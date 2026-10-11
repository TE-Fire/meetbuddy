package com.tefire.meetbuddy.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.tefire.meetbuddy.common.ActivityStatus;
import com.tefire.meetbuddy.common.SignupStatus;
import com.tefire.meetbuddy.common.error.ActivityErrorCode;
import com.tefire.meetbuddy.common.error.BizAssert;
import com.tefire.meetbuddy.common.error.CommonErrorCode;
import com.tefire.meetbuddy.entity.Activity;
import com.tefire.meetbuddy.entity.ActivitySignup;
import com.tefire.meetbuddy.entity.ChatGroupMember;
import com.tefire.meetbuddy.entity.User;
import com.tefire.meetbuddy.mapper.ActivityMapper;
import com.tefire.meetbuddy.mapper.ActivitySignupMapper;
import com.tefire.meetbuddy.mapper.ChatGroupMemberMapper;
import com.tefire.meetbuddy.mapper.UserMapper;
import com.tefire.meetbuddy.service.CreditService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 报名的数据库事务部分，单独成一个 Bean。
 *
 * <p>拆出来的原因：{@link SignupServiceImpl} 要在事务提交之后才释放 Redis 锁。
 * 如果把加锁和事务写在同一个类里，锁会在事务提交前就被释放，
 * 另一个线程可能读到尚未提交的计数，锁就形同虚设。
 */
@Service
@RequiredArgsConstructor
public class SignupTxService {

    private final ActivityMapper activityMapper;
    private final ActivitySignupMapper signupMapper;
    private final ChatGroupMemberMapper chatGroupMemberMapper;
    private final UserMapper userMapper;
    private final CreditService creditService;

    @Transactional(rollbackFor = Exception.class)
    public void doSignup(Long userId, Long activityId, String remark, boolean guarded) {
        Activity activity = BizAssert.notNull(activityMapper.selectById(activityId),
                CommonErrorCode.NOT_FOUND, "活动不存在");
        if (activity.getOrganizerId().equals(userId)) {
            throw CommonErrorCode.PARAM_ERROR.ex("组织者无需报名");
        }
        if (!ActivityStatus.canSignUp(activity.getStatus())) {
            throw ActivityErrorCode.ACTIVITY_FULL.ex("活动已满或已停止报名");
        }
        User user = BizAssert.notNull(userMapper.selectById(userId), CommonErrorCode.USER_NOT_FOUND);
        if (user.getCreditScore() < activity.getCreditRequired()) {
            throw ActivityErrorCode.CREDIT_LOW.ex("信用分不足，该活动要求 " + activity.getCreditRequired() + " 分");
        }
        // 查的是"任意状态"的历史行，不只是有效报名：
        // uk_activity_user 是防超员的最后一道防线，但它同时也会挡住"取消后重新报名"——
        // 所以这里对已取消的行做复用，而不是直接 insert。
        ActivitySignup existing = findAnySignup(activityId, userId);
        if (existing != null && isActive(existing.getStatus())) {
            throw ActivityErrorCode.DUPLICATE_SIGNUP.ex();
        }

        if (guarded) {
            // 条件更新：计数自增与上限判断在同一条 SQL 里，靠行锁保证不越界
            if (activityMapper.reserveSlot(activityId) == 0) {
                throw ActivityErrorCode.ACTIVITY_FULL.ex();
            }
        } else {
            // 无锁对照组：先查后写，高并发下必然超卖
            if (activity.getCurrentParticipants() >= activity.getMaxParticipants()) {
                throw ActivityErrorCode.ACTIVITY_FULL.ex();
            }
            activityMapper.incrSlotUnchecked(activityId);
        }

        if (existing != null) {
            existing.setStatus(SignupStatus.SIGNED.name());
            existing.setRemark(remark);
            signupMapper.updateById(existing);
        } else {
            ActivitySignup signup = new ActivitySignup();
            signup.setActivityId(activityId);
            signup.setUserId(userId);
            signup.setStatus(SignupStatus.SIGNED.name());
            signup.setRemark(remark);
            signupMapper.insert(signup);
        }

        joinGroup(activity, userId);
        activityMapper.markFull(activityId);
    }

    @Transactional(rollbackFor = Exception.class)
    public void doCancel(Long userId, Long activityId) {
        ActivitySignup signup = BizAssert.notNull(findActiveSignup(activityId, userId),
                CommonErrorCode.NOT_FOUND, "尚未报名该活动");
        Activity activity = BizAssert.notNull(activityMapper.selectById(activityId),
                CommonErrorCode.NOT_FOUND, "活动不存在");
        if (ActivityStatus.ONGOING.name().equals(activity.getStatus())
                || ActivityStatus.FINISHED.name().equals(activity.getStatus())
                || ActivityStatus.CANCELLED.name().equals(activity.getStatus())) {
            throw CommonErrorCode.PARAM_ERROR.ex("活动已开始或已取消，不能取消报名");
        }

        signup.setStatus(SignupStatus.CANCELED.name());
        signupMapper.updateById(signup);

        activityMapper.releaseSlot(activityId);
        activityMapper.reopen(activityId);
        leaveGroup(activity, userId);

        long minutesToStart = java.time.Duration.between(LocalDateTime.now(), activity.getStartTime()).toMinutes();
        if (minutesToStart <= 120) {
            creditService.change(userId, -3, "活动开始前 2 小时内取消报名", activityId, null);
        } else {
            creditService.change(userId, -1, "取消报名", activityId, null);
        }
    }

    @Transactional(rollbackFor = Exception.class)
    public void doConfirmAttend(Long organizerId, Long activityId, List<Long> attended, List<Long> absent) {
        Activity activity = BizAssert.notNull(activityMapper.selectById(activityId),
                CommonErrorCode.NOT_FOUND, "活动不存在");
        if (!activity.getOrganizerId().equals(organizerId)) {
            throw CommonErrorCode.FORBIDDEN.ex("只有组织者可以确认到场");
        }
        if (ActivityStatus.CANCELLED.name().equals(activity.getStatus())) {
            throw CommonErrorCode.PARAM_ERROR.ex("已取消的活动不能确认到场");
        }

        if (attended != null) {
            for (Long userId : attended) {
                ActivitySignup signup = findActiveSignup(activityId, userId);
                if (signup == null) {
                    continue;
                }
                signup.setStatus(SignupStatus.ATTENDED.name());
                signupMapper.updateById(signup);
                creditService.change(userId, 3, "被组织者确认到场", activityId, null);
            }
        }
        if (absent != null) {
            for (Long userId : absent) {
                ActivitySignup signup = findActiveSignup(activityId, userId);
                if (signup == null) {
                    continue;
                }
                signup.setStatus(SignupStatus.ABSENT.name());
                signupMapper.updateById(signup);
                creditService.change(userId, -10, "报名后未到场", activityId, null);
            }
        }
        activity.setStatus(ActivityStatus.FINISHED.name());
        activityMapper.updateById(activity);
    }

    private static boolean isActive(String status) {
        return SignupStatus.SIGNED.name().equals(status)
                || SignupStatus.ATTENDED.name().equals(status)
                || SignupStatus.ABSENT.name().equals(status);
    }

    /** 查任意状态的报名行，用于区分"从未报过名"和"报过又取消了"。 */
    private ActivitySignup findAnySignup(Long activityId, Long userId) {
        List<ActivitySignup> list = signupMapper.selectList(new LambdaQueryWrapper<ActivitySignup>()
                .eq(ActivitySignup::getActivityId, activityId)
                .eq(ActivitySignup::getUserId, userId)
                .last("limit 1"));
        return list.isEmpty() ? null : list.get(0);
    }

    private ActivitySignup findActiveSignup(Long activityId, Long userId) {
        List<ActivitySignup> list = signupMapper.selectList(new LambdaQueryWrapper<ActivitySignup>()
                .eq(ActivitySignup::getActivityId, activityId)
                .eq(ActivitySignup::getUserId, userId)
                .in(ActivitySignup::getStatus, SignupStatus.SIGNED.name(),
                        SignupStatus.ATTENDED.name(), SignupStatus.ABSENT.name())
                .last("limit 1"));
        return list.isEmpty() ? null : list.get(0);
    }

    private void joinGroup(Activity activity, Long userId) {
        if (activity.getGroupId() == null) {
            return;
        }
        boolean exists = chatGroupMemberMapper.selectCount(new LambdaQueryWrapper<ChatGroupMember>()
                .eq(ChatGroupMember::getGroupId, activity.getGroupId())
                .eq(ChatGroupMember::getUserId, userId)) > 0;
        if (exists) {
            return;
        }
        ChatGroupMember member = new ChatGroupMember();
        member.setGroupId(activity.getGroupId());
        member.setUserId(userId);
        member.setRole("MEMBER");
        member.setJoinedAt(LocalDateTime.now());
        chatGroupMemberMapper.insert(member);
    }

    private void leaveGroup(Activity activity, Long userId) {
        if (activity.getGroupId() == null) {
            return;
        }
        chatGroupMemberMapper.delete(new LambdaQueryWrapper<ChatGroupMember>()
                .eq(ChatGroupMember::getGroupId, activity.getGroupId())
                .eq(ChatGroupMember::getUserId, userId));
    }
}
