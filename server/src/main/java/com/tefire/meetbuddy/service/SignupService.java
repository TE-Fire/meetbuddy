package com.tefire.meetbuddy.service;

public interface SignupService {

    /**
     * 报名。并发防超员的唯一入口，M2 的压测打的就是这里。
     *
     * @param lockEnabled 是否走 Redis 分布式锁；关掉用于复现超卖，做实验对照组
     */
    void signup(Long userId, Long activityId, String remark, boolean lockEnabled);

    /** 取消报名。距开始不足 2 小时扣 3 分，否则扣 1 分，见 docs/01 第四节。 */
    void cancelSignup(Long userId, Long activityId);

    /** 组织者批量确认到场与缺席，驱动信用分变动。 */
    void confirmAttend(Long organizerId, Long activityId, java.util.List<Long> attended, java.util.List<Long> absent);
}
