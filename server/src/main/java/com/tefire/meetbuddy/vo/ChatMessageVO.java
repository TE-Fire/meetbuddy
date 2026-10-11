package com.tefire.meetbuddy.vo;

import lombok.Data;

import java.time.LocalDateTime;

/** 聊天消息出参。单聊时 groupId 为空，群聊时 receiverId 为空。 */
@Data
public class ChatMessageVO {

    private Long id;

    private Long groupId;

    private Long receiverId;

    private Long senderId;

    private String senderNickname;

    private String senderAvatar;

    /** TEXT / IMAGE / SYSTEM */
    private String msgType;

    private String content;

    private Integer readStatus;

    private LocalDateTime createdAt;
}
