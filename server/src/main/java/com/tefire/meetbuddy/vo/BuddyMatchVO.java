package com.tefire.meetbuddy.vo;

import lombok.Data;

import java.util.List;

/**
 * 匹配结果项。
 *
 * <p>{@code reason} 是给前端直接展示的一句话解释。只返回一个分数的话，
 * 用户没法判断为什么要联系这个人，产品的说服力会大打折扣。
 */
@Data
public class BuddyMatchVO {

    /** 发布者 */
    private Long userId;

    private String nickname;

    private String avatar;

    private Integer creditScore;

    /** 搭子需求 */
    private Long requestId;

    private String title;

    private String category;

    private String timeRange;

    /** 总分，[0,1] */
    private double score;

    /** 直线距离，单位公里 */
    private double distance;

    private List<String> commonTags;

    private String reason;
}
