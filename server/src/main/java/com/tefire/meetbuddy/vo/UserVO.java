package com.tefire.meetbuddy.vo;

import com.tefire.meetbuddy.entity.User;

/**
 * 对外暴露的用户视图。刻意用 VO 而不是直接返回实体：
 * 一旦把实体序列化出去，passwordHash 就会跟着进 JSON，改动实体字段等于改动对外接口。
 */
public record UserVO(
        Long id,
        String phone,
        String nickname,
        String avatar,
        Integer gender,
        String bio,
        Integer creditScore
) {
    public static UserVO from(User user) {
        if (user == null) {
            return null;
        }
        return new UserVO(
                user.getId(),
                user.getPhone(),
                user.getNickname(),
                user.getAvatar(),
                user.getGender(),
                user.getBio(),
                user.getCreditScore()
        );
    }
}
