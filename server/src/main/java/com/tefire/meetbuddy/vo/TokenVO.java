package com.tefire.meetbuddy.vo;

public record TokenVO(
        String accessToken,
        String refreshToken,
        UserVO user
) {
}
