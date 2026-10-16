package com.tefire.meetbuddy.job;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.tefire.meetbuddy.common.ActivityStatus;
import com.tefire.meetbuddy.entity.Activity;
import com.tefire.meetbuddy.mapper.ActivityMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 活动到点自动结项。规则见 docs/06-成就勋章与个人主页.md 第三节。
 *
 * <p>组织者忘了点"确认到场"时，{@code doConfirmAttend} 那笔 FINISHED 永远不会来，
 * 活动会一直挂在 ONGOING，扫描类徽章也跟着评不了。本 Job 兜底：结束时间已过、
 * 状态还停在 OPEN/FULL/ONGOING 的一律转 FINISHED（CANCELLED 不动）。
 * 条件更新而不是 updateById，避免把别人并发改的计数字段写回旧值（与 ReminderJob 同思路）。
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ActivityFinishJob {

    private static final int SCAN_LIMIT = 100;

    private final ActivityMapper activityMapper;

    @Scheduled(fixedDelay = 60_000L)
    public void scanEnded() {
        List<Activity> ended = activityMapper.selectList(new LambdaQueryWrapper<Activity>()
                .in(Activity::getStatus, ActivityStatus.OPEN.name(),
                        ActivityStatus.FULL.name(), ActivityStatus.ONGOING.name())
                .le(Activity::getEndTime, LocalDateTime.now())
                .last("limit " + SCAN_LIMIT));
        for (Activity a : ended) {
            try {
                long n = activityMapper.update(null, new LambdaUpdateWrapper<Activity>()
                        .set(Activity::getStatus, ActivityStatus.FINISHED.name())
                        .eq(Activity::getId, a.getId())
                        .in(Activity::getStatus, ActivityStatus.OPEN.name(),
                                ActivityStatus.FULL.name(), ActivityStatus.ONGOING.name()));
                if (n > 0) {
                    log.info("[finish] 活动 {} 到点自动结项", a.getId());
                }
            } catch (Exception ex) {
                // 单个失败不拖垮整轮
                log.warn("[finish] 活动 {} 结项失败: {}", a.getId(), ex.getMessage());
            }
        }
    }
}
