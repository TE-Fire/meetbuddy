package com.tefire.meetbuddy.job;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.tefire.meetbuddy.common.ActivityStatus;
import com.tefire.meetbuddy.common.SignupStatus;
import com.tefire.meetbuddy.entity.Activity;
import com.tefire.meetbuddy.entity.ActivitySignup;
import com.tefire.meetbuddy.mapper.ActivityMapper;
import com.tefire.meetbuddy.mapper.ActivitySignupMapper;
import com.tefire.meetbuddy.service.BadgeService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * 扫描类徽章的评定。规则见 docs/06-成就勋章与个人主页.md 第三节。
 *
 * <p>每分钟扫一轮"已结束但未评勋"的活动（{@code badge_scanned=0}），对组织者与
 * 全部有效报名者跑一遍阈值检查，然后条件更新置 1——每场活动只扫一次，与
 * ReminderJob 的 {@code reminded} 同一防重思路。即时类徽章不在这里，
 * 它们挂在事务方法末尾（doSignup / create / doConfirmAttend）。
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class BadgeScanJob {

    private static final int SCAN_LIMIT = 100;

    private final ActivityMapper activityMapper;
    private final ActivitySignupMapper signupMapper;
    private final BadgeService badgeService;

    @Scheduled(fixedDelay = 60_000L)
    public void scanFinished() {
        List<Activity> finished = activityMapper.selectList(new LambdaQueryWrapper<Activity>()
                .eq(Activity::getStatus, ActivityStatus.FINISHED.name())
                .eq(Activity::getBadgeScanned, 0)
                .last("limit " + SCAN_LIMIT));
        for (Activity a : finished) {
            try {
                Set<Long> candidates = new HashSet<>();
                candidates.add(a.getOrganizerId());
                candidates.addAll(activeSignupUserIds(a.getId()));
                for (Long userId : candidates) {
                    badgeService.checkScanned(userId);
                }
                activityMapper.update(null, new LambdaUpdateWrapper<Activity>()
                        .set(Activity::getBadgeScanned, 1)
                        .eq(Activity::getId, a.getId())
                        .eq(Activity::getBadgeScanned, 0));
            } catch (Exception ex) {
                // 单个活动失败不拖垮整轮，下轮重扫（badge_scanned 未置位）
                log.warn("[badge-scan] 活动 {} 评勋失败: {}", a.getId(), ex.getMessage());
            }
        }
    }

    /** 有效报名：SIGNED/ATTENDED/ABSENT 都算这场活动的相关人（缺席者也该评他的到场/放鸽子徽章） */
    private List<Long> activeSignupUserIds(Long activityId) {
        return signupMapper.selectList(new LambdaQueryWrapper<ActivitySignup>()
                        .eq(ActivitySignup::getActivityId, activityId)
                        .in(ActivitySignup::getStatus, SignupStatus.SIGNED.name(),
                                SignupStatus.ATTENDED.name(), SignupStatus.ABSENT.name()))
                .stream().map(ActivitySignup::getUserId).toList();
    }
}
