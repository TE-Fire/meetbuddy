package com.tefire.meetbuddy.controller;

import com.tefire.meetbuddy.common.Result;
import com.tefire.meetbuddy.common.UserContext;
import com.tefire.meetbuddy.service.BadgeService;
import com.tefire.meetbuddy.vo.BadgeVO;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 成就徽章。路径 {@code /api/badge/**}，由 {@code AuthInterceptor} 统一要求登录。
 * 规则见 {@code docs/06-成就勋章与个人主页.md}。
 */
@RestController
@RequestMapping("/api/badge")
@RequiredArgsConstructor
public class BadgeController {

    private final BadgeService badgeService;

    /** 我的徽章：全部（含未解锁与进度），按 BadgeEnum 枚举序 */
    @GetMapping("/mine")
    public Result<List<BadgeVO>> mine() {
        return Result.ok(badgeService.myBadges(UserContext.getUserId()));
    }
}
