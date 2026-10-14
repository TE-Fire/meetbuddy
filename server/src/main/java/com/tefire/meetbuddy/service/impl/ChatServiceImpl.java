package com.tefire.meetbuddy.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.tefire.meetbuddy.common.ActivityStatus;
import com.tefire.meetbuddy.common.PageVO;
import com.tefire.meetbuddy.common.error.BizAssert;
import com.tefire.meetbuddy.common.error.ChatErrorCode;
import com.tefire.meetbuddy.common.error.CommonErrorCode;
import com.tefire.meetbuddy.entity.Activity;
import com.tefire.meetbuddy.entity.ChatGroup;
import com.tefire.meetbuddy.entity.ChatGroupMember;
import com.tefire.meetbuddy.entity.Message;
import com.tefire.meetbuddy.entity.User;
import com.tefire.meetbuddy.mapper.ActivityMapper;
import com.tefire.meetbuddy.mapper.ChatGroupMapper;
import com.tefire.meetbuddy.mapper.ChatGroupMemberMapper;
import com.tefire.meetbuddy.mapper.MessageMapper;
import com.tefire.meetbuddy.mapper.UserMapper;
import com.tefire.meetbuddy.service.ChatService;
import com.tefire.meetbuddy.vo.ChatGroupVO;
import com.tefire.meetbuddy.vo.ChatMessageVO;
import com.tefire.meetbuddy.vo.ChatSessionVO;
import com.tefire.meetbuddy.ws.ChatMetrics;
import com.tefire.meetbuddy.ws.ChatSessionRegistry;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * 聊天业务：落库、投递、计到一块做完。
 *
 * <p><b>未读与离线补发的口径。</b>单聊用 {@code message.read_status} 就够了——一条消息
 * 只有一个接收人。群聊不行：一条群消息多人可见，一位 tinyint 表达不了"谁读到哪"，
 * 所以群聊另走 Redis 游标 {@code chat:read:{userId}:g{groupId}} 记"我最后读到哪条"，
 * 未读 = 该群 id 大于游标、且不是我自己发的消息数。游标没有时（刚入群）退回用
 * {@code chat_group_member.joined_at} 兜底，免得新人一进群被历史消息刷一脸未读。
 *
 * <p>这是 docs/02 "已读回执不逐条记录每人读到哪" 那句话的落地方式：游标是一条 Redis 记录，
 * 不是每人每消息一行，消息表因此不会膨胀出一个数量级。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ChatServiceImpl implements ChatService {

    /** 群聊已读游标：chat:read:{userId}:g{groupId} -> 最后已读的 msgId */
    private static final String GROUP_CURSOR_PREFIX = "chat:read:";
    private static final Duration CURSOR_TTL = Duration.ofDays(30);

    private static final int OFFLINE_LIMIT = 200;
    private static final int OFFLINE_PER_GROUP_LIMIT = 50;
    private static final long DEFAULT_PAGE_SIZE = 20;
    private static final long MAX_PAGE_SIZE = 100;

    /** MySQL 的 datetime 下限是 1000-01-01，别拿 LocalDateTime.MIN 去比 */
    private static final LocalDateTime EPOCH = LocalDateTime.of(1970, 1, 1, 0, 0);

    private final MessageMapper messageMapper;
    private final ChatGroupMapper chatGroupMapper;
    private final ChatGroupMemberMapper chatGroupMemberMapper;
    private final ActivityMapper activityMapper;
    private final UserMapper userMapper;
    private final StringRedisTemplate redisTemplate;
    private final ChatSessionRegistry registry;
    private final ChatMetrics metrics;
    private final ObjectMapper objectMapper;

    // ── 查询 ────────────────────────────────────────────────────

    @Override
    public List<ChatGroupVO> myGroups(Long userId) {
        List<Long> groupIds = myGroupIds(userId);
        if (groupIds.isEmpty()) {
            return Collections.emptyList();
        }
        Map<Long, String> roleByGroup = chatGroupMemberMapper
                .selectList(new LambdaQueryWrapper<ChatGroupMember>().eq(ChatGroupMember::getUserId, userId))
                .stream()
                .collect(Collectors.toMap(ChatGroupMember::getGroupId, ChatGroupMember::getRole, (a, b) -> a));

        List<ChatGroupVO> result = new ArrayList<>();
        for (ChatGroup group : chatGroupMapper.selectBatchIds(groupIds)) {
            ChatGroupVO vo = new ChatGroupVO();
            vo.setId(group.getId());
            vo.setActivityId(group.getActivityId());
            vo.setName(group.getName());
            vo.setMemberCount(group.getMemberCount());
            vo.setRole(roleByGroup.get(group.getId()));
            Message last = messageMapper.selectOne(new LambdaQueryWrapper<Message>()
                    .eq(Message::getGroupId, group.getId())
                    .orderByDesc(Message::getId)
                    .last("LIMIT 1"));
            if (last != null) {
                vo.setLastMessage(last.getContent());
                vo.setLastMessageAt(last.getCreatedAt());
            }
            vo.setUnread(countGroupUnread(userId, group.getId()));
            result.add(vo);
        }
        // 有消息的群排在前面，没消息的沉底
        result.sort(Comparator.comparing(ChatGroupVO::getLastMessageAt,
                Comparator.nullsLast(Comparator.<LocalDateTime>reverseOrder())));
        return result;
    }

    @Override
    public PageVO<ChatMessageVO> groupMessages(Long userId, Long groupId, Long beforeId, long size) {
        assertMember(userId, groupId);
        long limit = normalizeSize(size);

        LambdaQueryWrapper<Message> q = new LambdaQueryWrapper<Message>()
                .eq(Message::getGroupId, groupId)
                .orderByDesc(Message::getId)
                .last("LIMIT " + limit);
        if (beforeId != null) {
            q.lt(Message::getId, beforeId);
        }
        List<Message> rows = messageMapper.selectList(q);
        long total = messageMapper.selectCount(
                new LambdaQueryWrapper<Message>().eq(Message::getGroupId, groupId));
        // 倒序取"最近一页"，返回前翻回正序，前端可以直接顺序渲染
        Collections.reverse(rows);
        return new PageVO<>(toVOs(rows), total, 1, limit);
    }

    @Override
    public PageVO<ChatMessageVO> sessionMessages(Long userId, Long peerId, Long beforeId, long size) {
        long limit = normalizeSize(size);
        LambdaQueryWrapper<Message> q = new LambdaQueryWrapper<>();
        applySessionFilter(q, userId, peerId);
        q.orderByDesc(Message::getId).last("LIMIT " + limit);
        if (beforeId != null) {
            q.lt(Message::getId, beforeId);
        }
        List<Message> rows = messageMapper.selectList(q);

        LambdaQueryWrapper<Message> countQuery = new LambdaQueryWrapper<>();
        applySessionFilter(countQuery, userId, peerId);
        long total = messageMapper.selectCount(countQuery);
        Collections.reverse(rows);
        return new PageVO<>(toVOs(rows), total, 1, limit);
    }

    @Override
    public List<ChatSessionVO> mySessions(Long userId) {
        // 所有涉及我的单聊消息（group_id 为 null）。演示库量级小，一次取回在内存里聚合；
        // 真要大会话量，可按 peer 分组取 MAX(id) 后再回查，这里先不做这层优化。
        List<Message> involved = messageMapper.selectList(new LambdaQueryWrapper<Message>()
                .isNull(Message::getGroupId)
                .and(w -> w.eq(Message::getSenderId, userId).or().eq(Message::getReceiverId, userId))
                .orderByDesc(Message::getId));

        // 按对方聚合：倒序遍历，每个 peer 第一次出现的就是最新一条；顺带统计我这一侧未读
        Map<Long, Message> lastByPeer = new LinkedHashMap<>();
        Map<Long, Integer> unreadByPeer = new LinkedHashMap<>();
        for (Message m : involved) {
            Long peer = userId.equals(m.getSenderId()) ? m.getReceiverId() : m.getSenderId();
            lastByPeer.putIfAbsent(peer, m);
            if (userId.equals(m.getReceiverId()) && m.getReadStatus() != null && m.getReadStatus() == 0) {
                unreadByPeer.merge(peer, 1, Integer::sum);
            }
        }
        if (lastByPeer.isEmpty()) {
            return Collections.emptyList();
        }
        Map<Long, User> peers = loadUsers(new ArrayList<>(lastByPeer.keySet()));

        List<ChatSessionVO> result = new ArrayList<>();
        for (Map.Entry<Long, Message> e : lastByPeer.entrySet()) {
            Long peerId = e.getKey();
            Message last = e.getValue();
            User u = peers.get(peerId);
            ChatSessionVO vo = new ChatSessionVO();
            vo.setPeerId(peerId);
            vo.setPeerNickname(u != null ? u.getNickname() : null);
            vo.setPeerAvatar(u != null ? u.getAvatar() : null);
            vo.setLastMessage(last.getContent());
            vo.setLastMessageAt(last.getCreatedAt());
            vo.setUnread(unreadByPeer.getOrDefault(peerId, 0));
            vo.setSelfLast(userId.equals(last.getSenderId()));
            result.add(vo);
        }
        return result;
    }

    @Override
    public long unreadTotal(Long userId) {
        long privateUnread = messageMapper.selectCount(new LambdaQueryWrapper<Message>()
                .eq(Message::getReceiverId, userId)
                .eq(Message::getReadStatus, 0)
                .isNull(Message::getGroupId));
        long groupUnread = 0;
        for (Long groupId : myGroupIds(userId)) {
            groupUnread += countGroupUnread(userId, groupId);
        }
        return privateUnread + groupUnread;
    }

    @Override
    public List<ChatMessageVO> offlineMessages(Long userId) {
        List<Message> all = new ArrayList<>();

        // 单聊未读
        all.addAll(messageMapper.selectList(new LambdaQueryWrapper<Message>()
                .eq(Message::getReceiverId, userId)
                .eq(Message::getReadStatus, 0)
                .isNull(Message::getGroupId)
                .orderByAsc(Message::getId)
                .last("LIMIT " + OFFLINE_LIMIT)));

        // 群聊未读：逐群限量，免得一个刷屏的群把补发配额吃光，别的群一条都补不到
        for (Long groupId : myGroupIds(userId)) {
            all.addAll(messageMapper.selectList(groupUnreadQuery(userId, groupId)
                    .orderByAsc(Message::getId)
                    .last("LIMIT " + OFFLINE_PER_GROUP_LIMIT)));
        }

        all.sort(Comparator.comparing(Message::getId));
        List<Message> capped = all.size() > OFFLINE_LIMIT
                ? new ArrayList<>(all.subList(0, OFFLINE_LIMIT))
                : all;
        return toVOs(capped);
    }

    // ── 发送 ────────────────────────────────────────────────────

    @Override
    @Transactional(rollbackFor = Exception.class)
    public ChatMessageVO sendToGroup(Long userId, Long groupId, String content) {
        BizAssert.notBlank(content, ChatErrorCode.CONTENT_BLANK);
        assertMember(userId, groupId);
        ChatGroup group = BizAssert.notNull(chatGroupMapper.selectById(groupId),
                CommonErrorCode.NOT_FOUND, "群不存在");
        assertGroupWritable(group);

        Message entity = newMessage(userId, content);
        entity.setGroupId(groupId);
        messageMapper.insert(entity);
        metrics.onAccepted();

        ChatMessageVO vo = toVOs(List.of(entity)).get(0);
        // 广播时把发送者自己也带上：同一账号可能开着多个端，另一个端也要看到这条
        Set<Long> members = new HashSet<>(groupMemberIds(groupId));
        String payload = toJson(Map.of("type", "chat", "message", vo));
        int delivered = registry.sendToUsers(members, payload);
        if (delivered > 1) {
            // 除自己以外还有人在线，才算真正"即时送达"
            metrics.onDeliveredOnline();
        } else {
            metrics.onQueuedOffline();
        }
        return vo;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public ChatMessageVO sendToUser(Long userId, Long receiverId, String content) {
        BizAssert.isTrue(!userId.equals(receiverId), ChatErrorCode.SEND_TO_SELF);
        BizAssert.notBlank(content, ChatErrorCode.CONTENT_BLANK);
        BizAssert.notNull(userMapper.selectById(receiverId), CommonErrorCode.USER_NOT_FOUND);

        Message entity = newMessage(userId, content);
        entity.setReceiverId(receiverId);
        messageMapper.insert(entity);
        metrics.onAccepted();

        ChatMessageVO vo = toVOs(List.of(entity)).get(0);
        String payload = toJson(Map.of("type", "chat", "message", vo));
        // 自己也推一份，口径与群聊广播一致：多端登录时，手机发出的消息网页端也要看到。
        // 到达率只看"对方"那一侧，所以自己的这一份不计入 deliveredOnline。
        registry.sendToUser(userId, payload);
        int delivered = registry.sendToUser(receiverId, payload);
        if (delivered > 0) {
            metrics.onDeliveredOnline();
        } else {
            metrics.onQueuedOffline();
        }
        return vo;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void sendSystemToGroup(Long groupId, Long operatorId, String content) {
        if (groupId == null) {
            return;
        }
        Message entity = newMessage(operatorId, content);
        entity.setGroupId(groupId);
        entity.setMsgType("SYSTEM");
        messageMapper.insert(entity);
        metrics.onAccepted();

        ChatMessageVO vo = toVOs(List.of(entity)).get(0);
        int delivered = registry.sendToUsers(new HashSet<>(groupMemberIds(groupId)),
                toJson(Map.of("type", "chat", "message", vo)));
        if (delivered > 0) {
            metrics.onDeliveredOnline();
        } else {
            metrics.onQueuedOffline();
        }
    }

    @Override
    public void markRead(Long userId, Long msgId) {
        Message msg = BizAssert.notNull(messageMapper.selectById(msgId), ChatErrorCode.MESSAGE_NOT_FOUND);
        if (msg.getGroupId() != null) {
            assertMember(userId, msg.getGroupId());
            advanceGroupCursor(userId, msg.getGroupId(), msg.getId());
            return;
        }
        if (userId.equals(msg.getReceiverId())) {
            // 单聊标到该条为止（含同一发件人更早的未读），与群聊游标“读到哪算到哪”同义：
            // 进房间只 markRead 最新一条，之前连发的未读要一并清零，否则列表未读数假性残留。
            messageMapper.update(null, new LambdaUpdateWrapper<Message>()
                    .set(Message::getReadStatus, 1)
                    .eq(Message::getReceiverId, userId)
                    .eq(Message::getSenderId, msg.getSenderId())
                    .le(Message::getId, msgId));
        }
    }

    @Override
    public Map<String, Object> stats() {
        Map<String, Object> m = new LinkedHashMap<>(metrics.snapshot());
        m.put("onlineConnections", registry.onlineConnectionCount());
        m.put("onlineUsers", registry.onlineUsers().size());
        return m;
    }

    // ── 私有工具 ────────────────────────────────────────────────

    private Message newMessage(Long senderId, String content) {
        Message entity = new Message();
        entity.setSenderId(senderId);
        entity.setMsgType("TEXT");
        entity.setContent(content.trim());
        entity.setReadStatus(0);
        // 显式给创建时间：表里虽有 DEFAULT CURRENT_TIMESTAMP，但 insert 后不会回填到实体，
        // 而下面要立刻把实体转成 VO 回给客户端，时间不能是 null
        entity.setCreatedAt(LocalDateTime.now());
        return entity;
    }

    /** 单聊会话的双方消息（两个方向），拼条件而不是 clone wrapper——参数化更直白 */
    private void applySessionFilter(LambdaQueryWrapper<Message> q, Long userId, Long peerId) {
        q.isNull(Message::getGroupId);
        q.and(w -> w
                .and(x -> x.eq(Message::getSenderId, userId).eq(Message::getReceiverId, peerId))
                .or(y -> y.eq(Message::getSenderId, peerId).eq(Message::getReceiverId, userId)));
    }

    private long countGroupUnread(Long userId, Long groupId) {
        return messageMapper.selectCount(groupUnreadQuery(userId, groupId));
    }

    /**
     * 群未读的查询条件：本群、非我发送、且在游标之后。
     * 游标没有时（刚入群）用入群时间兜底，否则新成员会把入群前的历史全算成未读。
     */
    private LambdaQueryWrapper<Message> groupUnreadQuery(Long userId, Long groupId) {
        LambdaQueryWrapper<Message> q = new LambdaQueryWrapper<Message>()
                .eq(Message::getGroupId, groupId)
                .ne(Message::getSenderId, userId);
        long cursor = groupCursor(userId, groupId);
        if (cursor > 0) {
            return q.gt(Message::getId, cursor);
        }
        ChatGroupMember member = chatGroupMemberMapper.selectOne(new LambdaQueryWrapper<ChatGroupMember>()
                .eq(ChatGroupMember::getGroupId, groupId)
                .eq(ChatGroupMember::getUserId, userId)
                .last("LIMIT 1"));
        LocalDateTime since = (member == null || member.getJoinedAt() == null)
                ? EPOCH : member.getJoinedAt();
        return q.gt(Message::getCreatedAt, since);
    }

    private long groupCursor(Long userId, Long groupId) {
        String value = redisTemplate.opsForValue().get(cursorKey(userId, groupId));
        if (value == null) {
            return 0L;
        }
        try {
            return Long.parseLong(value);
        } catch (NumberFormatException ex) {
            return 0L;
        }
    }

    private void advanceGroupCursor(Long userId, Long groupId, Long msgId) {
        if (msgId <= groupCursor(userId, groupId)) {
            return;
        }
        redisTemplate.opsForValue().set(cursorKey(userId, groupId), String.valueOf(msgId), CURSOR_TTL);
    }

    private String cursorKey(Long userId, Long groupId) {
        return GROUP_CURSOR_PREFIX + userId + ":g" + groupId;
    }

    private void assertMember(Long userId, Long groupId) {
        long count = chatGroupMemberMapper.selectCount(new LambdaQueryWrapper<ChatGroupMember>()
                .eq(ChatGroupMember::getGroupId, groupId)
                .eq(ChatGroupMember::getUserId, userId));
        BizAssert.isTrue(count > 0, ChatErrorCode.NOT_GROUP_MEMBER);
    }

    /** 活动取消后群不解散，转为只读（见 docs/01 第五节）。 */
    private void assertGroupWritable(ChatGroup group) {
        if (group.getActivityId() == null) {
            return;
        }
        Activity activity = activityMapper.selectById(group.getActivityId());
        if (activity != null && ActivityStatus.CANCELLED.name().equals(activity.getStatus())) {
            throw ChatErrorCode.GROUP_READONLY.ex();
        }
    }

    private List<Long> myGroupIds(Long userId) {
        return chatGroupMemberMapper.selectList(new LambdaQueryWrapper<ChatGroupMember>()
                        .eq(ChatGroupMember::getUserId, userId))
                .stream().map(ChatGroupMember::getGroupId).toList();
    }

    private List<Long> groupMemberIds(Long groupId) {
        return chatGroupMemberMapper.selectList(new LambdaQueryWrapper<ChatGroupMember>()
                        .eq(ChatGroupMember::getGroupId, groupId))
                .stream().map(ChatGroupMember::getUserId).toList();
    }

    private List<ChatMessageVO> toVOs(List<Message> rows) {
        if (rows.isEmpty()) {
            return Collections.emptyList();
        }
        Map<Long, User> senders = loadUsers(rows.stream().map(Message::getSenderId).distinct().toList());
        return rows.stream().map(m -> {
            ChatMessageVO vo = new ChatMessageVO();
            vo.setId(m.getId());
            vo.setGroupId(m.getGroupId());
            vo.setReceiverId(m.getReceiverId());
            vo.setSenderId(m.getSenderId());
            vo.setMsgType(m.getMsgType());
            vo.setContent(m.getContent());
            vo.setReadStatus(m.getReadStatus());
            vo.setCreatedAt(m.getCreatedAt());
            User sender = senders.get(m.getSenderId());
            if (sender != null) {
                vo.setSenderNickname(sender.getNickname());
                vo.setSenderAvatar(sender.getAvatar());
            }
            return vo;
        }).toList();
    }

    private Map<Long, User> loadUsers(List<Long> ids) {
        if (ids.isEmpty()) {
            return Collections.emptyMap();
        }
        return userMapper.selectBatchIds(ids).stream()
                .collect(Collectors.toMap(User::getId, u -> u, (a, b) -> a));
    }

    private String toJson(Object payload) {
        try {
            return objectMapper.writeValueAsString(payload);
        } catch (JsonProcessingException ex) {
            log.error("[chat] 消息序列化失败", ex);
            throw CommonErrorCode.SYSTEM_ERROR.ex("消息序列化失败");
        }
    }

    private long normalizeSize(long size) {
        if (size <= 0) {
            return DEFAULT_PAGE_SIZE;
        }
        return Math.min(size, MAX_PAGE_SIZE);
    }
}
