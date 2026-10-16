package com.tefire.meetbuddy.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.tefire.meetbuddy.common.PageVO;
import com.tefire.meetbuddy.common.error.BizAssert;
import com.tefire.meetbuddy.common.error.CommonErrorCode;
import com.tefire.meetbuddy.entity.User;
import com.tefire.meetbuddy.entity.UserFollow;
import com.tefire.meetbuddy.mapper.UserFollowMapper;
import com.tefire.meetbuddy.mapper.UserMapper;
import com.tefire.meetbuddy.service.FollowService;
import com.tefire.meetbuddy.service.NotificationService;
import com.tefire.meetbuddy.vo.UserBriefVO;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * 关注关系实现。关注与取关都做成幂等，前端反复点也不会把关系搞乱；
 * 唯一索引是并发下的最后一道防线（撞键直接当已关注处理，不抛给用户）。
 */
@Service
@RequiredArgsConstructor
public class FollowServiceImpl implements FollowService {

    /** 通知类型：有人关注了你，点击跳对方主页（见 docs/05、docs/13） */
    private static final String TYPE_FOLLOWED = "USER_FOLLOWED";

    private final UserFollowMapper followMapper;
    private final UserMapper userMapper;
    private final NotificationService notificationService;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void follow(Long userId, Long targetId) {
        BizAssert.notNull(userId, CommonErrorCode.UNAUTHORIZED);
        if (userId.equals(targetId)) {
            throw CommonErrorCode.PARAM_ERROR.ex("不能关注自己");
        }
        BizAssert.notNull(userMapper.selectById(targetId), CommonErrorCode.USER_NOT_FOUND, "用户不存在");
        if (isFollowing(userId, targetId)) {
            return;
        }
        UserFollow follow = new UserFollow();
        follow.setFollowerId(userId);
        follow.setFolloweeId(targetId);
        follow.setCreatedAt(LocalDateTime.now());
        try {
            followMapper.insert(follow);
        } catch (DuplicateKeyException e) {
            // 并发重复关注：唯一索引挡下，当作已关注，不再重复发通知
            return;
        }
        User me = userMapper.selectById(userId);
        String name = me == null || me.getNickname() == null ? "有人" : me.getNickname();
        // bizId 存关注者 id，前端点通知跳到"关注你的人"的主页
        notificationService.notifyUser(targetId, TYPE_FOLLOWED, "新的关注", name + " 关注了你", userId);
    }

    @Override
    public void unfollow(Long userId, Long targetId) {
        BizAssert.notNull(userId, CommonErrorCode.UNAUTHORIZED);
        followMapper.delete(new LambdaQueryWrapper<UserFollow>()
                .eq(UserFollow::getFollowerId, userId)
                .eq(UserFollow::getFolloweeId, targetId));
    }

    @Override
    public boolean isFollowing(Long userId, Long targetId) {
        if (userId == null || targetId == null) {
            return false;
        }
        return followMapper.selectCount(new LambdaQueryWrapper<UserFollow>()
                .eq(UserFollow::getFollowerId, userId)
                .eq(UserFollow::getFolloweeId, targetId)) > 0;
    }

    @Override
    public long followerCount(Long userId) {
        return followMapper.selectCount(new LambdaQueryWrapper<UserFollow>()
                .eq(UserFollow::getFolloweeId, userId));
    }

    @Override
    public long followingCount(Long userId) {
        return followMapper.selectCount(new LambdaQueryWrapper<UserFollow>()
                .eq(UserFollow::getFollowerId, userId));
    }

    @Override
    public PageVO<UserBriefVO> followers(Long userId, long page, long size) {
        BizAssert.notNull(userMapper.selectById(userId), CommonErrorCode.USER_NOT_FOUND, "用户不存在");
        IPage<UserFollow> result = followMapper.selectPage(new Page<>(page, size),
                new LambdaQueryWrapper<UserFollow>()
                        .eq(UserFollow::getFolloweeId, userId)
                        .orderByDesc(UserFollow::getCreatedAt));
        return toBriefPage(result, UserFollow::getFollowerId);
    }

    @Override
    public PageVO<UserBriefVO> following(Long userId, long page, long size) {
        BizAssert.notNull(userMapper.selectById(userId), CommonErrorCode.USER_NOT_FOUND, "用户不存在");
        IPage<UserFollow> result = followMapper.selectPage(new Page<>(page, size),
                new LambdaQueryWrapper<UserFollow>()
                        .eq(UserFollow::getFollowerId, userId)
                        .orderByDesc(UserFollow::getCreatedAt));
        return toBriefPage(result, UserFollow::getFolloweeId);
    }

    /** 把关注记录页转成"对端用户"精简视图页，一次批量查用户避免 N+1。 */
    private PageVO<UserBriefVO> toBriefPage(IPage<UserFollow> result, Function<UserFollow, Long> idGetter) {
        List<Long> ids = result.getRecords().stream().map(idGetter).filter(java.util.Objects::nonNull).toList();
        Map<Long, User> users = ids.isEmpty() ? Map.of()
                : userMapper.selectBatchIds(ids).stream()
                        .collect(Collectors.toMap(User::getId, Function.identity(), (a, b) -> a));
        List<UserBriefVO> list = new ArrayList<>();
        for (UserFollow f : result.getRecords()) {
            UserBriefVO vo = UserBriefVO.from(users.get(idGetter.apply(f)));
            if (vo != null) {
                list.add(vo);
            }
        }
        return new PageVO<>(list, result.getTotal(), result.getCurrent(), result.getSize());
    }
}
