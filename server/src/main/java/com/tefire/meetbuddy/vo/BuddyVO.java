package com.tefire.meetbuddy.vo;

import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Data
public class BuddyVO {

    private Long id;

    private Long userId;

    private String nickname;

    private String avatar;

    private String title;

    private String description;

    private String category;

    private BigDecimal lng;

    private BigDecimal lat;

    private String timeRange;

    private String status;

    private List<String> tags;

    private Integer creditScore;

    private LocalDateTime createdAt;
}
