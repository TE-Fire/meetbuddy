package com.tefire.meetbuddy.vo;

import lombok.Data;

import java.time.LocalDateTime;

/** 管理端用户列表项。 */
@Data
public class AdminUserVO {

    private Long id;
    private String phone;
    private String nickname;
    private String avatar;
    private Integer gender;
    private Integer creditScore;
    private Integer status;
    private Integer role;
    private LocalDateTime lastActiveAt;
    private LocalDateTime createdAt;
}
