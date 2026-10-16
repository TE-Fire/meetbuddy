package com.tefire.meetbuddy.service;

import com.tefire.meetbuddy.common.PageVO;
import com.tefire.meetbuddy.vo.CreditLogVO;
import com.tefire.meetbuddy.vo.UserVO;

import java.math.BigDecimal;
import java.util.List;

public interface UserService {

    /** 取当前登录用户的资料，userId 从 UserContext 取，不接受外部传入 */
    UserVO getCurrentProfile();

    /** 上报坐标，同时刷新 Redis GEO 与最近活跃时间 */
    void updateLocation(Long userId, BigDecimal lng, BigDecimal lat);

    /** 覆盖式更新兴趣标签 */
    void updateTags(Long userId, List<String> tags);

    /**
     * 编辑个人资料（昵称/简介/性别/头像，均可选，null 不改）。
     *
     * @return 更新后的用户视图，前端直接刷新本地缓存
     */
    UserVO updateProfile(Long userId, String nickname, String bio, Integer gender, String avatar);

    /** 我的信用分明细，按时间倒序，只查自己的 */
    PageVO<CreditLogVO> creditLogs(Long userId, long page, long size);
}
