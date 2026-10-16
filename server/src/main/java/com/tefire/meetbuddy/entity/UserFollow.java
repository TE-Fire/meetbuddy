package com.tefire.meetbuddy.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 关注关系（有向）。follower 关注 followee。唯一索引 uk_follow 是幂等防线，见 docs/13。
 */
@Data
@TableName("user_follow")
public class UserFollow {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 关注者 */
    private Long followerId;

    /** 被关注者 */
    private Long followeeId;

    private LocalDateTime createdAt;
}
