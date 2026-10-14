package com.tefire.meetbuddy.vo;

import lombok.Data;

import java.time.LocalDateTime;

/** 管理端活动列表项。 */
@Data
public class AdminActivityVO {

    private Long id;
    private String title;
    private String category;
    private String status;
    private Integer adminStatus;
    private LocalDateTime startTime;
    private LocalDateTime endTime;
    private Integer currentParticipants;
    private Integer maxParticipants;
    private String address;
    private String organizerNickname;
    private LocalDateTime createdAt;
}
