package com.tefire.meetbuddy.vo;

import lombok.Data;

import java.util.List;

/** 用户详情：基本信息 + 信用分流水 + 举报历史。 */
@Data
public class AdminUserDetailVO {

    private AdminUserVO user;
    private List<CreditLogVO> creditLogs;
    private List<AdminReportVO> reports;
}
