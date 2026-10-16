package com.tefire.meetbuddy.service;

import com.tefire.meetbuddy.vo.UserProfileVO;

/**
 * 他人个人主页。规则见 docs/06-成就勋章与个人主页.md 第四节。
 */
public interface UserProfileService {

    /**
     * @param targetUserId  被看的人
     * @param currentUserId 当前登录用户（可空），用于回填"我是否已关注 TA"；null 或看自己时为 false
     * @return 公开资料 + 已解锁徽章 + 完成次数 + 最近活动 + 关注数；人不存在抛 1003
     */
    UserProfileVO getProfile(Long targetUserId, Long currentUserId);
}
