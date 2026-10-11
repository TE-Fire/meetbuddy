package com.tefire.meetbuddy.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.tefire.meetbuddy.common.ActivityStatus;
import com.tefire.meetbuddy.common.PageVO;
import com.tefire.meetbuddy.common.SignupStatus;
import com.tefire.meetbuddy.common.error.ActivityErrorCode;
import com.tefire.meetbuddy.common.error.BizAssert;
import com.tefire.meetbuddy.common.error.CommonErrorCode;
import com.tefire.meetbuddy.dto.ActivityCreateRequest;
import com.tefire.meetbuddy.entity.Activity;
import com.tefire.meetbuddy.entity.ActivityImage;
import com.tefire.meetbuddy.entity.ActivitySignup;
import com.tefire.meetbuddy.entity.ActivityTag;
import com.tefire.meetbuddy.entity.ChatGroup;
import com.tefire.meetbuddy.entity.ChatGroupMember;
import com.tefire.meetbuddy.entity.Favorite;
import com.tefire.meetbuddy.entity.User;
import com.tefire.meetbuddy.mapper.ActivityImageMapper;
import com.tefire.meetbuddy.mapper.ActivityMapper;
import com.tefire.meetbuddy.mapper.ActivitySignupMapper;
import com.tefire.meetbuddy.mapper.ActivityTagMapper;
import com.tefire.meetbuddy.mapper.ChatGroupMapper;
import com.tefire.meetbuddy.mapper.ChatGroupMemberMapper;
import com.tefire.meetbuddy.mapper.FavoriteMapper;
import com.tefire.meetbuddy.mapper.UserMapper;
import com.tefire.meetbuddy.service.ActivityService;
import com.tefire.meetbuddy.util.GeoStore;
import com.tefire.meetbuddy.vo.ActivityDetailVO;
import com.tefire.meetbuddy.vo.ActivityVO;
import com.tefire.meetbuddy.vo.CreateActivityVO;
import com.tefire.meetbuddy.vo.ParticipantVO;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class ActivityServiceImpl implements ActivityService {

    /** 低于这个分数禁止发布活动，见 docs/01 第四节 */
    private static final int MIN_CREDIT_TO_CREATE = 60;
    private static final int DEFAULT_CREDIT_REQUIRED = 60;

    private final ActivityMapper activityMapper;
    private final ActivityTagMapper activityTagMapper;
    private final ActivityImageMapper activityImageMapper;
    private final ActivitySignupMapper signupMapper;
    private final ChatGroupMapper chatGroupMapper;
    private final ChatGroupMemberMapper chatGroupMemberMapper;
    private final FavoriteMapper favoriteMapper;
    private final UserMapper userMapper;
    private final GeoStore geoStore;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public CreateActivityVO create(Long userId, ActivityCreateRequest request) {
        User user = requireUser(userId);
        if (user.getCreditScore() < MIN_CREDIT_TO_CREATE) {
            throw ActivityErrorCode.CREDIT_LOW.ex("信用分低于 " + MIN_CREDIT_TO_CREATE + "，不能发布活动");
        }
        if (!request.getEndTime().isAfter(request.getStartTime())) {
            throw CommonErrorCode.PARAM_ERROR.ex("结束时间必须晚于开始时间");
        }

        Activity activity = new Activity();
        activity.setOrganizerId(userId);
        activity.setTitle(request.getTitle());
        activity.setDescription(request.getDescription());
        activity.setCategory(request.getCategory());
        activity.setCoverUrl(request.getCoverUrl());
        activity.setLng(request.getLng());
        activity.setLat(request.getLat());
        activity.setAddress(request.getAddress());
        activity.setStartTime(request.getStartTime());
        activity.setEndTime(request.getEndTime());
        activity.setMaxParticipants(request.getMaxParticipants());
        activity.setCurrentParticipants(0);
        activity.setStatus(ActivityStatus.OPEN.name());
        activity.setCreditRequired(
                request.getCreditRequired() == null ? DEFAULT_CREDIT_REQUIRED : request.getCreditRequired());
        activityMapper.insert(activity);

        // 建群与建活动同事务：群不存在的话，报名成功却进不了群，比整个发布失败更难排查
        ChatGroup group = new ChatGroup();
        group.setActivityId(activity.getId());
        group.setName(activity.getTitle());
        group.setMemberCount(1);
        chatGroupMapper.insert(group);

        ChatGroupMember owner = new ChatGroupMember();
        owner.setGroupId(group.getId());
        owner.setUserId(userId);
        owner.setRole("OWNER");
        owner.setJoinedAt(LocalDateTime.now());
        chatGroupMemberMapper.insert(owner);

        activity.setGroupId(group.getId());
        activityMapper.updateById(activity);

        saveTags(activity.getId(), request.getTags());
        saveImages(activity.getId(), request.getImages());
        geoStore.upsert(GeoStore.ACTIVITY_KEY, activity.getId(), activity.getLng(), activity.getLat());

        CreateActivityVO vo = new CreateActivityVO();
        vo.setId(activity.getId());
        vo.setGroupId(group.getId());
        return vo;
    }

    @Override
    public PageVO<ActivityVO> list(String category, String status,
                                   BigDecimal lng, BigDecimal lat, Double radiusKm, long page, long size) {
        boolean geo = lng != null && lat != null && radiusKm != null && radiusKm > 0;
        if (geo) {
            Map<Long, Double> nearby = geoStore.nearby(GeoStore.ACTIVITY_KEY, lng, lat, radiusKm);
            if (nearby.isEmpty()) {
                return new PageVO<>(Collections.emptyList(), 0, page, size);
            }
            // GEO 已经把半径外的滤掉了，剩下的按距离由近到远分页
            List<Long> ids = new ArrayList<>(nearby.keySet());
            long from = Math.min((page - 1) * size, ids.size());
            long to = Math.min(from + size, ids.size());
            List<Long> pageIds = ids.subList((int) from, (int) to);
            if (pageIds.isEmpty()) {
                return new PageVO<>(Collections.emptyList(), ids.size(), page, size);
            }
            return toPage(activityMapper.selectPage(new Page<>(page, size),
                    buildFilter(category, status).in(Activity::getId, pageIds)), ids.size());
        }

        return toPage(activityMapper.selectPage(new Page<>(page, size), buildFilter(category, status)));
    }

    private LambdaQueryWrapper<Activity> buildFilter(String category, String status) {
        LambdaQueryWrapper<Activity> q = new LambdaQueryWrapper<>();
        if (StringUtils.hasText(category)) {
            q.eq(Activity::getCategory, category);
        }
        if (StringUtils.hasText(status)) {
            q.eq(Activity::getStatus, status);
        } else {
            // 默认不展示已结束和已取消，否则活动流会被历史数据淹没
            q.in(Activity::getStatus, ActivityStatus.OPEN.name(),
                    ActivityStatus.FULL.name(), ActivityStatus.ONGOING.name());
        }
        q.orderByDesc(Activity::getCreatedAt);
        return q;
    }

    @Override
    public ActivityDetailVO detail(Long activityId, Long currentUserId) {
        Activity activity = requireActivity(activityId);
        ActivityDetailVO vo = new ActivityDetailVO();
        fillBase(vo, activity, loadUsers(Collections.singletonList(activity.getOrganizerId())));
        vo.setDescription(activity.getDescription());
        vo.setImages(loadImages(activityId));
        vo.setGroupId(activity.getGroupId());
        vo.setParticipants(participantSummary(activityId));

        if (currentUserId != null) {
            vo.setOrganizer(activity.getOrganizerId().equals(currentUserId));
            vo.setSignedUp(hasSignup(activityId, currentUserId));
            vo.setFavorited(hasFavorite(activityId, currentUserId));
        }
        return vo;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void update(Long userId, Long activityId, ActivityCreateRequest request) {
        Activity activity = requireActivity(activityId);
        requireOrganizer(activity, userId);
        if (!ActivityStatus.OPEN.name().equals(activity.getStatus())) {
            throw CommonErrorCode.PARAM_ERROR.ex("只有报名中的活动可以编辑");
        }
        if (!request.getEndTime().isAfter(request.getStartTime())) {
            throw CommonErrorCode.PARAM_ERROR.ex("结束时间必须晚于开始时间");
        }
        if (request.getMaxParticipants() < activity.getCurrentParticipants()) {
            throw CommonErrorCode.PARAM_ERROR.ex("人数上限不能小于当前已报名人数 " + activity.getCurrentParticipants());
        }

        activity.setTitle(request.getTitle());
        activity.setDescription(request.getDescription());
        activity.setCategory(request.getCategory());
        activity.setCoverUrl(request.getCoverUrl());
        activity.setLng(request.getLng());
        activity.setLat(request.getLat());
        activity.setAddress(request.getAddress());
        activity.setStartTime(request.getStartTime());
        activity.setEndTime(request.getEndTime());
        activity.setMaxParticipants(request.getMaxParticipants());
        if (request.getCreditRequired() != null) {
            activity.setCreditRequired(request.getCreditRequired());
        }
        activityMapper.updateById(activity);

        activityTagMapper.delete(new LambdaQueryWrapper<ActivityTag>()
                .eq(ActivityTag::getActivityId, activityId));
        activityImageMapper.delete(new LambdaQueryWrapper<ActivityImage>()
                .eq(ActivityImage::getActivityId, activityId));
        saveTags(activityId, request.getTags());
        saveImages(activityId, request.getImages());
        // 地点可能被改，GEO 要跟着刷新，否则就近筛选会按旧坐标圈人
        geoStore.upsert(GeoStore.ACTIVITY_KEY, activityId, activity.getLng(), activity.getLat());
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void cancel(Long userId, Long activityId) {
        Activity activity = requireActivity(activityId);
        requireOrganizer(activity, userId);
        if (ActivityStatus.CANCELLED.name().equals(activity.getStatus())
                || ActivityStatus.FINISHED.name().equals(activity.getStatus())) {
            throw CommonErrorCode.PARAM_ERROR.ex("活动已结束或已取消");
        }
        activity.setStatus(ActivityStatus.CANCELLED.name());
        activityMapper.updateById(activity);
        // 取消的活动不该再出现在别人的就近列表里
        geoStore.remove(GeoStore.ACTIVITY_KEY, activityId);
        // 群不解散，改为只读；只读控制与离线推送在 M4 落地
    }

    @Override
    public PageVO<ActivityVO> mineOrganized(Long userId, long page, long size) {
        LambdaQueryWrapper<Activity> q = new LambdaQueryWrapper<Activity>()
                .eq(Activity::getOrganizerId, userId)
                .orderByDesc(Activity::getCreatedAt);
        return toPage(activityMapper.selectPage(new Page<>(page, size), q));
    }

    @Override
    public PageVO<ActivityVO> mineJoined(Long userId, long page, long size) {
        List<Long> activityIds = signupMapper.selectList(new LambdaQueryWrapper<ActivitySignup>()
                        .eq(ActivitySignup::getUserId, userId)
                        .in(ActivitySignup::getStatus, SignupStatus.SIGNED.name(),
                                SignupStatus.ATTENDED.name(), SignupStatus.ABSENT.name())
                        .orderByDesc(ActivitySignup::getCreatedAt))
                .stream()
                .map(ActivitySignup::getActivityId)
                .distinct()
                .toList();
        if (activityIds.isEmpty()) {
            return new PageVO<>(Collections.emptyList(), 0, page, size);
        }
        IPage<Activity> result = activityMapper.selectPage(new Page<>(page, size),
                new LambdaQueryWrapper<Activity>()
                        .in(Activity::getId, activityIds)
                        .orderByDesc(Activity::getStartTime));
        return toPage(result);
    }

    @Override
    public PageVO<ParticipantVO> participants(Long activityId, long page, long size) {
        requireActivity(activityId);
        IPage<ActivitySignup> result = signupMapper.selectPage(new Page<>(page, size),
                new LambdaQueryWrapper<ActivitySignup>()
                        .eq(ActivitySignup::getActivityId, activityId)
                        .in(ActivitySignup::getStatus, SignupStatus.SIGNED.name(),
                                SignupStatus.ATTENDED.name(), SignupStatus.ABSENT.name())
                        .orderByAsc(ActivitySignup::getCreatedAt));
        List<ParticipantVO> list = result.getRecords().stream()
                .map(s -> toParticipant(s, userMapper.selectById(s.getUserId())))
                .toList();
        return new PageVO<>(list, result.getTotal(), result.getCurrent(), result.getSize());
    }

    @Override
    public void favorite(Long userId, Long activityId) {
        requireActivity(activityId);
        if (hasFavorite(activityId, userId)) {
            return;
        }
        Favorite favorite = new Favorite();
        favorite.setUserId(userId);
        favorite.setActivityId(activityId);
        favorite.setCreatedAt(LocalDateTime.now());
        favoriteMapper.insert(favorite);
    }

    @Override
    public void unfavorite(Long userId, Long activityId) {
        favoriteMapper.delete(new LambdaQueryWrapper<Favorite>()
                .eq(Favorite::getUserId, userId)
                .eq(Favorite::getActivityId, activityId));
    }

    // ---------------- 内部方法 ----------------

    private Activity requireActivity(Long id) {
        return BizAssert.notNull(activityMapper.selectById(id), CommonErrorCode.NOT_FOUND, "活动不存在");
    }

    private User requireUser(Long id) {
        return BizAssert.notNull(userMapper.selectById(id), CommonErrorCode.USER_NOT_FOUND);
    }

    private void requireOrganizer(Activity activity, Long userId) {
        if (!activity.getOrganizerId().equals(userId)) {
            throw CommonErrorCode.FORBIDDEN.ex("只有组织者可以操作该活动");
        }
    }

    private void saveTags(Long activityId, List<String> tags) {
        if (tags == null) {
            return;
        }
        for (String tag : tags) {
            if (!StringUtils.hasText(tag)) {
                continue;
            }
            ActivityTag entity = new ActivityTag();
            entity.setActivityId(activityId);
            entity.setTagName(tag.trim());
            entity.setCreatedAt(LocalDateTime.now());
            activityTagMapper.insert(entity);
        }
    }

    private void saveImages(Long activityId, List<String> images) {
        if (images == null) {
            return;
        }
        int sort = 0;
        for (String url : images) {
            if (!StringUtils.hasText(url)) {
                continue;
            }
            ActivityImage entity = new ActivityImage();
            entity.setActivityId(activityId);
            entity.setImageUrl(url.trim());
            entity.setSort(sort++);
            entity.setCreatedAt(LocalDateTime.now());
            activityImageMapper.insert(entity);
        }
    }

    private List<String> loadTags(Long activityId) {
        return activityTagMapper.selectList(new LambdaQueryWrapper<ActivityTag>()
                        .eq(ActivityTag::getActivityId, activityId))
                .stream()
                .map(ActivityTag::getTagName)
                .toList();
    }

    private List<String> loadImages(Long activityId) {
        return activityImageMapper.selectList(new LambdaQueryWrapper<ActivityImage>()
                        .eq(ActivityImage::getActivityId, activityId)
                        .orderByAsc(ActivityImage::getSort))
                .stream()
                .map(ActivityImage::getImageUrl)
                .toList();
    }

    private Map<Long, User> loadUsers(List<Long> ids) {
        if (ids == null || ids.isEmpty()) {
            return Collections.emptyMap();
        }
        List<User> users = userMapper.selectBatchIds(ids.stream().filter(java.util.Objects::nonNull).toList());
        return users.stream().collect(Collectors.toMap(User::getId, Function.identity(), (a, b) -> a));
    }

    private List<ParticipantVO> participantSummary(Long activityId) {
        List<ActivitySignup> signups = signupMapper.selectList(new LambdaQueryWrapper<ActivitySignup>()
                .eq(ActivitySignup::getActivityId, activityId)
                .in(ActivitySignup::getStatus, SignupStatus.SIGNED.name(),
                        SignupStatus.ATTENDED.name(), SignupStatus.ABSENT.name())
                .last("limit 20"));
        Map<Long, User> users = loadUsers(signups.stream().map(ActivitySignup::getUserId).toList());
        return signups.stream().map(s -> toParticipant(s, users.get(s.getUserId()))).toList();
    }

    private ParticipantVO toParticipant(ActivitySignup signup, User user) {
        ParticipantVO vo = new ParticipantVO();
        vo.setUserId(signup.getUserId());
        if (user != null) {
            vo.setNickname(user.getNickname());
            vo.setAvatar(user.getAvatar());
            vo.setCreditScore(user.getCreditScore());
        }
        vo.setStatus(signup.getStatus());
        vo.setRemark(signup.getRemark());
        vo.setJoinedAt(signup.getCreatedAt());
        return vo;
    }

    private boolean hasSignup(Long activityId, Long userId) {
        return signupMapper.selectCount(new LambdaQueryWrapper<ActivitySignup>()
                .eq(ActivitySignup::getActivityId, activityId)
                .eq(ActivitySignup::getUserId, userId)
                .in(ActivitySignup::getStatus, SignupStatus.SIGNED.name(),
                        SignupStatus.ATTENDED.name(), SignupStatus.ABSENT.name())) > 0;
    }

    private boolean hasFavorite(Long activityId, Long userId) {
        return favoriteMapper.selectCount(new LambdaQueryWrapper<Favorite>()
                .eq(Favorite::getActivityId, activityId)
                .eq(Favorite::getUserId, userId)) > 0;
    }

    /** GEO 分支用：总数由 GEO 结果给出，分页结果里的 total 是 SQL 的，两者不一致时以 GEO 的为准。 */
    private PageVO<ActivityVO> toPage(IPage<Activity> result, long total) {
        List<ActivityVO> list = toVoList(result.getRecords());
        return new PageVO<>(list, total, result.getCurrent(), result.getSize());
    }

    private PageVO<ActivityVO> toPage(IPage<Activity> result) {
        List<ActivityVO> list = toVoList(result.getRecords());
        return new PageVO<>(list, result.getTotal(), result.getCurrent(), result.getSize());
    }

    private List<ActivityVO> toVoList(List<Activity> records) {
        Map<Long, User> users = loadUsers(records.stream().map(Activity::getOrganizerId).toList());
        List<ActivityVO> list = new ArrayList<>(records.size());
        for (Activity a : records) {
            ActivityVO vo = new ActivityVO();
            fillBase(vo, a, users);
            list.add(vo);
        }
        return list;
    }

    private void fillBase(ActivityVO vo, Activity a, Map<Long, User> users) {
        vo.setId(a.getId());
        vo.setTitle(a.getTitle());
        vo.setCategory(a.getCategory());
        vo.setCoverUrl(a.getCoverUrl());
        vo.setLng(a.getLng());
        vo.setLat(a.getLat());
        vo.setAddress(a.getAddress());
        vo.setStartTime(a.getStartTime());
        vo.setEndTime(a.getEndTime());
        vo.setMaxParticipants(a.getMaxParticipants());
        vo.setCurrentParticipants(a.getCurrentParticipants());
        vo.setStatus(a.getStatus());
        vo.setCreditRequired(a.getCreditRequired());
        vo.setTags(loadTags(a.getId()));
        vo.setOrganizerId(a.getOrganizerId());
        User organizer = users.get(a.getOrganizerId());
        if (organizer != null) {
            vo.setOrganizerNickname(organizer.getNickname());
            vo.setOrganizerAvatar(organizer.getAvatar());
        }
    }
}
