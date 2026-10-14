package com.tefire.meetbuddy.controller;

import com.tefire.meetbuddy.common.Result;
import com.tefire.meetbuddy.common.UserContext;
import com.tefire.meetbuddy.dto.ReportSubmitRequest;
import com.tefire.meetbuddy.entity.Report;
import com.tefire.meetbuddy.mapper.ReportMapper;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/report")
@RequiredArgsConstructor
@Validated
public class ReportController {

    private final ReportMapper reportMapper;

    /**
     * 用户端举报入口（M6 决策 3）。reporter 一律取令牌，不从请求体读，
     * 避免越权替别人举报。证据为图片 URL，逗号分隔，可空。
     */
    @PostMapping
    public Result<Void> submit(@Valid @RequestBody ReportSubmitRequest request) {
        Report report = new Report();
        report.setReporterId(UserContext.getUserId());
        report.setTargetType(request.targetType());
        report.setTargetId(request.targetId());
        report.setReason(request.reason());
        report.setEvidence(request.evidence());
        report.setStatus("PENDING");
        reportMapper.insert(report);
        return Result.ok();
    }
}
