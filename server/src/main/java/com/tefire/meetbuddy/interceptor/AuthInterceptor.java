package com.tefire.meetbuddy.interceptor;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.tefire.meetbuddy.common.Result;
import com.tefire.meetbuddy.common.error.CommonErrorCode;
import com.tefire.meetbuddy.common.error.IErrorCode;
import com.tefire.meetbuddy.common.UserContext;
import com.tefire.meetbuddy.util.JwtUtil;
import io.jsonwebtoken.Claims;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;
import org.springframework.web.cors.CorsUtils;
import org.springframework.web.servlet.HandlerInterceptor;

/**
 * 登录校验。黑名单放在这里而不是靠令牌自然过期：封禁用户必须立刻失效，
 * 否则"封禁"功能在令牌过期前形同虚设。
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class AuthInterceptor implements HandlerInterceptor {

    private static final String BLACKLIST_PREFIX = "jwt:blacklist:";
    private static final String BAN_PREFIX = "ban:user:";
    private static final String BEARER = "Bearer ";

    private final JwtUtil jwtUtil;
    private final StringRedisTemplate redisTemplate;
    private final ObjectMapper objectMapper;

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler)
            throws Exception {
        // 预检请求按规范不带 Authorization 头，也拿不到令牌——浏览器发 OPTIONS 时先放行，
        // 真正的鉴权落在紧随其后的那个真实请求上。不放过这里，前端所有带 JSON 体的调用都会死在预检。
        if (CorsUtils.isPreFlightRequest(request)) {
            return true;
        }

        String header = request.getHeader("Authorization");
        if (header == null || !header.startsWith(BEARER)) {
            reject(response, CommonErrorCode.UNAUTHORIZED);
            return false;
        }

        Claims claims = jwtUtil.parse(header.substring(BEARER.length()));
        if (claims == null || !"access".equals(claims.get("type"))) {
            reject(response, CommonErrorCode.UNAUTHORIZED);
            return false;
        }

        if (Boolean.TRUE.equals(redisTemplate.hasKey(BLACKLIST_PREFIX + claims.getId()))) {
            reject(response, CommonErrorCode.UNAUTHORIZED);
            return false;
        }

        // 按人维度的封禁键：封禁时写入、TTL 等于 access 有效期上限，过期自动解除。
        // 命中说明该用户被管理端封禁，立即拦在新动作之前（登录、发布、报名、发言都会被挡）。
        if (Boolean.TRUE.equals(redisTemplate.hasKey(BAN_PREFIX + claims.getSubject()))) {
            reject(response, CommonErrorCode.USER_BANNED);
            return false;
        }

        UserContext.setUserId(Long.valueOf(claims.getSubject()));
        UserContext.setRole(claims.get("role") == null ? 0 : ((Number) claims.get("role")).intValue());
        return true;
    }

    @Override
    public void afterCompletion(HttpServletRequest request, HttpServletResponse response,
                                Object handler, Exception ex) {
        UserContext.clear();
    }

    private void reject(HttpServletResponse response, IErrorCode code) throws Exception {
        response.setStatus(HttpServletResponse.SC_OK);
        response.setContentType("application/json;charset=UTF-8");
        response.getWriter().write(objectMapper.writeValueAsString(Result.fail(code)));
    }
}
