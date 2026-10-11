package com.tefire.meetbuddy.common.error;

/**
 * 错误码契约：整个后端的「错误描述」只认这个接口，不认任何具体枚举。
 *
 * <p>各段错误码枚举（CommonErrorCode / ActivityErrorCode / SmsErrorCode …）实现它，
 * 于是在 BizException、Result.fail、BizAssert 三处天然可用；以后新增一段错误码时，
 * 只要新写一个枚举实现本接口即可，已有代码零改动。
 *
 * <p>这一层是照着校园市场后端（campus-market/backend）的同一套约定搬过来的，
 * 两个项目读起来一致。唯一刻意的差异：那边方法名是 {@code getMsg()}，这边保留
 * {@code getMessage()}——meetbuddy 的响应信封字段本就叫 {@code message}（见 docs/03），
 * 枚举方法与信封字段同名，排查时不用在脑子里做一次映射。
 */
public interface IErrorCode {

    int getCode();

    String getMessage();

    /** 快捷抛出：{@code throw ActivityErrorCode.ACTIVITY_FULL.ex();} */
    default BizException ex() {
        return new BizException(this);
    }

    /** 快捷抛出并补充细节：{@code throw CommonErrorCode.NOT_FOUND.ex("活动 " + id + " 不存在");} */
    default BizException ex(String detail) {
        return new BizException(this, detail);
    }
}
