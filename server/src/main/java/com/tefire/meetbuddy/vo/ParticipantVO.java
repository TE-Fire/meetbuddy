package com.tefire.meetbuddy.vo;

import lombok.Data;

import java.time.LocalDateTime;

@Data
public class ParticipantVO {

    private Long userId;

    private String nickname;

    private String avatar;

    private Integer creditScore;

    /** SIGNED / CANCELED / ATTENDED / ABSENT */
    private String status;

    private String remark;

    private LocalDateTime joinedAt;
}
