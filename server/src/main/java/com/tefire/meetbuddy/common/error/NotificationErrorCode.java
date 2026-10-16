package com.tefire.meetbuddy.common.error;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 通知段错误码（32xx）。段位在 docs/03 的登记表里占好，M7 落地。
 * 通知基本是查询与已读操作，校验点少，目前只用到"不存在"这一个。
 */
@Getter
@AllArgsConstructor
public enum NotificationErrorCode implements IErrorCode {

    NOTIFICATION_NOT_FOUND(3201, "通知不存在");

    private final int code;
    private final String message;
}
