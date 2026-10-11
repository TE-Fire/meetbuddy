package com.tefire.meetbuddy.common.error;

import lombok.Getter;

/**
 * 业务异常：可预期的失败（活动已满、重复报名、无权限等）。
 *
 * <p>与系统异常的区别有两点：它不打堆栈（这些是业务上的正常分支，不是缺陷，
 * 打堆栈只会让日志失真）；它的 code/msg 是直接给用户看的，而不是"系统繁忙"。
 *
 * <p>入参只认 {@link IErrorCode} 契约，不允许再传裸的 int code——裸 int 一旦扩散，
 * 「这个 2003 是什么意思」就要回到源码里翻，枚举名本身就是文档。
 */
@Getter
public class BizException extends RuntimeException {

    private final int code;

    /** 抛出时用的错误码枚举，日志与排查时可还原枚举名 */
    private final IErrorCode errorCode;

    public BizException(IErrorCode errorCode) {
        super(errorCode.getMessage());
        this.code = errorCode.getCode();
        this.errorCode = errorCode;
    }

    /** 覆盖提示文案、保留错误码，用于拼具体的上下文（如"活动 12 已满"） */
    public BizException(IErrorCode errorCode, String detail) {
        super(detail);
        this.code = errorCode.getCode();
        this.errorCode = errorCode;
    }

    public static BizException of(IErrorCode errorCode) {
        return new BizException(errorCode);
    }
}
