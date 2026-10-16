package com.tefire.meetbuddy.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 站内通知。规则见 docs/05-通知与提醒.md。
 * 一条通知一个接收人，已读用 read_status，与单聊消息同一个路子。
 */
@Data
@TableName("notification")
public class Notification {

    @TableId(type = IdType.AUTO)
    private Long id;

    private Long userId;

    /** SIGNUP_NEW / ACTIVITY_CANCELLED / ACTIVITY_REMINDER（管理侧类型后续增强） */
    private String type;

    private String title;

    private String content;

    /** 关联业务 id，多为活动 id；点击通知据此跳转 */
    private Long bizId;

    /** 0 未读 / 1 已读 */
    private Integer readStatus;

    private LocalDateTime createdAt;
}
