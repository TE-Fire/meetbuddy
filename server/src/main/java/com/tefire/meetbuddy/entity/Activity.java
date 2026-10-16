package com.tefire.meetbuddy.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@TableName("activity")
public class Activity {

    @TableId(type = IdType.AUTO)
    private Long id;

    private Long organizerId;

    private String title;

    private String description;

    /** 剧本杀 / 运动 / 探店 / 拼车 / 其他 */
    private String category;

    private String coverUrl;

    private BigDecimal lng;

    private BigDecimal lat;

    private String address;

    private LocalDateTime startTime;

    private LocalDateTime endTime;

    private Integer maxParticipants;

    /** 冗余计数，正确性由报名时的分布式锁保证 */
    private Integer currentParticipants;

    /** OPEN / FULL / ONGOING / FINISHED / CANCELLED */
    private String status;

    /** 管理侧干预维度：0 正常 / 1 下架。与 status 状态机分离，避免表达不了"进行中却被下架" */
    private Integer adminStatus;

    private Integer creditRequired;

    private Long groupId;

    /** 是否已发"开始前提醒"（0 未发 / 1 已发），ReminderJob 置位防重，见 docs/05 */
    private Integer reminded;

    /** 是否已被 BadgeScanJob 评勋（0 未评 / 1 已评），置位防重，见 docs/06 */
    private Integer badgeScanned;

    private LocalDateTime createdAt;

    private LocalDateTime updatedAt;
}
