package com.tefire.meetbuddy.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("chat_group")
public class ChatGroup {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 活动群非空；预留非活动群场景 */
    private Long activityId;

    private String name;

    private Integer memberCount;

    private LocalDateTime createdAt;

    private LocalDateTime updatedAt;
}
