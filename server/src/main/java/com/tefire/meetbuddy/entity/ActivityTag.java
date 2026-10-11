package com.tefire.meetbuddy.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("activity_tag")
public class ActivityTag {

    @TableId(type = IdType.AUTO)
    private Long id;

    private Long activityId;

    private String tagName;

    private LocalDateTime createdAt;
}
