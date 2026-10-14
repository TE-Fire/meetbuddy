package com.tefire.meetbuddy.vo;

import lombok.Data;

import java.util.List;

/** 看板聚合响应，一次返回全部口径（docs/04 第六节）。 */
@Data
public class AdminDashboardVO {

    private long totalUsers;
    private long totalActivities;
    private long openActivities;
    private long pendingReports;

    private List<DailyCount> trend;
    private List<CategoryCount> categories;
    private List<RegionCount> regions;
}
