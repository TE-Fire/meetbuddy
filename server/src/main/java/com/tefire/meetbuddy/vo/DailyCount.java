package com.tefire.meetbuddy.vo;

import lombok.Data;

/** 看板趋势的单日三项计数：新增活动 / 报名 / 消息。 */
@Data
public class DailyCount {
    private String date;
    private Long activityCount;
    private Long signupCount;
    private Long messageCount;
}
