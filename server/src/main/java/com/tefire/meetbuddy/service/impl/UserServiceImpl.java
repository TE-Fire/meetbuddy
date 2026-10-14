package com.tefire.meetbuddy.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.tefire.meetbuddy.common.PageVO;
import com.tefire.meetbuddy.common.UserContext;
import com.tefire.meetbuddy.common.error.BizAssert;
import com.tefire.meetbuddy.common.error.CommonErrorCode;
import com.tefire.meetbuddy.entity.CreditLog;
import com.tefire.meetbuddy.entity.User;
import com.tefire.meetbuddy.entity.UserTag;
import com.tefire.meetbuddy.mapper.CreditLogMapper;
import com.tefire.meetbuddy.mapper.UserMapper;
import com.tefire.meetbuddy.mapper.UserTagMapper;
import com.tefire.meetbuddy.service.UserService;
import com.tefire.meetbuddy.util.GeoStore;
import com.tefire.meetbuddy.vo.CreditLogVO;
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
    private final CreditLogMapper creditLogMapper;
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

    @Override
    @Transactional(rollbackFor = Exception.class)
    public UserVO updateProfile(Long userId, String nickname, String bio, Integer gender) {
        User user = BizAssert.notNull(userMapper.selectById(userId), CommonErrorCode.USER_NOT_FOUND);
        if (nickname != null) {
            String n = nickname.trim();
            BizAssert.isTrue(n.length() >= 1 && n.length() <= 20, CommonErrorCode.PARAM_ERROR, "昵称长度 1~20 字");
            user.setNickname(n);
        }
        if (bio != null) {
            String b = bio.trim();
            BizAssert.isTrue(b.length() <= 100, CommonErrorCode.PARAM_ERROR, "简介最多 100 字");
            user.setBio(b);
        }
        if (gender != null) {
            BizAssert.isTrue(gender >= 0 && gender <= 2, CommonErrorCode.PARAM_ERROR, "性别取值 0/1/2");
            user.setGender(gender);
        }
        userMapper.updateById(user);
        return UserVO.from(user);
    }

    @Override
    public PageVO<CreditLogVO> creditLogs(Long userId, long page, long size) {
        BizAssert.notNull(userMapper.selectById(userId), CommonErrorCode.USER_NOT_FOUND);
        com.baomidou.mybatisplus.extension.plugins.pagination.Page<CreditLog> p =
                creditLogMapper.selectPage(new com.baomidou.mybatisplus.extension.plugins.pagination.Page<>(page, size),
                        new LambdaQueryWrapper<CreditLog>()
                                .eq(CreditLog::getUserId, userId)
                                .orderByDesc(CreditLog::getCreatedAt));
        List<CreditLogVO> list = p.getRecords().stream().map(this::toVO).toList();
        return new PageVO<>(list, p.getTotal(), page, size);
    }

    private CreditLogVO toVO(CreditLog e) {
        CreditLogVO vo = new CreditLogVO();
        vo.setId(e.getId());
        vo.setChangeValue(e.getChangeValue());
        vo.setReason(e.getReason());
        vo.setRelatedId(e.getRelatedId());
        vo.setOperatorId(e.getOperatorId());
        vo.setBalanceAfter(e.getBalanceAfter());
        vo.setCreatedAt(e.getCreatedAt());
        return vo;
    }
}
