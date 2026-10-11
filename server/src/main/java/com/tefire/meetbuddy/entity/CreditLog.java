package com.tefire.meetbuddy.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 信用分流水，只追加不修改。
 * 扣分如果没有流水，用户就无法申诉，管理端的审核也就成了摆设。
 */
@Data
@TableName("credit_log")
public class CreditLog {

    @TableId(type = IdType.AUTO)
    private Long id;

    private Long userId;

    /** 正数为加，负数为减 */
    private Integer changeValue;

    private String reason;

    /** 关联活动或举报 */
    private Long relatedId;

    /** 管理端调整时非空 */
    private Long operatorId;

    private Integer balanceAfter;

    private LocalDateTime createdAt;
}
