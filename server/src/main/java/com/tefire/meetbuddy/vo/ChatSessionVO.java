package com.tefire.meetbuddy.vo;

import lombok.Data;

import java.time.LocalDateTime;

/**
 * 我的单聊会话列表项（与 {@link ChatGroupVO} 对偶：群聊一项是一群人，单聊一项是一个对方）。
 * 把对方信息、最后一条消息、未读数一次带出，消息页不必再逐个请求。
 */
@Data
public class ChatSessionVO {

    /** 对方 userId，点击进聊天室时当 peerId 用 */
    private Long peerId;

    private String peerNickname;

    private String peerAvatar;

    private String lastMessage;

    private LocalDateTime lastMessageAt;

    /** 对方发来且未读的条数，口径同 ChatService.unreadTotal 的单聊部分 */
    private long unread;

    /** 最后一条是不是我发的：前端据此决定要不要显示“我:”前缀 */
    private boolean selfLast;
}
