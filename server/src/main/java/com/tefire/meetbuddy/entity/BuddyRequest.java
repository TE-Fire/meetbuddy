package com.tefire.meetbuddy.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 搭子需求。与 activity 分开建表的原因写在 docs/02：它没有人数上限，也没有截止时间，
 * 合并只会得到一张到处是 nullable 的宽表。
 */
@Data
@TableName("buddy_request")
public class BuddyRequest {

    @TableId(type = IdType.AUTO)
    private Long id;

    private Long userId;

    private String title;

    private String description;

    private String category;

    private BigDecimal lng;

    private BigDecimal lat;

    /** 自由文本，如"周末下午"；刻意不做成时间字段，因为搭子需求本来就没有精确时点 */
    private String timeRange;

    /** OPEN / CLOSED */
    private String status;

    private LocalDateTime createdAt;

    private LocalDateTime updatedAt;
}
