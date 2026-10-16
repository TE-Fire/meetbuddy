package com.tefire.meetbuddy.vo;

import com.tefire.meetbuddy.entity.User;
import lombok.Data;

/**
 * 用户精简视图，用于关注/粉丝列表。只暴露参与者列表早已公开的字段，
 * 手机号等隐私字段刻意不返回；banned 交给前端置灰，原因同 UserProfileVO。
 */
@Data
public class UserBriefVO {

    private Long userId;

    private String nickname;

    private String avatar;

    private Integer creditScore;

    private boolean banned;

    public static UserBriefVO from(User u) {
        if (u == null) {
            return null;
        }
        UserBriefVO vo = new UserBriefVO();
        vo.setUserId(u.getId());
        vo.setNickname(u.getNickname());
        vo.setAvatar(u.getAvatar());
        vo.setCreditScore(u.getCreditScore());
        vo.setBanned(u.getStatus() != null && u.getStatus() == 1);
        return vo;
    }
}
