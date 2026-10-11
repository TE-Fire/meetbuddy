package com.tefire.meetbuddy.util;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.util.Collections;
import java.util.UUID;

/**
 * 基于 Redis 的最小可用分布式锁：SET NX PX 加锁，Lua 比对值再删除解锁。
 *
 * <p>没有引入 Redisson，原因是标签页式的毕设项目里 Redisson 的看门狗、可重入这些特性都用不上，
 * 多一个依赖反而增加打包体积和排障成本。这里只需要"互斥 + 不会误删别人的锁"两件事。
 *
 * <p>解锁必须用 Lua 比对 value：如果直接 DEL，线程 A 的锁超时后被线程 B 拿到，
 * A 再执行 DEL 就会把 B 的锁删掉，互斥失效。
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class RedisLock {

    private final StringRedisTemplate redis;

    private static final DefaultRedisScript<Long> UNLOCK_SCRIPT = new DefaultRedisScript<>(
            "if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end",
            Long.class);

    /**
     * 在等待窗口内反复尝试加锁。
     *
     * @return 锁令牌，拿到锁才能往下走；返回 null 表示等待超时未获取
     */
    public String tryLock(String key, Duration ttl, Duration wait) {
        String token = UUID.randomUUID().toString();
        long deadline = System.currentTimeMillis() + wait.toMillis();
        while (true) {
            Boolean ok = redis.opsForValue().setIfAbsent(key, token, ttl);
            if (Boolean.TRUE.equals(ok)) {
                return token;
            }
            if (System.currentTimeMillis() >= deadline) {
                log.warn("获取锁超时 key={} wait={}ms", key, wait.toMillis());
                return null;
            }
            try {
                Thread.sleep(20);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                return null;
            }
        }
    }

    public void unlock(String key, String token) {
        if (token == null) {
            return;
        }
        try {
            redis.execute(UNLOCK_SCRIPT, Collections.singletonList(key), token);
        } catch (Exception e) {
            log.error("解锁失败 key={}", key, e);
        }
    }
}
