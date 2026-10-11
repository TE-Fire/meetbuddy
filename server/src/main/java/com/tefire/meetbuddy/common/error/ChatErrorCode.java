package com.tefire.meetbuddy.common.error;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 聊天段错误码（31xx）。段位在 M0 就在 {@code docs/03} 的登记表里占好了，M4 才真正落地。
 *
 * <p>这里没有"消息发送失败"这类码：HTTP 侧聊天接口只有查询，发送走 WebSocket，
 * 而 WebSocket 的错误不是用 code 表达的——帧里带 {@code type=error} + 这里的码，
 * 见 {@code ChatWebSocketHandler}。所以这批码既要能被 HTTP 的 {@code Result} 用，
 * 也要能被 WS 的 error 帧用，实现 {@link IErrorCode} 正好两处通用。
 */
@Getter
@AllArgsConstructor
public enum ChatErrorCode implements IErrorCode {

    NOT_GROUP_MEMBER(3101, "你不在该群聊中"),
    MESSAGE_NOT_FOUND(3102, "消息不存在"),
    INVALID_FRAME(3103, "消息帧格式不正确"),
    GROUP_READONLY(3104, "活动已取消，群聊转为只读"),
    SEND_TO_SELF(3105, "不能给自己发消息"),
    UNAUTHORIZED_WS(3106, "连接令牌无效或已过期"),
    CONTENT_BLANK(3107, "消息内容不能为空");

    private final int code;
    private final String message;
}
