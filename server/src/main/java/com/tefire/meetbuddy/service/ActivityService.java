package com.tefire.meetbuddy.service;

import com.tefire.meetbuddy.common.PageVO;
import com.tefire.meetbuddy.dto.ActivityCreateRequest;
import com.tefire.meetbuddy.vo.ActivityDetailVO;
import com.tefire.meetbuddy.vo.ActivityVO;
import com.tefire.meetbuddy.vo.CreateActivityVO;
import com.tefire.meetbuddy.vo.ParticipantVO;

import java.math.BigDecimal;

public interface ActivityService {

    /** 发布活动，同时建群并把组织者以 OWNER 身份拉进群。 */
    CreateActivityVO create(Long userId, ActivityCreateRequest request);

    /**
     * 活动流。
     * <p>传了 lng/lat/radius 就先走 Redis GEO 圈出半径内的活动，再叠加分类与状态过滤；
     * 不传则退化为纯分页列表。keyword 非空时按标题模糊搜索，与其余条件叠加。
     *
     * @param sortBy 排序方式：latest（默认，按发布时间倒序）、hot（按报名人数倒序）、
     *               distance（仅 geo 模式按距离由近到远，非 geo 模式降级为 latest）
     */
    PageVO<ActivityVO> list(String category, String status, String keyword,
                            BigDecimal lng, BigDecimal lat, Double radiusKm,
                            String sortBy, long page, long size);

    ActivityDetailVO detail(Long activityId, Long currentUserId);

    void update(Long userId, Long activityId, ActivityCreateRequest request);

    void cancel(Long userId, Long activityId);

    PageVO<ActivityVO> mineOrganized(Long userId, long page, long size);

    PageVO<ActivityVO> mineJoined(Long userId, long page, long size);

    PageVO<ParticipantVO> participants(Long activityId, long page, long size);

    void favorite(Long userId, Long activityId);

    void unfavorite(Long userId, Long activityId);
}
