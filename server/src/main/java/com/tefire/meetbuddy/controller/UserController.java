package com.tefire.meetbuddy.controller;

import com.tefire.meetbuddy.common.PageVO;
import com.tefire.meetbuddy.common.Result;
import com.tefire.meetbuddy.common.UserContext;
import com.tefire.meetbuddy.dto.LocationRequest;
import com.tefire.meetbuddy.dto.ProfileUpdateRequest;
import com.tefire.meetbuddy.dto.TagsRequest;
import com.tefire.meetbuddy.service.FollowService;
import com.tefire.meetbuddy.service.UserProfileService;
import com.tefire.meetbuddy.service.UserService;
import com.tefire.meetbuddy.vo.CreditLogVO;
import com.tefire.meetbuddy.vo.UserBriefVO;
import com.tefire.meetbuddy.vo.UserProfileVO;
import com.tefire.meetbuddy.vo.UserVO;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/user")
@RequiredArgsConstructor
public class UserController {

    private static final long MAX_SIZE = 100;

    private final UserService userService;
    private final UserProfileService userProfileService;
    private final FollowService followService;

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

    /** 编辑个人资料（昵称/简介/性别均可选，null 不改），返回更新后的资料供前端刷新缓存 */
    @PutMapping("/profile")
    public Result<UserVO> profile(@Valid @RequestBody ProfileUpdateRequest request) {
        return Result.ok(userService.updateProfile(
                UserContext.getUserId(), request.nickname(), request.bio(), request.gender(), request.avatar()));
    }

    /** 我的信用分明细，按时间倒序 */
    @GetMapping("/credit/logs")
    public Result<PageVO<CreditLogVO>> creditLogs(
            @RequestParam(defaultValue = "1") @Min(1) long page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) long size) {
        return Result.ok(userService.creditLogs(UserContext.getUserId(), page, size));
    }

    /**
     * 他人个人主页。手机号等隐私字段不返回，人不存在返回 1003。规则见 docs/06。
     * 与 {@code /profile}（改自己）不冲突：前者是 {@code /{id}/profile} 路径段。
     */
    @GetMapping("/{id}/profile")
    public Result<UserProfileVO> profile(@PathVariable Long id) {
        return Result.ok(userProfileService.getProfile(id, UserContext.getUserId()));
    }

    /** 关注某人；幂等，不能关注自己。成功给对方落一条 USER_FOLLOWED 通知。规则见 docs/13 */
    @PostMapping("/{id}/follow")
    public Result<Void> follow(@PathVariable Long id) {
        followService.follow(UserContext.getUserId(), id);
        return Result.ok();
    }

    /** 取关；幂等。 */
    @DeleteMapping("/{id}/follow")
    public Result<Void> unfollow(@PathVariable Long id) {
        followService.unfollow(UserContext.getUserId(), id);
        return Result.ok();
    }

    /** 某人的粉丝列表 */
    @GetMapping("/{id}/followers")
    public Result<PageVO<UserBriefVO>> followers(
            @PathVariable Long id,
            @RequestParam(defaultValue = "1") @Min(1) long page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(MAX_SIZE) long size) {
        return Result.ok(followService.followers(id, page, size));
    }

    /** 某人的关注列表 */
    @GetMapping("/{id}/following")
    public Result<PageVO<UserBriefVO>> following(
            @PathVariable Long id,
            @RequestParam(defaultValue = "1") @Min(1) long page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(MAX_SIZE) long size) {
        return Result.ok(followService.following(id, page, size));
    }
}
