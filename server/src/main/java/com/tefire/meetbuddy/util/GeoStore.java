package com.tefire.meetbuddy.util;

import lombok.RequiredArgsConstructor;
import org.springframework.data.geo.Circle;
import org.springframework.data.geo.Distance;
import org.springframework.data.geo.GeoResult;
import org.springframework.data.geo.GeoResults;
import org.springframework.data.geo.Metrics;
import org.springframework.data.geo.Point;
import org.springframework.data.redis.connection.RedisGeoCommands;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Redis GEO 的薄封装。
 *
 * <p>GEO 只用来做"半径内圈人"这一件事：它把绝大多数无关候选一次性过滤掉，
 * 剩下的几十条再做加权排序。反过来先把全表拉出来逐条算距离，数据量一大就废了。
 *
 * <p>三个 key 分开存，因为用户、活动、搭子需求的候选集互不相干，
 * 混在一个 key 里就得在结果里再按类型过滤一遍。
 */
@Component
@RequiredArgsConstructor
public class GeoStore {

    public static final String USER_KEY = "geo:user";
    public static final String ACTIVITY_KEY = "geo:activity";
    public static final String BUDDY_KEY = "geo:buddy";

    private final StringRedisTemplate redis;

    public void upsert(String key, Long id, BigDecimal lng, BigDecimal lat) {
        if (id == null || lng == null || lat == null) {
            return;
        }
        redis.opsForGeo().add(key, new Point(lng.doubleValue(), lat.doubleValue()), id.toString());
    }

    public void remove(String key, Long id) {
        redis.opsForGeo().remove(key, id.toString());
    }

    /**
     * 取半径内的成员及距离。
     *
     * @param radiusKm 半径，单位公里
     * @return 成员 id 到距离的映射，按距离由近到远排序
     */
    public Map<Long, Double> nearby(String key, BigDecimal lng, BigDecimal lat, double radiusKm) {
        Circle circle = new Circle(new Point(lng.doubleValue(), lat.doubleValue()),
                new Distance(radiusKm, Metrics.KILOMETERS));
        GeoResults<RedisGeoCommands.GeoLocation<String>> results =
                redis.opsForGeo().radius(key, circle,
                        RedisGeoCommands.GeoRadiusCommandArgs.newGeoRadiusArgs()
                                .includeDistance()
                                .sortAscending());
        Map<Long, Double> out = new LinkedHashMap<>();
        if (results == null) {
            return out;
        }
        for (GeoResult<RedisGeoCommands.GeoLocation<String>> r : results.getContent()) {
            String member = r.getContent().getName();
            double km = r.getDistance().getValue();
            out.put(Long.parseLong(member), km);
        }
        return out;
    }

    /** 批量取，用于一次拿到多个成员后再算距离的场景。 */
    public List<String> members(String key) {
        return redis.opsForZSet().range(key, 0, -1) == null
                ? List.of()
                : List.copyOf(redis.opsForZSet().range(key, 0, -1));
    }
}
