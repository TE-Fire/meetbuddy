package com.tefire.meetbuddy.vo;

import lombok.Data;

/** 单日计数，看板趋势用。 */
@Data
public class DayCount {
    private String date;
    private Long count;
}
