package com.tefire.meetbuddy.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

/** 搭子需求。没有人数上限与截止时间，这是它与活动最本质的区别，也是两者不合并成一张表的原因。 */
@Data
public class BuddyCreateRequest {

    @NotBlank
    @Size(max = 64)
    private String title;

    @Size(max = 2000)
    private String description;

    @NotBlank
    private String category;

    @NotNull
    private BigDecimal lng;

    @NotNull
    private BigDecimal lat;

    /** 自由文本，如"周末下午" */
    private String timeRange;

    private List<String> tags;
}
