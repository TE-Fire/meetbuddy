package com.tefire.meetbuddy.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@TableName("user")
public class User {

    @TableId(type = IdType.AUTO)
    private Long id;

    private String phone;

    private String passwordHash;

    private String nickname;

    private String avatar;

    /** 0 未知 / 1 男 / 2 女 */
    private Integer gender;

    private String bio;

    /** 信用分，区间 [0,100]，新用户初始 100 */
    private Integer creditScore;

    /** 0 正常 / 1 封禁 */
    private Integer status;

    /** 0 普通用户 / 1 管理员（M6 引入） */
    private Integer role;

    private BigDecimal lastLng;

    private BigDecimal lastLat;

    private LocalDateTime lastActiveAt;

    private LocalDateTime createdAt;

    private LocalDateTime updatedAt;
}
