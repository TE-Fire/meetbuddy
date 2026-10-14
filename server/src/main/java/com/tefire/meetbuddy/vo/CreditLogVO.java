package com.tefire.meetbuddy.vo;

import lombok.Data;

import java.time.LocalDateTime;

/** 信用分流水条目。前端按正负号展示加减，reason 直接展示给用户（被扣分要看得见原因）。 */
@Data
public class CreditLogVO {

    private Long id;

    /** 正数为加，负数为减 */
    private Integer changeValue;

    private String reason;

    /** 关联活动或举报，前端可按 type 跳转 */
    private Long relatedId;

    /** 管理端调整时非空 */
    private Long operatorId;

    private Integer balanceAfter;

    private LocalDateTime createdAt;
}
