package com.tefire.meetbuddy.vo;

import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

/** 活动流列表项。刻意不含 description 与图片，列表页不需要，省一次大字段传输。 */
@Data
public class ActivityVO {

    private Long id;

    private String title;

    private String category;

    private String coverUrl;

    private BigDecimal lng;

    private BigDecimal lat;

    private String address;

    private LocalDateTime startTime;

    private LocalDateTime endTime;

    private Integer maxParticipants;

    private Integer currentParticipants;

    private String status;

    private Integer creditRequired;

    private List<String> tags;

    /** 组织者摘要，避免前端为了显示头像再打一次用户接口 */
    private Long organizerId;

    private String organizerNickname;

    private String organizerAvatar;
}
