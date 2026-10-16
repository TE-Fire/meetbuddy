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
import java.util.HashSet;
import java.util.List;
import java.util.Set;

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
        return new UserVO(
                user.getId(),
                user.getPhone(),
                user.getNickname(),
                user.getAvatar(),
                user.getGender(),
                user.getBio(),
                user.getCreditScore(),
                user.getRole(),
                listTags(userId));
    }

    /** 取用户兴趣标签（已按 user_tag 主键升序，对应插入顺序） */
    private List<String> listTags(Long userId) {
        return userTagMapper
                .selectList(new LambdaQueryWrapper<UserTag>().eq(UserTag::getUserId, userId).orderByAsc(UserTag::getId))
                .stream()
                .map(UserTag::getTagName)
                .toList();
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
        // 覆盖式更新：输入里可能带重复标签，user_tag 有 (user_id, tag_name) 唯一索引，
        // 不去重会触发 DuplicateKeyException（被全局处理器误报成"已报名过该活动"）。
        // 这里先去重再插，保证幂等且语义正确；顺序按首次出现保留。
        Set<String> seen = new HashSet<>();
        int count = 0;
        for (String tag : tags) {
            if (tag == null) {
                continue;
            }
            String t = tag.trim();
            if (t.isBlank() || seen.contains(t) || count >= MAX_TAGS) {
                continue;
            }
            seen.add(t);
            UserTag entity = new UserTag();
            entity.setUserId(userId);
            entity.setTagName(t);
            entity.setCreatedAt(LocalDateTime.now());
            userTagMapper.insert(entity);
            count++;
        }
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public UserVO updateProfile(Long userId, String nickname, String bio, Integer gender, String avatar) {
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
        // 头像：上传接口按请求 Host 返回绝对地址（如 http://127.0.0.1:8099/uploads/x.jpg），
        // 统一归一化成相对路径落库，所有设备刷新时由前端 imgUrl 拼自己的 apiBase 自愈。
        // 校验只看 path 段：必须以 /uploads/ 或 /images/ 开头，外链（http://evil.com/a.png）一律拒。
        if (avatar != null) {
            String a = avatar.trim();
            BizAssert.isTrue(!a.isEmpty() && a.length() <= 255, CommonErrorCode.PARAM_ERROR, "头像地址不合法");
            int idx = a.indexOf("/uploads/");
            if (idx < 0) idx = a.indexOf("/images/");
            BizAssert.isTrue(idx >= 0, CommonErrorCode.PARAM_ERROR, "头像地址无效");
            String path = a.substring(idx);
            BizAssert.isTrue(path.startsWith("/uploads/") || path.startsWith("/images/"),
                    CommonErrorCode.PARAM_ERROR, "头像地址无效");
            user.setAvatar(path);
        }
        userMapper.updateById(user);
        return new UserVO(
                user.getId(),
                user.getPhone(),
                user.getNickname(),
                user.getAvatar(),
                user.getGender(),
                user.getBio(),
                user.getCreditScore(),
                user.getRole(),
                listTags(userId));
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
