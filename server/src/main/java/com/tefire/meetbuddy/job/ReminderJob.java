package com.tefire.meetbuddy.job;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.tefire.meetbuddy.common.ActivityStatus;
import com.tefire.meetbuddy.common.SignupStatus;
import com.tefire.meetbuddy.entity.Activity;
import com.tefire.meetbuddy.entity.ActivitySignup;
import com.tefire.meetbuddy.mapper.ActivityMapper;
import com.tefire.meetbuddy.mapper.ActivitySignupMapper;
import com.tefire.meetbuddy.service.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * 活动开始前提醒。规则见 docs/05-通知与提醒.md。
 *
 * <p>每分钟扫一轮：找"未提醒、且开始时间落在 [now, now+提前量]"的活动，
 * 通知组织者 + 有效报名者，然后只把 {@code reminded} 从 0 置 1 防重
 * （用条件更新而不是 updateById，避免把别人并发改的计数字段写回旧值）。
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ReminderJob {

    private static final int SCAN_LIMIT = 100;

    private final ActivityMapper activityMapper;
    private final ActivitySignupMapper signupMapper;
    private final NotificationService notificationService;

    @Value("${meetbuddy.notification.reminder-lead-minutes:30}")
    private int leadMinutes;

    @Scheduled(fixedDelay = 60_000L)
    public void scanUpcoming() {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime horizon = now.plusMinutes(leadMinutes);
        List<Activity> upcoming = activityMapper.selectList(new LambdaQueryWrapper<Activity>()
                .eq(Activity::getReminded, 0)
                .in(Activity::getStatus, ActivityStatus.OPEN.name(),
                        ActivityStatus.FULL.name(), ActivityStatus.ONGOING.name())
                .ge(Activity::getStartTime, now)
                .le(Activity::getStartTime, horizon)
                .last("limit " + SCAN_LIMIT));
        for (Activity a : upcoming) {
            try {
                Set<Long> recipients = new HashSet<>();
                recipients.add(a.getOrganizerId());
                recipients.addAll(activeSignupUserIds(a.getId()));
                notificationService.notifyUsers(recipients, "ACTIVITY_REMINDER",
                        "活动即将开始",
                        "「" + a.getTitle() + "」将在 " + leadMinutes + " 分钟内开始，别忘了赴约",
                        a.getId());
                activityMapper.update(null, new LambdaUpdateWrapper<Activity>()
                        .set(Activity::getReminded, 1)
                        .eq(Activity::getId, a.getId())
                        .eq(Activity::getReminded, 0));
            } catch (Exception ex) {
                // 单个活动失败不拖垮整轮，记日志继续
                log.warn("[reminder] 活动 {} 提醒失败: {}", a.getId(), ex.getMessage());
            }
        }
    }

    private List<Long> activeSignupUserIds(Long activityId) {
        return signupMapper.selectList(new LambdaQueryWrapper<ActivitySignup>()
                        .eq(ActivitySignup::getActivityId, activityId)
                        .in(ActivitySignup::getStatus, SignupStatus.SIGNED.name(),
                                SignupStatus.ATTENDED.name(), SignupStatus.ABSENT.name()))
                .stream().map(ActivitySignup::getUserId).toList();
    }
}
