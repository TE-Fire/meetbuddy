package com.tefire.meetbuddy.service;

import com.tefire.meetbuddy.common.PageVO;
import com.tefire.meetbuddy.vo.ChatGroupVO;
import com.tefire.meetbuddy.vo.ChatMessageVO;
import com.tefire.meetbuddy.vo.ChatSessionVO;

import java.util.List;
import java.util.Map;

/**
 * 聊天业务。投递本身（谁在线、推给谁）也放在这一层而不是 WebSocket Handler 里，
 * 因为"落库 + 投递 + 计数"是同一件事的三个动作，拆到两层会让 Handler 变厚、
 * 而且 HTTP 侧以后要加发消息接口时没地方复用。
 */
public interface ChatService {

    /** 我参与的群，带最后一条消息与未读数 */
    List<ChatGroupVO> myGroups(Long userId);

    /** 群历史，beforeId 为空取最新一页 */
    PageVO<ChatMessageVO> groupMessages(Long userId, Long groupId, Long beforeId, long size);

    /** 单聊历史 */
    PageVO<ChatMessageVO> sessionMessages(Long userId, Long peerId, Long beforeId, long size);

    /** 我的单聊会话列表：每个有过私聊的对方一项，带最后一条消息与未读数，按最近消息倒序 */
    List<ChatSessionVO> mySessions(Long userId);

    /** 未读总数 = 单聊未读 + 各群未读 */
    long unreadTotal(Long userId);

    /** 重连时补发的离线消息，按时间正序 */
    List<ChatMessageVO> offlineMessages(Long userId);

    ChatMessageVO sendToGroup(Long userId, Long groupId, String content);

    ChatMessageVO sendToUser(Long userId, Long receiverId, String content);

    /** 单聊已读回执：把这条消息标成已读，并推进会话游标 */
    void markRead(Long userId, Long msgId);

    /**
     * 系统消息：活动取消这类事件由服务端代发进群。跳过成员校验，因为发起者是系统事件
     * 而不是某个"想说话的人"；{@code operatorId} 只用来落在 sender_id 上留痕。
     * msg_type 落 SYSTEM，前端据此居中灰字展示。
     */
    void sendSystemToGroup(Long groupId, Long operatorId, String content);

    /** 到达率等计数快照 */
    Map<String, Object> stats();
}
