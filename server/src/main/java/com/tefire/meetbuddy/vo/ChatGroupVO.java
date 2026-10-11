package com.tefire.meetbuddy.vo;

import lombok.Data;

import java.time.LocalDateTime;

/** 我的群列表项。把最后一条消息和未读数一起带出来，列表页就不用再逐群请求。 */
@Data
public class ChatGroupVO {

    private Long id;

    private Long activityId;

    private String name;

    private Integer memberCount;

    /** 我在群里的角色：OWNER / MEMBER */
    private String role;

    private String lastMessage;

    private LocalDateTime lastMessageAt;

    /** 该群未读数，口径见 ChatService */
    private long unread;
}
