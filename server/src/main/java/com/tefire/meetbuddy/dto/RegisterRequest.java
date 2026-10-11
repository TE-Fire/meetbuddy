package com.tefire.meetbuddy.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record RegisterRequest(
        @NotBlank @Pattern(regexp = "^1[3-9]\\d{9}$", message = "手机号格式不正确") String phone,
        @NotBlank @Size(min = 6, max = 32, message = "密码长度需为 6-32 位") String password,
        @NotBlank @Size(max = 32, message = "昵称不能超过 32 个字符") String nickname,
        @NotBlank String smsCode
) {
}
