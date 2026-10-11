package com.tefire.meetbuddy.ws;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.ConcurrentWebSocketSessionDecorator;

import java.io.IOException;
import java.util.Collection;
import java.util.Collections;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 在线连接表：userId ↔ WebSocketSession。
 *
 * <p>三件事在这里集中处理，别处不用再操心：
 *
 * <ol>
 *   <li><b>一个用户多条连接</b>。同一账号可能同时开着 Flutter 端和浏览器调试页，
 *       所以是 {@code userId -> Map<sessionId, session>} 而不是一对一。发消息时全部投递。</li>
 *   <li><b>session 不是线程安全的</b>。群聊广播时多个线程会同时对同一个 session 调
 *       {@code sendMessage}，Tomcat 会抛 {@code TEXT_PARTIAL_WRITING}。统一用
 *       {@link ConcurrentWebSocketSessionDecorator} 包一层，把并发发送串行化。</li>
 *   <li><b>心跳时间要自己记</b>。{@code WebSocketSession} 没有"上次收到消息时间"这种属性，
 *       所以单开一张表记，供 {@link #evictIdle} 巡检用。</li>
 * </ol>
 */
@Slf4j
@Component
public class ChatSessionRegistry {

    /** 单次发送的超时与缓冲上限，防止慢客户端把发送线程挂住 */
    private static final int SEND_TIME_LIMIT_MS = 5_000;
    private static final int SEND_BUFFER_SIZE = 512 * 1024;

    private final Map<Long, Map<String, WebSocketSession>> sessionsByUser = new ConcurrentHashMap<>();
    private final Map<String, WebSocketSession> sessionById = new ConcurrentHashMap<>();
    private final Map<String, Long> userBySession = new ConcurrentHashMap<>();
    private final Map<String, Long> lastSeenAt = new ConcurrentHashMap<>();

    public void register(Long userId, WebSocketSession raw) {
        WebSocketSession session = new ConcurrentWebSocketSessionDecorator(
                raw, SEND_TIME_LIMIT_MS, SEND_BUFFER_SIZE);
        sessionsByUser.computeIfAbsent(userId, k -> new ConcurrentHashMap<>()).put(session.getId(), session);
        sessionById.put(session.getId(), session);
        userBySession.put(session.getId(), userId);
        lastSeenAt.put(session.getId(), System.currentTimeMillis());
        log.info("[ws] 用户 {} 上线，sessionId={}，当前在线连接 {}",
                userId, session.getId(), sessionById.size());
    }

    public void unregister(String sessionId) {
        Long userId = userBySession.remove(sessionId);
        sessionById.remove(sessionId);
        lastSeenAt.remove(sessionId);
        if (userId == null) {
            return;
        }
        Map<String, WebSocketSession> sessions = sessionsByUser.get(userId);
        if (sessions != null) {
            sessions.remove(sessionId);
            if (sessions.isEmpty()) {
                sessionsByUser.remove(userId);
            }
        }
        log.info("[ws] 用户 {} 下线，sessionId={}，在线连接剩 {}", userId, sessionId, sessionById.size());
    }

    /** 收到任何一帧都算心跳，不只是显式的 heartbeat ——有消息往来就不该被判超时。 */
    public void touch(String sessionId) {
        lastSeenAt.put(sessionId, System.currentTimeMillis());
    }

    public boolean isOnline(Long userId) {
        Map<String, WebSocketSession> sessions = sessionsByUser.get(userId);
        return sessions != null && !sessions.isEmpty();
    }

    public Set<Long> onlineUsers() {
        return Collections.unmodifiableSet(sessionsByUser.keySet());
    }

    public int onlineConnectionCount() {
        return sessionById.size();
    }

    /** 投给某个用户的所有连接，返回成功投递的连接数（0 表示对方离线）。 */
    public int sendToUser(Long userId, String payload) {
        Map<String, WebSocketSession> sessions = sessionsByUser.get(userId);
        if (sessions == null || sessions.isEmpty()) {
            return 0;
        }
        int delivered = 0;
        for (WebSocketSession session : sessions.values()) {
            if (send(session, payload)) {
                delivered++;
            }
        }
        return delivered;
    }

    /** 群聊广播。自动跳过不在线的成员，返回实际投递到的连接数。 */
    public int sendToUsers(Collection<Long> userIds, String payload) {
        int delivered = 0;
        for (Long userId : userIds) {
            delivered += sendToUser(userId, payload);
        }
        return delivered;
    }

    /**
     * 心跳巡检：把静默超过 {@code idleMillis} 的连接关掉。
     * 之所以要主动踢而不是只依赖 TCP：客户端断网、进程被杀时不会发 close 帧，
     * 连接会一直挂在表里，消息投过去石沉大海，而发送方以为对方在线。
     */
    public int evictIdle(long idleMillis) {
        long now = System.currentTimeMillis();
        int evicted = 0;
        for (Map.Entry<String, Long> entry : lastSeenAt.entrySet()) {
            if (now - entry.getValue() <= idleMillis) {
                continue;
            }
            String sessionId = entry.getKey();
            WebSocketSession session = sessionById.get(sessionId);
            if (session != null) {
                try {
                    session.close(CloseStatus.SESSION_NOT_RELIABLE);
                } catch (IOException ex) {
                    log.debug("[ws] 关闭超时连接失败 sessionId={} : {}", sessionId, ex.getMessage());
                }
            }
            unregister(sessionId);
            evicted++;
        }
        return evicted;
    }

    private boolean send(WebSocketSession session, String payload) {
        if (!session.isOpen()) {
            return false;
        }
        try {
            session.sendMessage(new TextMessage(payload));
            return true;
        } catch (IOException | IllegalStateException ex) {
            log.warn("[ws] 发送失败 sessionId={} : {}", session.getId(), ex.getMessage());
            return false;
        }
    }
}
