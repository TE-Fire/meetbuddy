package com.tefire.meetbuddy.controller;

import com.tefire.meetbuddy.common.Result;
import com.tefire.meetbuddy.common.UserContext;
import com.tefire.meetbuddy.dto.BuddyCreateRequest;
import com.tefire.meetbuddy.service.BuddyService;
import com.tefire.meetbuddy.vo.BuddyMatchVO;
import com.tefire.meetbuddy.vo.BuddyVO;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.util.List;

@RestController
@RequestMapping("/api/buddy")
@Validated
@RequiredArgsConstructor
public class BuddyController {

    /** 未传半径时的默认值，10 公里对同城场景是个合理起点 */
    private static final double DEFAULT_RADIUS_KM = 10.0;

    private final BuddyService buddyService;

    @PostMapping
    public Result<Long> create(@Valid @RequestBody BuddyCreateRequest request) {
        return Result.ok(buddyService.create(UserContext.getUserId(), request));
    }

    @GetMapping
    public Result<List<BuddyVO>> mine() {
        return Result.ok(buddyService.mine(UserContext.getUserId()));
    }

    @PutMapping("/{id}/close")
    public Result<Void> close(@PathVariable Long id) {
        buddyService.close(UserContext.getUserId(), id);
        return Result.ok();
    }

    /**
     * 加权匹配。候选取自 Redis GEO，排序按 docs/01 第七节的公式。
     * radius 单位为公里，取值区间 [0.5, 500]，与活动流保持一致（见 ActivityController.list 的说明）。
     */
    @GetMapping("/match")
    public Result<List<BuddyMatchVO>> match(
            @RequestParam BigDecimal lng,
            @RequestParam BigDecimal lat,
            @RequestParam(defaultValue = "10") @DecimalMin("0.5") @DecimalMax("500") double radius,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int limit) {
        return Result.ok(buddyService.match(UserContext.getUserId(), lng, lat, radius, limit));
    }
}
