package com.tefire.meetbuddy.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("report")
public class Report {

    @TableId(type = IdType.AUTO)
    private Long id;

    private Long reporterId;

    /** ACTIVITY / USER / MESSAGE */
    private String targetType;

    private Long targetId;

    private String reason;

    /** 图片 URL，逗号分隔 */
    private String evidence;

    /** PENDING / APPROVED / REJECTED */
    private String status;

    private Long handlerId;

    private String handleResult;

    private LocalDateTime createdAt;

    private LocalDateTime updatedAt;
}
