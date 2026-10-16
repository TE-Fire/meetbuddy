package com.tefire.meetbuddy.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 徽章解锁记录。徽章定义在 {@link com.tefire.meetbuddy.common.BadgeEnum}（代码内，不建定义表），
 * 本表只记"谁在什么时候拿到了哪枚"。唯一索引 uk_user_badge 是幂等防线，见 docs/06。
 */
@Data
@TableName("user_badge")
public class UserBadge {

    @TableId(type = IdType.AUTO)
    private Long id;

    private Long userId;

    private String badgeCode;

    private LocalDateTime unlockedAt;
}
