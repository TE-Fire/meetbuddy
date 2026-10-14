package com.tefire.meetbuddy.vo;

import lombok.Data;

import java.time.LocalDateTime;

/** 管理端举报列表项。 */
@Data
public class AdminReportVO {

    private Long id;
    private String reporterNickname;
    private String targetType;
    private Long targetId;
    private String targetTitle;
    private String reason;
    private String evidence;
    private String status;
    private String handleResult;
    private LocalDateTime createdAt;
}
