package com.tefire.meetbuddy.service;

/** 信用分变动，规则见 docs/01 第四节。所有加减分必须走这里，以便留下流水。 */
public interface CreditService {

    /**
     * @param delta     正数加分，负数扣分
     * @param reason    人类可读的原因，会展示给用户
     * @param relatedId 关联活动或举报
     * @param operatorId 管理端调整时非空，系统自动变动为 null
     */
    void change(Long userId, int delta, String reason, Long relatedId, Long operatorId);
}
