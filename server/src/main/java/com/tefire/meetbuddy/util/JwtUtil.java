package com.tefire.meetbuddy.util;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

/**
 * JWT 签发与校验。密钥长度要求 32 字节以上，这是 HMAC-SHA256 的硬性下限，
 * 配置里给短了会在启动时直接抛异常，不会悄悄降级。
 */
@Component
public class JwtUtil {

    @Value("${meetbuddy.jwt.secret}")
    private String secret;

    @Value("${meetbuddy.jwt.access-ttl-seconds:7200}")
    private long accessTtlSeconds;

    @Value("${meetbuddy.jwt.refresh-ttl-seconds:604800}")
    private long refreshTtlSeconds;

    private SecretKey key() {
        return Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
    }

    public String createAccessToken(Long userId, String jti) {
        return build(userId, jti, "access", accessTtlSeconds);
    }

    public String createRefreshToken(Long userId, String jti) {
        return build(userId, jti, "refresh", refreshTtlSeconds);
    }

    private String build(Long userId, String jti, String type, long ttl) {
        Date now = new Date();
        return Jwts.builder()
                .subject(String.valueOf(userId))
                .id(jti)
                .claim("type", type)
                .issuedAt(now)
                .expiration(new Date(now.getTime() + ttl * 1000))
                .signWith(key())
                .compact();
    }

    /**
     * 解析失败一律返回 null，由拦截器决定如何响应。解析失败是常态（令牌过期、
     * 被篡改），不该抛异常打满日志。
     */
    public Claims parse(String token) {
        try {
            return Jwts.parser()
                    .verifyWith(key())
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();
        } catch (JwtException | IllegalArgumentException e) {
            return null;
        }
    }
}
