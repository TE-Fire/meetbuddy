package com.tefire.meetbuddy.service;

import com.tefire.meetbuddy.dto.BuddyCreateRequest;
import com.tefire.meetbuddy.vo.BuddyMatchVO;
import com.tefire.meetbuddy.vo.BuddyVO;

import java.math.BigDecimal;
import java.util.List;

public interface BuddyService {

    Long create(Long userId, BuddyCreateRequest request);

    List<BuddyVO> mine(Long userId);

    void close(Long userId, Long requestId);

    /**
     * 加权匹配，取 Top N。权重与算式见 docs/01 第七节。
     *
     * @param radiusKm 搜索半径，单位公里
     * @param limit    返回条数
     */
    List<BuddyMatchVO> match(Long userId, BigDecimal lng, BigDecimal lat, double radiusKm, int limit);
}
