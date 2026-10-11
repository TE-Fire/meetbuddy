package com.tefire.meetbuddy.service.impl;

import com.tefire.meetbuddy.common.error.CommonErrorCode;
import com.tefire.meetbuddy.service.SignupService;
import com.tefire.meetbuddy.util.RedisLock;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.List;

/**
 * 报名的锁层。只负责互斥，业务逻辑全在 {@link SignupTxService}。
 *
 * <p>锁粒度是单个活动而不是整个接口：不同活动之间互不影响，
 * 压测时二十个活动可以同时被抢，不会因为全局锁退化成串行。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class SignupServiceImpl implements SignupService {

    private static final String LOCK_KEY_PREFIX = "lock:activity:signup:";

    private final SignupTxService signupTxService;
    private final RedisLock redisLock;

    @Override
    public void signup(Long userId, Long activityId, String remark, boolean lockEnabled) {
        if (!lockEnabled) {
            // 无锁路径，仅用于复现超卖做实验对照
            signupTxService.doSignup(userId, activityId, remark, false);
            return;
        }
        String key = LOCK_KEY_PREFIX + activityId;
        String token = redisLock.tryLock(key, Duration.ofSeconds(10), Duration.ofSeconds(5));
        if (token == null) {
            throw CommonErrorCode.SYSTEM_ERROR.ex("报名过于拥挤，请稍后重试");
        }
        try {
            signupTxService.doSignup(userId, activityId, remark, true);
        } finally {
            redisLock.unlock(key, token);
        }
    }

    @Override
    public void cancelSignup(Long userId, Long activityId) {
        signupTxService.doCancel(userId, activityId);
    }

    @Override
    public void confirmAttend(Long organizerId, Long activityId, List<Long> attended, List<Long> absent) {
        signupTxService.doConfirmAttend(organizerId, activityId, attended, absent);
    }
}
