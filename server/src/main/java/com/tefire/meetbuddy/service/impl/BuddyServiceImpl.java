package com.tefire.meetbuddy.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.tefire.meetbuddy.common.error.BizAssert;
import com.tefire.meetbuddy.common.error.CommonErrorCode;
import com.tefire.meetbuddy.dto.BuddyCreateRequest;
import com.tefire.meetbuddy.entity.BuddyRequest;
import com.tefire.meetbuddy.entity.BuddyTag;
import com.tefire.meetbuddy.entity.User;
import com.tefire.meetbuddy.entity.UserTag;
import com.tefire.meetbuddy.mapper.BuddyRequestMapper;
import com.tefire.meetbuddy.mapper.BuddyTagMapper;
import com.tefire.meetbuddy.mapper.UserMapper;
import com.tefire.meetbuddy.mapper.UserTagMapper;
import com.tefire.meetbuddy.service.BuddyService;
import com.tefire.meetbuddy.util.GeoStore;
import com.tefire.meetbuddy.vo.BuddyMatchVO;
import com.tefire.meetbuddy.vo.BuddyVO;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * 搭子需求的发布与匹配。
 *
 * <p>匹配的顺序是"GEO 先圈人，再加权排序"：Redis GEO 把半径外的候选一次性滤掉，
 * 剩下的通常只有几十条，加权计算在内存里做。反过来先拉全表再逐条算距离，数据量一大就废了。
 */
@Service
@RequiredArgsConstructor
public class BuddyServiceImpl implements BuddyService {

    /** 权重，见 docs/01 第七节 */
    private static final double W_DISTANCE = 0.4;
    private static final double W_TAG = 0.3;
    private static final double W_TIME = 0.2;
    private static final double W_CREDIT = 0.1;

    private final BuddyRequestMapper buddyRequestMapper;
    private final BuddyTagMapper buddyTagMapper;
    private final UserTagMapper userTagMapper;
    private final UserMapper userMapper;
    private final GeoStore geoStore;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Long create(Long userId, BuddyCreateRequest request) {
        BuddyRequest entity = new BuddyRequest();
        entity.setUserId(userId);
        entity.setTitle(request.getTitle());
        entity.setDescription(request.getDescription());
        entity.setCategory(request.getCategory());
        entity.setLng(request.getLng());
        entity.setLat(request.getLat());
        entity.setTimeRange(request.getTimeRange());
        entity.setStatus("OPEN");
        buddyRequestMapper.insert(entity);

        saveTags(entity.getId(), request.getTags());
        geoStore.upsert(GeoStore.BUDDY_KEY, entity.getId(), request.getLng(), request.getLat());
        return entity.getId();
    }

    @Override
    public List<BuddyVO> mine(Long userId) {
        List<BuddyRequest> list = buddyRequestMapper.selectList(new LambdaQueryWrapper<BuddyRequest>()
                .eq(BuddyRequest::getUserId, userId)
                .orderByDesc(BuddyRequest::getCreatedAt));
        if (list.isEmpty()) {
            return Collections.emptyList();
        }
        List<Long> ids = list.stream().map(BuddyRequest::getId).toList();
        Map<Long, Set<String>> tags = loadBuddyTags(ids);
        User me = userMapper.selectById(userId);
        return list.stream().map(r -> {
            BuddyVO vo = new BuddyVO();
            vo.setId(r.getId());
            vo.setUserId(r.getUserId());
            vo.setTitle(r.getTitle());
            vo.setDescription(r.getDescription());
            vo.setCategory(r.getCategory());
            vo.setLng(r.getLng());
            vo.setLat(r.getLat());
            vo.setTimeRange(r.getTimeRange());
            vo.setStatus(r.getStatus());
            vo.setTags(new ArrayList<>(tags.getOrDefault(r.getId(), Set.of())));
            vo.setCreatedAt(r.getCreatedAt());
            if (me != null) {
                vo.setNickname(me.getNickname());
                vo.setAvatar(me.getAvatar());
                vo.setCreditScore(me.getCreditScore());
            }
            return vo;
        }).toList();
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void close(Long userId, Long requestId) {
        BuddyRequest entity = BizAssert.notNull(buddyRequestMapper.selectById(requestId),
                CommonErrorCode.NOT_FOUND, "需求不存在");
        if (!entity.getUserId().equals(userId)) {
            throw CommonErrorCode.FORBIDDEN.ex("只能关闭自己发布的需求");
        }
        entity.setStatus("CLOSED");
        buddyRequestMapper.updateById(entity);
        // 关了就要从 GEO 里摘掉，否则它还会出现在别人的匹配结果里
        geoStore.remove(GeoStore.BUDDY_KEY, requestId);
    }

    @Override
    public List<BuddyMatchVO> match(Long userId, BigDecimal lng, BigDecimal lat, double radiusKm, int limit) {
        Map<Long, Double> nearby = geoStore.nearby(GeoStore.BUDDY_KEY, lng, lat, radiusKm);
        if (nearby.isEmpty()) {
            return Collections.emptyList();
        }
        List<BuddyRequest> requests = buddyRequestMapper.selectBatchIds(nearby.keySet())
                .stream()
                .filter(r -> "OPEN".equals(r.getStatus()) && !r.getUserId().equals(userId))
                .toList();
        if (requests.isEmpty()) {
            return Collections.emptyList();
        }

        List<Long> ids = requests.stream().map(BuddyRequest::getId).toList();
        Map<Long, Set<String>> theirTags = loadBuddyTags(ids);
        Set<String> myTags = loadMyTags(userId);
        Map<Long, User> owners = loadUsers(requests.stream().map(BuddyRequest::getUserId).toList());

        List<BuddyMatchVO> scored = new ArrayList<>();
        for (BuddyRequest r : requests) {
            double distance = nearby.get(r.getId());
            Set<String> theirs = theirTags.getOrDefault(r.getId(), Set.of());
            Set<String> common = new HashSet<>(myTags);
            common.retainAll(theirs);

            double sDistance = Math.max(0, 1 - distance / radiusKm);
            double sTag = myTags.isEmpty() || theirs.isEmpty()
                    ? 0
                    : (double) common.size() / Math.min(myTags.size(), theirs.size());
            User owner = owners.get(r.getUserId());
            double sTime = freshnessScore(owner == null ? null : owner.getLastActiveAt());
            double sCredit = owner == null ? 0 : owner.getCreditScore() / 100.0;
            double score = W_DISTANCE * sDistance + W_TAG * sTag + W_TIME * sTime + W_CREDIT * sCredit;

            BuddyMatchVO vo = new BuddyMatchVO();
            vo.setUserId(r.getUserId());
            vo.setRequestId(r.getId());
            vo.setTitle(r.getTitle());
            vo.setCategory(r.getCategory());
            vo.setTimeRange(r.getTimeRange());
            vo.setScore(Math.round(score * 10000) / 10000.0);
            vo.setDistance(Math.round(distance * 100) / 100.0);
            vo.setCommonTags(new ArrayList<>(common));
            vo.setReason(buildReason(distance, common));
            if (owner != null) {
                vo.setNickname(owner.getNickname());
                vo.setAvatar(owner.getAvatar());
                vo.setCreditScore(owner.getCreditScore());
            }
            scored.add(vo);
        }

        return scored.stream()
                .sorted((a, b) -> Double.compare(b.getScore(), a.getScore()))
                .limit(limit)
                .toList();
    }

    /**
     * 时间维度用活跃新鲜度作代理。
     * 用户表里没有"空闲时段"字段，需求的 time_range 又是自由文本，做不了真正的时段求交；
     * 但一个一周没上线的搭子，再近也约不成，所以这一项必须有区分度。
     */
    private double freshnessScore(LocalDateTime lastActiveAt) {
        if (lastActiveAt == null) {
            return 0.1;
        }
        long hours = Duration.between(lastActiveAt, LocalDateTime.now()).toHours();
        if (hours <= 24) {
            return 1.0;
        }
        if (hours >= 24 * 7) {
            return 0.1;
        }
        // 24h -> 1.0 线性降到 7d -> 0.3
        return 1.0 - 0.7 * (hours - 24) / (24.0 * 6);
    }

    private String buildReason(double distance, Set<String> common) {
        StringBuilder sb = new StringBuilder("距离 ").append(Math.round(distance * 10) / 10.0).append("km");
        if (common.isEmpty()) {
            sb.append("，标签暂无重合");
        } else {
            sb.append("，都喜欢 ").append(String.join("、", common));
        }
        return sb.toString();
    }

    private void saveTags(Long requestId, List<String> tags) {
        if (tags == null) {
            return;
        }
        for (String tag : tags) {
            if (tag == null || tag.isBlank()) {
                continue;
            }
            BuddyTag entity = new BuddyTag();
            entity.setRequestId(requestId);
            entity.setTagName(tag.trim());
            entity.setCreatedAt(LocalDateTime.now());
            buddyTagMapper.insert(entity);
        }
    }

    private Map<Long, Set<String>> loadBuddyTags(List<Long> requestIds) {
        if (requestIds.isEmpty()) {
            return Collections.emptyMap();
        }
        Map<Long, Set<String>> map = new HashMap<>();
        buddyTagMapper.selectList(new LambdaQueryWrapper<BuddyTag>()
                        .in(BuddyTag::getRequestId, requestIds))
                .forEach(t -> map.computeIfAbsent(t.getRequestId(), k -> new HashSet<>()).add(t.getTagName()));
        return map;
    }

    private Set<String> loadMyTags(Long userId) {
        return userTagMapper.selectList(new LambdaQueryWrapper<UserTag>()
                        .eq(UserTag::getUserId, userId))
                .stream()
                .map(UserTag::getTagName)
                .collect(Collectors.toSet());
    }

    private Map<Long, User> loadUsers(List<Long> ids) {
        if (ids.isEmpty()) {
            return Collections.emptyMap();
        }
        List<User> users = userMapper.selectBatchIds(ids.stream().distinct().toList());
        return users.stream().collect(Collectors.toMap(User::getId, Function.identity(), (a, b) -> a));
    }
}
