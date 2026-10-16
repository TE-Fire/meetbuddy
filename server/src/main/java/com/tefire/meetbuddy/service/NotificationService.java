package com.tefire.meetbuddy.service;

import com.tefire.meetbuddy.common.PageVO;
import com.tefire.meetbuddy.vo.NotificationVO;

import java.util.Collection;

/**
 * 站内通知。规则见 docs/05-通知与提醒.md。
 * 触达 = 落库 +（接收方在线时）经 WebSocket 推一帧 notify。
 */
public interface NotificationService {

    /** 落一条通知；接收方在线则经 WS 实时推一帧 notify */
    void notifyUser(Long userId, String type, String title, String content, Long bizId);

    /** 批量（活动取消 / 提醒通知一群参与者用） */
    void notifyUsers(Collection<Long> userIds, String type, String title, String content, Long bizId);

    /** 我的通知分页，按时间倒序 */
    PageVO<NotificationVO> list(Long userId, long page, long size);

    long unread(Long userId);

    void markRead(Long userId, Long id);

    /** 全部已读，返回本次标记的条数 */
    long markAllRead(Long userId);
}
