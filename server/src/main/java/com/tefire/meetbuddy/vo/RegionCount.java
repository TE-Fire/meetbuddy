package com.tefire.meetbuddy.vo;

import lombok.Data;

/** 用户地域分布项（按预设城市围栏就近归类）。 */
@Data
public class RegionCount {
    private String region;
    private Long count;
}
