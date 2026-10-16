package com.tefire.meetbuddy.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.tefire.meetbuddy.common.ActivityStatus;
import com.tefire.meetbuddy.common.SignupStatus;
import com.tefire.meetbuddy.common.error.BizAssert;
import com.tefire.meetbuddy.common.error.CommonErrorCode;
import com.tefire.meetbuddy.entity.Activity;
import com.tefire.meetbuddy.entity.ActivitySignup;
import com.tefire.meetbuddy.entity.User;
import com.tefire.meetbuddy.entity.UserTag;
import com.tefire.meetbuddy.mapper.ActivityMapper;
import com.tefire.meetbuddy.mapper.ActivitySignupMapper;
import com.tefire.meetbuddy.mapper.UserMapper;
import com.tefire.meetbuddy.mapper.UserTagMapper;
import com.tefire.meetbuddy.service.BadgeService;
import com.tefire.meetbuddy.service.FollowService;
import com.tefire.meetbuddy.service.UserProfileService;
import com.tefire.meetbuddy.vo.BadgeVO;
import com.tefire.meetbuddy.vo.UserProfileVO;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 他人主页聚合。只暴露参与者列表早已公开的字段（昵称/头像/信用分），
 * 手机号等隐私字段刻意不返回；封禁用户可看，置灰交给前端的 banned 标志。
 */
@Service
@RequiredArgsConstructor
public class UserProfileServiceImpl implements UserProfileService {

    private static final int RECENT_LIMIT = 5;

    private final UserMapper userMapper;
    private final ActivityMapper activityMapper;
    private final ActivitySignupMapper signupMapper;
    private final BadgeService badgeService;
    private final UserTagMapper userTagMapper;
    private final FollowService followService;

    @Override
    public UserProfileVO getProfile(Long targetUserId, Long currentUserId) {
        User user = BizAssert.notNull(userMapper.selectById(targetUserId),
                CommonErrorCode.USER_NOT_FOUND);

        List<Activity> hosted = finishedActivities(activityMapper.selectList(
                new LambdaQueryWrapper<Activity>()
                        .eq(Activity::getOrganizerId, targetUserId)
                        .eq(Activity::getStatus, ActivityStatus.FINISHED.name())));

        List<ActivitySignup> joined = signupMapper.selectList(new LambdaQueryWrapper<ActivitySignup>()
                .eq(ActivitySignup::getUserId, targetUserId)
                .in(ActivitySignup::getStatus, SignupStatus.SIGNED.name(), SignupStatus.ATTENDED.name()));
        List<Long> joinedIds = joined.stream().map(ActivitySignup::getActivityId).distinct().toList();
        List<Activity> joinedActivities = joinedIds.isEmpty() ? List.of()
                : finishedActivities(activityMapper.selectList(new LambdaQueryWrapper<Activity>()
                        .in(Activity::getId, joinedIds)
                        .eq(Activity::getStatus, ActivityStatus.FINISHED.name())));

        UserProfileVO vo = new UserProfileVO();
        vo.setUserId(user.getId());
        vo.setNickname(user.getNickname());
        vo.setAvatar(user.getAvatar());
        vo.setBio(user.getBio());
        vo.setCreditScore(user.getCreditScore());
        vo.setBanned(user.getStatus() != null && user.getStatus() == 1);
        vo.setBadges(unlockedOnly(badgeService.unlockedBadges(targetUserId)));
        vo.setHostedCount(hosted.size());
        vo.setJoinedCount(joinedActivities.size());
        vo.setTags(userTagMapper.selectList(
                new LambdaQueryWrapper<UserTag>().eq(UserTag::getUserId, targetUserId).orderByAsc(UserTag::getId))
                .stream().map(UserTag::getTagName).toList());
        vo.setFollowerCount(followService.followerCount(targetUserId));
        vo.setFollowingCount(followService.followingCount(targetUserId));
        // 看自己时不显示"关注"按钮，following 恒为 false
        boolean notSelf = currentUserId != null && !currentUserId.equals(targetUserId);
        vo.setFollowing(notSelf && followService.isFollowing(currentUserId, targetUserId));
        vo.setRecentActivities(recent(hosted, joinedActivities));
        return vo;
    }

    /** 按开始时间倒序取前 N 条，组织与参加合并；role 标注身份 */
    private List<UserProfileVO.RecentActivity> recent(List<Activity> hosted, List<Activity> joined) {
        Map<Long, String> roleOf = new HashMap<>();
        for (Activity a : hosted) {
            roleOf.put(a.getId(), "ORGANIZER");
        }
        for (Activity a : joined) {
            roleOf.putIfAbsent(a.getId(), "PARTICIPANT");
        }
        List<Activity> all = new ArrayList<>(hosted);
        all.addAll(joined);
        all.sort(Comparator.comparing(Activity::getStartTime,
                Comparator.nullsLast(Comparator.reverseOrder())));
        List<UserProfileVO.RecentActivity> list = new ArrayList<>();
        for (Activity a : all) {
            if (list.size() >= RECENT_LIMIT) {
                break;
            }
            UserProfileVO.RecentActivity r = new UserProfileVO.RecentActivity();
            r.setId(a.getId());
            r.setTitle(a.getTitle());
            r.setCoverUrl(a.getCoverUrl());
            r.setStatus(a.getStatus());
            r.setStartTime(a.getStartTime());
            r.setRole(roleOf.get(a.getId()));
            list.add(r);
        }
        return list;
    }

    private List<Activity> finishedActivities(List<Activity> activities) {
        return activities == null ? List.of() : activities;
    }

    /** 主页只展示已得徽章，未得的不上别人的墙 */
    private List<BadgeVO> unlockedOnly(List<BadgeVO> badges) {
        List<BadgeVO> list = new ArrayList<>(badges.size());
        for (BadgeVO b : badges) {
            if (b.isUnlocked()) {
                list.add(b);
            }
        }
        return list;
    }
}
