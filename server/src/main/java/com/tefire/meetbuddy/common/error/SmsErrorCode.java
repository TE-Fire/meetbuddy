package com.tefire.meetbuddy.common.error;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 通知 / 短信段（3xxx）。段位登记见 {@link CommonErrorCode}。
 *
 * <p>31xx 留给聊天与 WebSocket（M4），届时新立枚举即可，本枚举不动。
 */
@Getter
@AllArgsConstructor
public enum SmsErrorCode implements IErrorCode {

    SMS_CODE_ERROR(3001, "验证码错误或已过期"),
    SMS_SEND_TOO_OFTEN(3002, "验证码发送过于频繁"),
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
