package com.tefire.meetbuddy.service;

import com.tefire.meetbuddy.common.PageVO;
import com.tefire.meetbuddy.vo.AdminActivityVO;
import com.tefire.meetbuddy.vo.AdminDashboardVO;
import com.tefire.meetbuddy.vo.AdminReportVO;
import com.tefire.meetbuddy.vo.AdminUserDetailVO;
import com.tefire.meetbuddy.vo.AdminUserVO;

public interface AdminService {

    AdminDashboardVO dashboard();

    PageVO<AdminActivityVO> listActivities(String status, String keyword, long page, long size);

    void takedown(Long activityId, String reason, Long adminId);

    void restore(Long activityId);

    PageVO<AdminReportVO> listReports(String status, long page, long size);

    void handleReport(Long reportId, boolean approved, String handleResult, Long adminId);

    PageVO<AdminUserVO> listUsers(String keyword, long page, long size);

    AdminUserDetailVO userDetail(Long userId);

    void ban(Long userId, String reason, Long adminId);

    void unban(Long userId);

    void adjustCredit(Long userId, int changeValue, String reason, Long adminId);
}
