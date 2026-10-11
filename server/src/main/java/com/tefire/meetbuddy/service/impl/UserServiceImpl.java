package com.tefire.meetbuddy.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.tefire.meetbuddy.common.UserContext;
import com.tefire.meetbuddy.common.error.BizAssert;
import com.tefire.meetbuddy.common.error.CommonErrorCode;
import com.tefire.meetbuddy.entity.User;
import com.tefire.meetbuddy.entity.UserTag;
import com.tefire.meetbuddy.mapper.UserMapper;
import com.tefire.meetbuddy.mapper.UserTagMapper;
import com.tefire.meetbuddy.service.UserService;
import com.tefire.meetbuddy.util.GeoStore;
import com.tefire.meetbuddy.vo.UserVO;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class UserServiceImpl implements UserService {

    private static final int MAX_TAGS = 20;

    private final UserMapper userMapper;
    private final UserTagMapper userTagMapper;
    private final GeoStore geoStore;

    @Override
    public UserVO getCurrentProfile() {
        Long userId = BizAssert.notNull(UserContext.getUserId(), CommonErrorCode.UNAUTHORIZED);
        User user = BizAssert.notNull(userMapper.selectById(userId), CommonErrorCode.USER_NOT_FOUND);
        return UserVO.from(user);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void updateLocation(Long userId, BigDecimal lng, BigDecimal lat) {
        User user = BizAssert.notNull(userMapper.selectById(userId), CommonErrorCode.USER_NOT_FOUND);
        user.setLastLng(lng);
        user.setLastLat(lat);
        user.setLastActiveAt(LocalDateTime.now());
        userMapper.updateById(user);
        geoStore.upsert(GeoStore.USER_KEY, userId, lng, lat);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void updateTags(Long userId, List<String> tags) {
        BizAssert.notNull(userMapper.selectById(userId), CommonErrorCode.USER_NOT_FOUND);
        userTagMapper.delete(new LambdaQueryWrapper<UserTag>().eq(UserTag::getUserId, userId));
        if (tags == null) {
            return;
        }
        int count = 0;
        for (String tag : tags) {
            if (tag == null || tag.isBlank() || count >= MAX_TAGS) {
                continue;
            }
            UserTag entity = new UserTag();
            entity.setUserId(userId);
            entity.setTagName(tag.trim());
            entity.setCreatedAt(LocalDateTime.now());
            userTagMapper.insert(entity);
            count++;
        }
    }
}
