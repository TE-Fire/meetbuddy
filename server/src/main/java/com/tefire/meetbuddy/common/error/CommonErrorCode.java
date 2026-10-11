package com.tefire.meetbuddy.common.error;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 通用错误码：通用 / 用户 / 认证段（1xxx）+ 系统段（50xx）。
 *
 * <p><b>段位登记（本项目全平台在这张表里占段，新模块先占段再扩枚举）：</b>
 * <pre>
 *   0     成功
 *   1xxx  通用 / 用户 / 认证        本枚举
 *   401 / 403  未登录 / 无权限      本枚举（保留 HTTP 语义，见下）
 *   2xxx  活动与报名                 ActivityErrorCode
 *   21xx  搭子与匹配                 （预留）
 *   3xxx  通知 / 短信                SmsErrorCode
 *   31xx  聊天                       （预留）
 *   4xxx  管理端                     （预留，M6）
 *   5000  系统                      本枚举
 * </pre>
 *
 * <p><b>为什么不把用户/认证段挪到 4xxx 单独立枚举：</b>1xxx 段的编号在 M1 就已经定稿，
 * 13 条验收用例和 {@code docs/03} 的错误码表都锁在 1001~1006 上，重编号会让验收记录、
 * 前端约定、脚本断言同时失效，换来的只是枚举分得更细一点，不划算。搭子和聊天这两段
 * 现在还是空的，等真有错误码时再立枚举。
 *
 * <p><b>401 / 403 为什么不像校园市场那样并入 1001/1002：</b>那边是 Sa-Token 的框架
 * 异常映射出来的，必须统一走业务码；这里认证是自己写的拦截器，401 是「拿 HTTP 语义
 * 直接说事」——前端 axios 拦截器见 401 就跳登录页，不必再解析 body。
 */
@Getter
@AllArgsConstructor
public enum CommonErrorCode implements IErrorCode {

    OK(0, "ok"),

    /* ── 401 / 403：传输层语义直接表达鉴权结果 ───────────── */
    UNAUTHORIZED(401, "未登录或令牌已过期"),
    FORBIDDEN(403, "无权限"),

    /* ── 通用 / 用户 / 认证 1xxx ───────────────────────── */
    PARAM_ERROR(1001, "参数校验失败"),
    USER_BANNED(1002, "账号已被封禁"),
    USER_NOT_FOUND(1003, "用户不存在"),
    NOT_FOUND(1004, "资源不存在"),
    USER_EXISTS(1005, "该手机号已注册"),
    LOGIN_FAIL(1006, "手机号或密码错误"),

    /* ── 系统 50xx ────────────────────────────────────── */
    SYSTEM_ERROR(5000, "服务端异常"),
    ;

    private final int code;
    private final String message;

    @Override
    public int getCode() {
        return code;
    }

    @Override
    public String getMessage() {
        return message;
    }
}
