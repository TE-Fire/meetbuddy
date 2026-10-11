package com.tefire.meetbuddy.common;

import com.tefire.meetbuddy.common.error.ActivityErrorCode;
import com.tefire.meetbuddy.common.error.BizException;
import com.tefire.meetbuddy.common.error.CommonErrorCode;
import jakarta.validation.ConstraintViolationException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.stream.Collectors;

/**
 * 全局异常处理——异常契约链的最后一环：IErrorCode → BizException/BizAssert
 * → Result.fail(IErrorCode) → 这里统一翻译成响应体。
 *
 * <p>分工很明确：业务异常 warn 一行、不打堆栈；只有真正没接住的异常才 error + 全栈。
 * 混在一起的话，日志里全是重复报名这种"正常失败"的堆栈，真出问题时翻不出来。
 */
@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(BizException.class)
    public Result<Void> handleBusiness(BizException e) {
        // errorCode 都是枚举，toString() 就是常量名；带上它，日志里看到的是
        // ACTIVITY_FULL 而不是光秃秃的 2001
        log.warn("[biz] code={} errorCode={} msg={}", e.getCode(), e.getErrorCode(), e.getMessage());
        return Result.fail(e.getCode(), e.getMessage());
    }

    /**
     * 参数校验失败时把具体字段拼进提示里。只返回"参数错误"的话，
     * 联调阶段前端每一次试错都要抓包才能知道错在哪个字段。
     */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public Result<Void> handleValid(MethodArgumentNotValidException e) {
        String msg = e.getBindingResult().getFieldErrors().stream()
                .map(FieldError::getField)
                .collect(Collectors.joining(", "));
        return Result.fail(CommonErrorCode.PARAM_ERROR, "参数校验失败：" + msg);
    }

    /** @Validated 校验 @RequestParam 时抛的是这个，和 body 校验的异常类型不同，必须单独接。 */
    @ExceptionHandler(ConstraintViolationException.class)
    public Result<Void> handleConstraint(ConstraintViolationException e) {
        String msg = e.getConstraintViolations().stream()
                .map(v -> v.getPropertyPath().toString())
                .collect(Collectors.joining(", "));
        return Result.fail(CommonErrorCode.PARAM_ERROR, "参数校验失败：" + msg);
    }

    /**
     * 唯一键冲突。压测时两个请求可能同时通过重复报名检查，
     * 最后靠 activity_signup 的 uk_activity_user 拦住——不接住会变成 5000 服务端异常，
     * 用户看到的是"系统错误"而不是"你已经报过名了"。
     */
    @ExceptionHandler(DuplicateKeyException.class)
    public Result<Void> handleDuplicate(DuplicateKeyException e) {
        return Result.fail(ActivityErrorCode.DUPLICATE_SIGNUP);
    }

    @ExceptionHandler(Exception.class)
    public Result<Void> handleOther(Exception e) {
        log.error("未处理异常", e);
        return Result.fail(CommonErrorCode.SYSTEM_ERROR);
    }
}
