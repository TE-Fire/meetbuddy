package com.tefire.meetbuddy.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("buddy_tag")
public class BuddyTag {

    @TableId(type = IdType.AUTO)
    private Long id;

    private Long requestId;

    private String tagName;

    private LocalDateTime createdAt;
}
