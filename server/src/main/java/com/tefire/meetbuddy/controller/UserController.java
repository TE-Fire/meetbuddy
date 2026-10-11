package com.tefire.meetbuddy.controller;

import com.tefire.meetbuddy.common.Result;
import com.tefire.meetbuddy.common.UserContext;
import com.tefire.meetbuddy.dto.LocationRequest;
import com.tefire.meetbuddy.dto.TagsRequest;
import com.tefire.meetbuddy.service.UserService;
import com.tefire.meetbuddy.vo.UserVO;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/user")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    /**
     * M1 的鉴权验收入口：不带令牌访问这里应当返回 code=401，带上登录拿到的令牌应当返回自己的资料。
     */
    @GetMapping("/me")
    public Result<UserVO> me() {
        return Result.ok(userService.getCurrentProfile());
    }

    /** 上报坐标。App 每次进入前台或位置变化时调，同时刷新 GEO 与活跃时间。 */
    @PostMapping("/location")
    public Result<Void> location(@Valid @RequestBody LocationRequest request) {
        userService.updateLocation(UserContext.getUserId(), request.getLng(), request.getLat());
        return Result.ok();
    }

    @PutMapping("/tags")
    public Result<Void> tags(@Valid @RequestBody TagsRequest request) {
        userService.updateTags(UserContext.getUserId(), request.getTags());
        return Result.ok();
    }
}
