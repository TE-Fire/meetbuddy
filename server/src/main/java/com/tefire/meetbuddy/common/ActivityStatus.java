package com.tefire.meetbuddy.common;

/**
 * 活动状态机，流转规则见 docs/01 第五节。
 * 存库用字符串，便于直接查库时看懂，代价是失去了编译期校验。
 */
public enum ActivityStatus {

    /** 报名中 */
    OPEN,
    /** 已满，关闭报名入口 */
    FULL,
    /** 进行中 */
    ONGOING,
    /** 已结束 */
    FINISHED,
    /** 组织者取消 */
    CANCELLED;

    public static boolean canSignUp(String status) {
        return OPEN.name().equals(status);
    }
}
