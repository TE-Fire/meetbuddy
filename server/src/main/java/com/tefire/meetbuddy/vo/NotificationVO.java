package com.tefire.meetbuddy.vo;

import lombok.Data;

import java.time.LocalDateTime;

/** 通知列表项。bizId 供前端点击跳转（多为活动 id）。 */
@Data
public class NotificationVO {

    private Long id;

    private String type;

    private String title;

    private String content;

    private Long bizId;

    /** 0 未读 / 1 已读 */
    private Integer readStatus;

    private LocalDateTime createdAt;
}
