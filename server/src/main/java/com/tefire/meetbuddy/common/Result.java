package com.tefire.meetbuddy.common;

import com.tefire.meetbuddy.common.error.CommonErrorCode;
import com.tefire.meetbuddy.common.error.IErrorCode;
import lombok.Data;

import java.io.Serializable;

/**
 * 全站统一响应信封。HTTP 状态码只表达传输层语义，业务成败一律看 code，
 * 这样前端只需要处理一处分支，不必在 HTTP 4xx 和 body 之间来回判断。
 *
 * <p>失败入参只吃 {@link IErrorCode} 契约（见 docs/03 第五节），与
 * BizException / BizAssert 同源——同一个错误码在抛出处和响应处长得一样，
 * 翻日志时不用在 int 和枚举名之间来回对。
 */
@Data
public class Result<T> implements Serializable {

    private int code;
    private String message;
    private T data;

    public static <T> Result<T> ok() {
        return ok(null);
    }

    public static <T> Result<T> ok(T data) {
        Result<T> r = new Result<>();
        r.setCode(CommonErrorCode.OK.getCode());
        r.setMessage(CommonErrorCode.OK.getMessage());
        r.setData(data);
        return r;
    }

    /** 直接用错误码契约 */
    public static <T> Result<T> fail(IErrorCode code) {
        return fail(code.getCode(), code.getMessage());
    }

    /** 覆盖提示文案、保留错误码，如 1001 + "参数校验失败：radius" */
    public static <T> Result<T> fail(IErrorCode code, String message) {
        return fail(code.getCode(), message);
    }

    /** 裸 int 入口，只给拿不到错误码枚举的场合（如框架抛出来的异常）用 */
    public static <T> Result<T> fail(int code, String message) {
        Result<T> r = new Result<>();
        r.setCode(code);
        r.setMessage(message);
        return r;
    }
}
