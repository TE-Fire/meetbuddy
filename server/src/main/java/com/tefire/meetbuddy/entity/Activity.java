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

    private Integer creditRequired;

    private Long groupId;

    private LocalDateTime createdAt;

    private LocalDateTime updatedAt;
}
