package com.tefire.meetbuddy.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 消息。单聊与群聊共用一张表（见 docs/02 第四节）：群聊时 {@code groupId} 非空，
 * 单聊时 {@code receiverId} 非空，两者不会同时有值。
 *
 * <p>不拆两张表的原因很实际——"未读数""历史记录"这两类查询如果按单聊/群聊分表，
 * 每次都要 union 两次再排序分页；而两者真正的差异只有一个"这条消息发给谁"。
 */
@Data
@TableName("message")
public class Message {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 群聊非空 */
    private Long groupId;

    private Long senderId;

    /** 单聊非空 */
    private Long receiverId;

    /** TEXT / IMAGE / SYSTEM */
    private String msgType;

    private String content;

    /**
     * 0 未读 / 1 已读。只对单聊有意义：群聊一条消息多人可见，一位 tinyint
     * 表达不了"谁读到哪"，那部分走 Redis 的 lastread 游标（见 ChatService）。
     */
    private Integer readStatus;

    private LocalDateTime createdAt;
}
