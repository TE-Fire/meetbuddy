package com.tefire.meetbuddy.common.error;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 活动与报名段（2xxx）。段位登记见 {@link CommonErrorCode}。
 *
 * <p>21xx 留给搭子与匹配（BuddyErrorCode），现在还没有独立的错误码，先不立枚举。
 */
@Getter
@AllArgsConstructor
public enum ActivityErrorCode implements IErrorCode {

    ACTIVITY_FULL(2001, "活动已满"),
    DUPLICATE_SIGNUP(2002, "已报名过该活动"),
    CREDIT_LOW(2003, "信用分不足"),
    ;

    private final int code;
    private final String message;

    @Override
    public int getCode() {
        return code;
    }

    @Override
    public String getMessage() {
        return message;
    }
}
