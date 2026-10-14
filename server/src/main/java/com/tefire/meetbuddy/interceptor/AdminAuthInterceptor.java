package com.tefire.meetbuddy.interceptor;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.tefire.meetbuddy.common.Result;
import com.tefire.meetbuddy.common.UserContext;
import com.tefire.meetbuddy.common.error.CommonErrorCode;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

/**
 * 管理端权限闸门，只守 {@code /admin/**}。
 *
 * <p>前置条件由 {@link AuthInterceptor} 保证：它已被注册到 {@code /admin/**}，会先完成
 * 令牌解析、黑名单、封禁检查，并写入 {@link UserContext#getRole()}。本拦截器只做一件事——
 * 拿到 role，不是管理员（≠1）一律 403。顺序上它在 AuthInterceptor 之后注册，所以一定能
 * 读到已就绪的 UserContext。
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class AdminAuthInterceptor implements HandlerInterceptor {

    private final ObjectMapper objectMapper;

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler)
            throws Exception {
        Integer role = UserContext.getRole();
        if (role == null || role != 1) {
            response.setStatus(HttpServletResponse.SC_OK);
            response.setContentType("application/json;charset=UTF-8");
            response.getWriter().write(objectMapper.writeValueAsString(Result.fail(CommonErrorCode.FORBIDDEN)));
            return false;
        }
        return true;
    }
}
