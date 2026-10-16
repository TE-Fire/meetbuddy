package com.tefire.meetbuddy.service;

import com.tefire.meetbuddy.common.PageVO;
import com.tefire.meetbuddy.vo.UserBriefVO;

/**
 * 关注关系。规则见 docs/13-关注关系.md：
 * 不能关注自己；关注/取关均幂等；关注会给对方落一条 USER_FOLLOWED 通知。
 */
public interface FollowService {

    /** 关注；已关注则直接返回（幂等）。不能关注自己。 */
    void follow(Long userId, Long targetId);

    /** 取关；未关注也不报错（幂等）。 */
    void unfollow(Long userId, Long targetId);

    /** userId 是否关注了 targetId */
    boolean isFollowing(Long userId, Long targetId);

    /** 粉丝数（别人关注 userId 的数量） */
    long followerCount(Long userId);

    /** 关注数（userId 关注了多少人） */
    long followingCount(Long userId);

    /** 粉丝列表：谁关注了 userId */
    PageVO<UserBriefVO> followers(Long userId, long page, long size);

    /** 关注列表：userId 关注了谁 */
    PageVO<UserBriefVO> following(Long userId, long page, long size);
}
