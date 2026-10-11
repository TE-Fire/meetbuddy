package com.tefire.meetbuddy.common;

/** 报名记录状态。取消后不删除行，保留历史以便统计放鸽子次数。 */
public enum SignupStatus {

    /** 已报名 */
    SIGNED,
    /** 已取消 */
    CANCELED,
    /** 到场 */
    ATTENDED,
    /** 缺席 */
    ABSENT;
}
