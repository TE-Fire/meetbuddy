package com.tefire.meetbuddy.service;

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
}
