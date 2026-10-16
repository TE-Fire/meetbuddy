package com.tefire.meetbuddy.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.tefire.meetbuddy.common.ActivityStatus;
import com.tefire.meetbuddy.common.BadgeEnum;
import com.tefire.meetbuddy.common.SignupStatus;
import com.tefire.meetbuddy.entity.Activity;
import com.tefire.meetbuddy.entity.ActivitySignup;
import com.tefire.meetbuddy.entity.UserBadge;
import com.tefire.meetbuddy.mapper.ActivityMapper;
import com.tefire.meetbuddy.mapper.ActivitySignupMapper;
import com.tefire.meetbuddy.mapper.UserBadgeMapper;
import com.tefire.meetbuddy.service.BadgeService;
import com.tefire.meetbuddy.service.NotificationService;
import com.tefire.meetbuddy.vo.BadgeVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 徽章解锁。进度全部用 COUNT 现算（个人维度数据量小，不建统计表），
 * 未解锁徽章的 progress 与解锁判定共用同一次计数。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class BadgeServiceImpl implements BadgeService {

    private final UserBadgeMapper userBadgeMapper;
    private final ActivityMapper activityMapper;
    private final ActivitySignupMapper signupMapper;
    private final NotificationService notificationService;

    @Override
    public List<BadgeVO> myBadges(Long userId) {
        Map<BadgeEnum.Group, Integer> counts = groupCounts(userId);
        Map<String, LocalDateTime> unlocked = unlockedMap(userId);
        List<BadgeVO> list = new ArrayList<>(BadgeEnum.values().length);
        for (BadgeEnum b : BadgeEnum.values()) {
            list.add(toVO(b, unlocked.get(b.getCode()), counts.get(b.getGroup())));
        }
        return list;
    }

    @Override
    public List<BadgeVO> unlockedBadges(Long userId) {
        Map<String, LocalDateTime> unlocked = unlockedMap(userId);
        List<BadgeVO> list = new ArrayList<>(unlocked.size());
        for (BadgeEnum b : BadgeEnum.values()) {
            LocalDateTime at = unlocked.get(b.getCode());
            if (at != null) {
                list.add(toVO(b, at, null));
            }
        }
        return list;
    }

    @Override
    public void checkInstant(Long userId, BadgeEnum badge) {
        if (unlockedMap(userId).containsKey(badge.getCode())) {
            return;
        }
        // NONE 组是"首次"型徽章：挂点本身就是首次现场，无需计数，直接解锁
        if (badge.getGroup() == BadgeEnum.Group.NONE) {
            unlock(userId, badge);
            return;
        }
        int current = groupCounts(userId).getOrDefault(badge.getGroup(), 0);
        if (current >= badge.getTarget()) {
            unlock(userId, badge);
        }
    }

    @Override
    public void checkScanned(Long userId) {
        Map<String, LocalDateTime> unlocked = unlockedMap(userId);
        Map<BadgeEnum.Group, Integer> counts = null;
        for (BadgeEnum b : BadgeEnum.values()) {
            if (b.getTrigger() != BadgeEnum.Trigger.SCAN || unlocked.containsKey(b.getCode())) {
                continue;
            }
            if (counts == null) {
                counts = groupCounts(userId);
            }
            int current = counts.getOrDefault(b.getGroup(), 0);
            if (current >= b.getTarget()) {
                unlock(userId, b);
            }
        }
    }

    // ---------------- 内部 ----------------

    /** 一次算全所有组的当前值，供 myBadges / checkInstant / checkScanned 复用 */
    private Map<BadgeEnum.Group, Integer> groupCounts(Long userId) {
        Map<BadgeEnum.Group, Integer> counts = new EnumMap<>(BadgeEnum.Group.class);
        counts.put(BadgeEnum.Group.NONE, 0);
        counts.put(BadgeEnum.Group.JOINED, countFinishedJoined(userId));
        counts.put(BadgeEnum.Group.HOSTED, countFinishedHosted(userId));
        counts.put(BadgeEnum.Group.ATTENDED, countAttended(userId));
        counts.put(BadgeEnum.Group.FULL, countFullHouse(userId));
        return counts;
    }

    /**
     * 完成的活动数：报名状态为 SIGNED/ATTENDED（不含 CANCELED 与 ABSENT——缺席不算"参加"，
     * 放鸽子由信用分惩罚叙事承担），且活动已 FINISHED。口径见 docs/06 第二节。
     */
    private int countFinishedJoined(Long userId) {
        List<Long> activityIds = signupMapper.selectList(new LambdaQueryWrapper<ActivitySignup>()
                        .eq(ActivitySignup::getUserId, userId)
                        .in(ActivitySignup::getStatus, SignupStatus.SIGNED.name(), SignupStatus.ATTENDED.name()))
                .stream().map(ActivitySignup::getActivityId).distinct().toList();
        if (activityIds.isEmpty()) {
            return 0;
        }
        return Math.toIntExact(activityMapper.selectCount(new LambdaQueryWrapper<Activity>()
                .in(Activity::getId, activityIds)
                .eq(Activity::getStatus, ActivityStatus.FINISHED.name())));
    }

    /** 完成的活动数：自己组织且正常结束（CANCELLED 不算完成） */
    private int countFinishedHosted(Long userId) {
        return Math.toIntExact(activityMapper.selectCount(new LambdaQueryWrapper<Activity>()
                .eq(Activity::getOrganizerId, userId)
                .eq(Activity::getStatus, ActivityStatus.FINISHED.name())));
    }

    private int countAttended(Long userId) {
        return Math.toIntExact(signupMapper.selectCount(new LambdaQueryWrapper<ActivitySignup>()
                .eq(ActivitySignup::getUserId, userId)
                .eq(ActivitySignup::getStatus, SignupStatus.ATTENDED.name())));
    }

    /** 满员结束的活动数。取结束时的计数：取消报名会 releaseSlot 减计数，扫到的是最终值 */
    private int countFullHouse(Long userId) {
        return Math.toIntExact(activityMapper.selectCount(new LambdaQueryWrapper<Activity>()
                .eq(Activity::getOrganizerId, userId)
                .eq(Activity::getStatus, ActivityStatus.FINISHED.name())
                .apply("current_participants >= max_participants")));
    }

    private Map<String, LocalDateTime> unlockedMap(Long userId) {
        List<UserBadge> rows = userBadgeMapper.selectList(new LambdaQueryWrapper<UserBadge>()
                .eq(UserBadge::getUserId, userId));
        Map<String, LocalDateTime> map = new HashMap<>(rows.size());
        for (UserBadge r : rows) {
            map.put(r.getBadgeCode(), r.getUnlockedAt());
        }
        return map;
    }

    /**
     * 解锁 + 发通知。幂等靠 uk_user_badge：即时挂点与定时扫描可能并发判定同一枚，
     * 重复插入被数据库挡下，吞掉异常视为"已解锁"，不重复发通知。
     */
    private void unlock(Long userId, BadgeEnum badge) {
        UserBadge record = new UserBadge();
        record.setUserId(userId);
        record.setBadgeCode(badge.getCode());
        record.setUnlockedAt(LocalDateTime.now());
        try {
            userBadgeMapper.insert(record);
        } catch (DuplicateKeyException ex) {
            log.debug("[badge] 用户 {} 的 {} 已解锁，跳过", userId, badge.getCode());
            return;
        }
        notificationService.notifyUser(userId, "BADGE_UNLOCKED",
                "获得新徽章",
                "恭喜获得徽章「" + badge.getName() + "」：" + badge.getDesc(),
                null);
    }

    private BadgeVO toVO(BadgeEnum b, LocalDateTime unlockedAt, Integer current) {
        BadgeVO vo = new BadgeVO();
        vo.setCode(b.getCode());
        vo.setName(b.getName());
        vo.setDesc(b.getDesc());
        vo.setIcon(b.getIcon());
        vo.setGroup(b.getGroup().name());
        vo.setUnlocked(unlockedAt != null);
        vo.setUnlockedAt(unlockedAt);
        vo.setTarget(b.getTarget());
        vo.setProgress(b.getGroup() == BadgeEnum.Group.NONE ? 0 : (current == null ? 0 : current));
        return vo;
    }
}
