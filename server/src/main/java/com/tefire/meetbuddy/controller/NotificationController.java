package com.tefire.meetbuddy.controller;

import com.tefire.meetbuddy.common.PageVO;
import com.tefire.meetbuddy.common.Result;
import com.tefire.meetbuddy.common.UserContext;
import com.tefire.meetbuddy.service.NotificationService;
import com.tefire.meetbuddy.vo.NotificationVO;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 站内通知。路径 {@code /api/notification/**}，由 {@code AuthInterceptor} 统一要求登录。
 * 规则见 {@code docs/05-通知与提醒.md}。
 */
@RestController
@RequestMapping("/api/notification")
@RequiredArgsConstructor
@Validated
public class NotificationController {

    private final NotificationService notificationService;

    @GetMapping
    public Result<PageVO<NotificationVO>> list(
            @RequestParam(defaultValue = "1") @Min(1) long page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) long size) {
        return Result.ok(notificationService.list(UserContext.getUserId(), page, size));
    }

    @GetMapping("/unread")
    public Result<Long> unread() {
        return Result.ok(notificationService.unread(UserContext.getUserId()));
    }

    @PostMapping("/{id}/read")
    public Result<Void> markRead(@PathVariable Long id) {
        notificationService.markRead(UserContext.getUserId(), id);
        return Result.ok();
    }

    @PostMapping("/read-all")
    public Result<Long> readAll() {
        return Result.ok(notificationService.markAllRead(UserContext.getUserId()));
    }
}
