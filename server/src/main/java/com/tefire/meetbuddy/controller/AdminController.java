package com.tefire.meetbuddy.controller;

import com.tefire.meetbuddy.common.PageVO;
import com.tefire.meetbuddy.common.Result;
import com.tefire.meetbuddy.common.UserContext;
import com.tefire.meetbuddy.common.error.CommonErrorCode;
import com.tefire.meetbuddy.dto.AdminBanRequest;
import com.tefire.meetbuddy.dto.AdminCreditRequest;
import com.tefire.meetbuddy.dto.AdminReportHandleRequest;
import com.tefire.meetbuddy.dto.AdminTakedownRequest;
import com.tefire.meetbuddy.service.AdminService;
import com.tefire.meetbuddy.vo.AdminActivityVO;
import com.tefire.meetbuddy.vo.AdminDashboardVO;
import com.tefire.meetbuddy.vo.AdminReportVO;
import com.tefire.meetbuddy.vo.AdminUserDetailVO;
import com.tefire.meetbuddy.vo.AdminUserVO;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/admin")
@RequiredArgsConstructor
@Validated
public class AdminController {

    private static final long DEFAULT_PAGE = 1;
    private static final long DEFAULT_SIZE = 20;
    private static final long MAX_SIZE = 100;

    private final AdminService adminService;

    @GetMapping("/dashboard")
    public Result<AdminDashboardVO> dashboard() {
        return Result.ok(adminService.dashboard());
    }

    @GetMapping("/activity")
    public Result<PageVO<AdminActivityVO>> activities(
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String keyword,
            @RequestParam(defaultValue = "1") long page,
            @RequestParam(defaultValue = "20") long size) {
        size = Math.min(size, MAX_SIZE);
        return Result.ok(adminService.listActivities(status, keyword, page, size));
    }

    @PostMapping("/activity/{id}/takedown")
    public Result<Void> takedown(@PathVariable Long id, @Valid @RequestBody AdminTakedownRequest request) {
        adminService.takedown(id, request.reason(), UserContext.getUserId());
        return Result.ok();
    }

    @PostMapping("/activity/{id}/restore")
    public Result<Void> restore(@PathVariable Long id) {
        adminService.restore(id);
        return Result.ok();
    }

    @GetMapping("/report")
    public Result<PageVO<AdminReportVO>> reports(
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "1") long page,
            @RequestParam(defaultValue = "20") long size) {
        size = Math.min(size, MAX_SIZE);
        return Result.ok(adminService.listReports(status, page, size));
    }

    @PostMapping("/report/{id}/handle")
    public Result<Void> handleReport(@PathVariable Long id, @Valid @RequestBody AdminReportHandleRequest request) {
        adminService.handleReport(id, request.approved(), request.handleResult(), UserContext.getUserId());
        return Result.ok();
    }

    @GetMapping("/user")
    public Result<PageVO<AdminUserVO>> users(
            @RequestParam(required = false) String keyword,
            @RequestParam(defaultValue = "1") long page,
            @RequestParam(defaultValue = "20") long size) {
        size = Math.min(size, MAX_SIZE);
        return Result.ok(adminService.listUsers(keyword, page, size));
    }

    @GetMapping("/user/{id}")
    public Result<AdminUserDetailVO> userDetail(@PathVariable Long id) {
        return Result.ok(adminService.userDetail(id));
    }

    @PostMapping("/user/{id}/ban")
    public Result<Void> ban(@PathVariable Long id, @Valid @RequestBody AdminBanRequest request) {
        adminService.ban(id, request.reason(), UserContext.getUserId());
        return Result.ok();
    }

    @PostMapping("/user/{id}/unban")
    public Result<Void> unban(@PathVariable Long id) {
        adminService.unban(id);
        return Result.ok();
    }

    @PostMapping("/user/{id}/credit")
    public Result<Void> credit(@PathVariable Long id, @Valid @RequestBody AdminCreditRequest request) {
        adminService.adjustCredit(id, request.changeValue(), request.reason(), UserContext.getUserId());
        return Result.ok();
    }
}
