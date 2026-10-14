package com.tefire.meetbuddy.common;

/**
 * 当前登录用户的线程持有者。拦截器写入，业务代码读取，请求结束时必须清除——
 * Tomcat 的线程是复用的，不清除会把上一个用户的身份带给下一个请求。
 */
public final class UserContext {

    private static final ThreadLocal<Long> HOLDER = new ThreadLocal<>();

    private static final ThreadLocal<Integer> ROLE_HOLDER = new ThreadLocal<>();

    private UserContext() {
    }

    public static void setUserId(Long userId) {
        HOLDER.set(userId);
    }

    public static Long getUserId() {
        return HOLDER.get();
    }

    /** 角色：0 用户 / 1 管理员。老令牌不带 role claim 时为 null，按 0 处理。 */
    public static void setRole(Integer role) {
        ROLE_HOLDER.set(role);
    }

    public static Integer getRole() {
        return ROLE_HOLDER.get();
    }

    public static void clear() {
        HOLDER.remove();
        ROLE_HOLDER.remove();
    }
}
