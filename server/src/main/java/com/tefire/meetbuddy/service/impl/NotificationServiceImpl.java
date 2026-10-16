package com.tefire.meetbuddy.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.tefire.meetbuddy.common.PageVO;
import com.tefire.meetbuddy.common.error.BizAssert;
import com.tefire.meetbuddy.common.error.NotificationErrorCode;
import com.tefire.meetbuddy.entity.Notification;
import com.tefire.meetbuddy.mapper.NotificationMapper;
import com.tefire.meetbuddy.service.NotificationService;
import com.tefire.meetbuddy.vo.NotificationVO;
import com.tefire.meetbuddy.ws.ChatSessionRegistry;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.Map;

/**
 * 通知落库 + 在线实时推送。逐条 insert 而不是批量：
 * 每条都要单独判断"这个人在不在线、要不要推帧"，批量 insert 拿不到各自的自增 id。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class NotificationServiceImpl implements NotificationService {

    private final NotificationMapper notificationMapper;
    private final ChatSessionRegistry registry;
    private final ObjectMapper objectMapper;

    @Override
    public void notifyUser(Long userId, String type, String title, String content, Long bizId) {
        notifyUsers(List.of(userId), type, title, content, bizId);
    }

    @Override
    public void notifyUsers(Collection<Long> userIds, String type, String title, String content, Long bizId) {
        if (userIds == null || userIds.isEmpty()) {
            return;
        }
        LocalDateTime now = LocalDateTime.now();
        for (Long uid : userIds) {
            if (uid == null) {
                continue;
            }
            Notification n = new Notification();
            n.setUserId(uid);
            n.setType(type);
            n.setTitle(title);
            n.setContent(content);
            n.setBizId(bizId);
            n.setReadStatus(0);
            n.setCreatedAt(now);
            notificationMapper.insert(n);
            // 在线才推；离线只落库，靠未读红点 + 下次进通知页补看（见 docs/05 第五节）
            int delivered = registry.sendToUser(uid, toJson(Map.of("type", "notify", "notification", toVO(n))));
            if (delivered == 0) {
                log.debug("[notify] 用户 {} 不在线，通知仅落库 id={}", uid, n.getId());
            }
        }
    }

    @Override
    public PageVO<NotificationVO> list(Long userId, long page, long size) {
        Page<Notification> p = notificationMapper.selectPage(new Page<>(page, size),
                new LambdaQueryWrapper<Notification>()
                        .eq(Notification::getUserId, userId)
                        .orderByDesc(Notification::getCreatedAt)
                        .orderByDesc(Notification::getId));
        List<NotificationVO> list = p.getRecords().stream().map(this::toVO).toList();
        return new PageVO<>(list, p.getTotal(), page, size);
    }

    @Override
    public long unread(Long userId) {
        return notificationMapper.selectCount(new LambdaQueryWrapper<Notification>()
                .eq(Notification::getUserId, userId)
                .eq(Notification::getReadStatus, 0));
    }

    @Override
    public void markRead(Long userId, Long id) {
        Notification n = BizAssert.notNull(notificationMapper.selectById(id),
                NotificationErrorCode.NOTIFICATION_NOT_FOUND);
        BizAssert.isTrue(n.getUserId().equals(userId),
                NotificationErrorCode.NOTIFICATION_NOT_FOUND, "无权操作他人的通知");
        if (n.getReadStatus() != null && n.getReadStatus() == 1) {
            return;
        }
        notificationMapper.update(null, new LambdaUpdateWrapper<Notification>()
                .set(Notification::getReadStatus, 1)
                .eq(Notification::getId, id)
                .eq(Notification::getUserId, userId));
    }

    @Override
    public long markAllRead(Long userId) {
        // 只动"当前未读"的行，返回受影响条数
        return notificationMapper.update(null, new LambdaUpdateWrapper<Notification>()
                .set(Notification::getReadStatus, 1)
                .eq(Notification::getUserId, userId)
                .eq(Notification::getReadStatus, 0));
    }

    private NotificationVO toVO(Notification n) {
        NotificationVO vo = new NotificationVO();
        vo.setId(n.getId());
        vo.setType(n.getType());
        vo.setTitle(n.getTitle());
        vo.setContent(n.getContent());
        vo.setBizId(n.getBizId());
        vo.setReadStatus(n.getReadStatus());
        vo.setCreatedAt(n.getCreatedAt());
        return vo;
    }

    private String toJson(Object payload) {
        try {
            return objectMapper.writeValueAsString(payload);
        } catch (JsonProcessingException ex) {
            log.error("[notify] 序列化失败", ex);
            return "{\"type\":\"error\",\"code\":5000,\"message\":\"序列化失败\"}";
        }
    }
}
