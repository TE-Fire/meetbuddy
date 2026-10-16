package com.tefire.meetbuddy.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;

/**
 * 个人资料编辑。三项均可选，传 null 表示不改；
 * service 层对 trim 后的长度做最终校验（空串、超长在此拒绝）。
 */
public record ProfileUpdateRequest(
        @Size(max = 20, message = "昵称最长 20") String nickname,
        @Size(max = 100, message = "简介最长 100") String bio,
        @Min(value = 0, message = "性别取值 0/1/2") @Max(value = 2, message = "性别取值 0/1/2") Integer gender,
        @Size(max = 255, message = "头像地址过长") String avatar
) {
}
