package com.tefire.meetbuddy.controller;

import com.tefire.meetbuddy.common.PageVO;
import com.tefire.meetbuddy.common.Result;
import com.tefire.meetbuddy.common.UserContext;
import com.tefire.meetbuddy.dto.ActivityCreateRequest;
import com.tefire.meetbuddy.dto.AttendRequest;
import com.tefire.meetbuddy.dto.SignupRequest;
import com.tefire.meetbuddy.service.ActivityService;
import com.tefire.meetbuddy.service.SignupService;
import com.tefire.meetbuddy.vo.ActivityDetailVO;
import com.tefire.meetbuddy.vo.ActivityVO;
import com.tefire.meetbuddy.vo.CreateActivityVO;
import com.tefire.meetbuddy.vo.ParticipantVO;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

import java.math.BigDecimal;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.validation.annotation.Validated;
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
@RequestMapping("/api/activity")
@Validated
@RequiredArgsConstructor
public class ActivityController {

    private static final long DEFAULT_PAGE = 1;
    private static final long DEFAULT_SIZE = 20;
    private static final long MAX_SIZE = 100;

    private final ActivityService activityService;
    private final SignupService signupService;

    /** 关掉即可复现超卖，M7 压测实验的对照组用；生产必须保持 true */
    @Value("${meetbuddy.signup.lock-enabled:true}")
    private boolean signupLockEnabled;

    @PostMapping
    public Result<CreateActivityVO> create(@Valid @RequestBody ActivityCreateRequest request) {
        return Result.ok(activityService.create(UserContext.getUserId(), request));
    }

    /**
     * 活动流。传 lng/lat/radius 时先由 Redis GEO 圈出半径内的活动，再按分类与状态过滤，
     * 结果按距离由近到远；不传坐标则退化为按发布时间倒序的纯分页列表。
     *
     * <p>radius 单位公里，取值区间 [0.5, 500]（见 docs/03 第四节）。下界给到 0.5 是为了
     * 「附近 500m」这类精搜；上界 500 是「同城 + 周边城市」，再远就不属于组局的场景了。
     * 这里用 @DecimalMin/@DecimalMax 而不是 @Min/@Max —— 后者声明的是 long，对 double
     * 只能做整数比较，0.5 这种小数会被判成 0 直接拒掉。
     */
    @GetMapping
    public Result<PageVO<ActivityVO>> list(
            @RequestParam(required = false) String category,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) BigDecimal lng,
            @RequestParam(required = false) BigDecimal lat,
            @RequestParam(required = false) @DecimalMin("0.5") @DecimalMax("500") Double radius,
            @RequestParam(defaultValue = "1") @Min(1) long page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) long size) {
        return Result.ok(activityService.list(category, status, keyword, lng, lat, radius, page, size));
    }

    @GetMapping("/mine/organized")
    public Result<PageVO<ActivityVO>> mineOrganized(
            @RequestParam(defaultValue = "1") long page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(MAX_SIZE) long size) {
        return Result.ok(activityService.mineOrganized(UserContext.getUserId(), page, size));
    }

    @GetMapping("/mine/joined")
    public Result<PageVO<ActivityVO>> mineJoined(
            @RequestParam(defaultValue = "1") long page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(MAX_SIZE) long size) {
        return Result.ok(activityService.mineJoined(UserContext.getUserId(), page, size));
    }

    @GetMapping("/{id}")
    public Result<ActivityDetailVO> detail(@PathVariable Long id) {
        return Result.ok(activityService.detail(id, UserContext.getUserId()));
    }

    @PutMapping("/{id}")
    public Result<Void> update(@PathVariable Long id, @Valid @RequestBody ActivityCreateRequest request) {
        activityService.update(UserContext.getUserId(), id, request);
        return Result.ok();
    }

    @PostMapping("/{id}/cancel")
    public Result<Void> cancel(@PathVariable Long id) {
        activityService.cancel(UserContext.getUserId(), id);
        return Result.ok();
    }

    /** 并发防超员的唯一入口，M2 的压测打这里。 */
    @PostMapping("/{id}/signup")
    public Result<Void> signup(@PathVariable Long id, @RequestBody(required = false) SignupRequest request) {
        String remark = request == null ? null : request.getRemark();
        signupService.signup(UserContext.getUserId(), id, remark, signupLockEnabled);
        return Result.ok();
    }

    @DeleteMapping("/{id}/signup")
    public Result<Void> cancelSignup(@PathVariable Long id) {
        signupService.cancelSignup(UserContext.getUserId(), id);
        return Result.ok();
    }

    @GetMapping("/{id}/participants")
    public Result<PageVO<ParticipantVO>> participants(
            @PathVariable Long id,
            @RequestParam(defaultValue = "1") long page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(MAX_SIZE) long size) {
        return Result.ok(activityService.participants(id, page, size));
    }

    @PostMapping("/{id}/attend")
    public Result<Void> attend(@PathVariable Long id, @Valid @RequestBody AttendRequest request) {
        signupService.confirmAttend(UserContext.getUserId(), id, request.getAttended(), request.getAbsent());
        return Result.ok();
    }

    @PostMapping("/{id}/favorite")
    public Result<Void> favorite(@PathVariable Long id) {
        activityService.favorite(UserContext.getUserId(), id);
        return Result.ok();
    }

    @DeleteMapping("/{id}/favorite")
    public Result<Void> unfavorite(@PathVariable Long id) {
        activityService.unfavorite(UserContext.getUserId(), id);
        return Result.ok();
    }
}
