package com.tefire.meetbuddy.ws;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.tefire.meetbuddy.common.error.BizException;
import com.tefire.meetbuddy.common.error.ChatErrorCode;
import com.tefire.meetbuddy.common.error.CommonErrorCode;
import com.tefire.meetbuddy.common.error.IErrorCode;
import com.tefire.meetbuddy.service.ChatService;
import com.tefire.meetbuddy.util.JwtUtil;
import com.tefire.meetbuddy.vo.ChatMessageVO;
import io.jsonwebtoken.Claims;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.io.IOException;
import java.net.URI;
import java.util.List;
import java.util.Map;

/**
 * WebSocket 协议处理：认证、拆帧、回执。业务全在 {@link ChatService} 里。
 *
 * <p>帧格式见 docs/03 第六节。客户端只发三种帧：{@code chat} / {@code read} / {@code heartbeat}；
 * 服务端回 {@code chat}（新消息）、{@code ack}（已落库，带 msgId）、{@code offline}（重连补发）、
 * {@code pong}，另有 {@code error} 帧承载 {@link ChatErrorCode} 里的码。
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ChatWebSocketHandler extends TextWebSocketHandler {

    private static final String ATTR_USER_ID = "userId";
    private static final String BLACKLIST_PREFIX = "jwt:blacklist:";

    /** 契约：心跳 30 秒一次，服务端 90 秒收不到任何帧就断开 */
    private static final long HEARTBEAT_TIMEOUT_MS = 90_000L;
    private static final long SWEEP_INTERVAL_MS = 30_000L;

    private final ChatSessionRegistry registry;
    private final ChatService chatService;
    private final ChatMetrics metrics;
    private final JwtUtil jwtUtil;
    private final StringRedisTemplate redisTemplate;
    private final ObjectMapper objectMapper;

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        Long userId = authenticate(session);
        if (userId == null) {
            // 握手已经完成、HTTP 200 也回了，这里只能靠 close 码表达"令牌不对"
            closeQuietly(session, CloseStatus.POLICY_VIOLATION.withReason("token invalid"));
            return;
        }
        session.getAttributes().put(ATTR_USER_ID, userId);
        registry.register(userId, session);

        // 一连上就把欠他的消息推过去。补发放在建立连接之后而不是"客户端主动拉"，
        // 是因为断线期间客户端根本不知道丢了多少条，让它自己去猜游标不如服务端说了算。
        List<ChatMessageVO> offline = chatService.offlineMessages(userId);
        if (!offline.isEmpty()) {
            registry.sendToUser(userId, toJson(Map.of("type", "offline", "messages", offline)));
            metrics.onReplayed(offline.size());
            log.info("[ws] 用户 {} 重连，补发离线消息 {} 条", userId, offline.size());
        }
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) {
        Long userId = (Long) session.getAttributes().get(ATTR_USER_ID);
        if (userId == null) {
            closeQuietly(session, CloseStatus.POLICY_VIOLATION.withReason("unauthenticated"));
            return;
        }
        // 任何一帧都算心跳：有消息往来就不该被判超时
        registry.touch(session.getId());

        JsonNode frame;
        try {
            frame = objectMapper.readTree(message.getPayload());
        } catch (JsonProcessingException ex) {
            sendError(userId, ChatErrorCode.INVALID_FRAME, "无法解析的 JSON");
            return;
        }

        String type = frame.path("type").asText("");
        try {
            switch (type) {
                case "heartbeat" -> registry.sendToUser(userId, toJson(Map.of("type", "pong")));
                case "chat" -> handleChat(userId, frame);
                case "read" -> handleRead(userId, frame);
                default -> sendError(userId, ChatErrorCode.INVALID_FRAME, "未知帧类型：" + type);
            }
        } catch (BizException ex) {
            metrics.onRejected();
            sendError(userId, ex.getErrorCode(), ex.getMessage());
        } catch (Exception ex) {
            metrics.onRejected();
            log.error("[ws] 处理帧失败 userId={} type={}", userId, type, ex);
            sendError(userId, CommonErrorCode.SYSTEM_ERROR, "服务端处理失败");
        }
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        registry.unregister(session.getId());
    }

    @Override
    public void handleTransportError(WebSocketSession session, Throwable exception) {
        log.warn("[ws] 传输异常 sessionId={} : {}", session.getId(), exception.getMessage());
        registry.unregister(session.getId());
        closeQuietly(session, CloseStatus.SERVER_ERROR);
    }

    /**
     * 心跳巡检。只靠 TCP 是不够的：客户端断网或进程被杀时不会发 close 帧，
     * 连接会一直挂在在线表里，别人发来的消息投进去石沉大海，发送方却以为对方收到了。
     */
    @Scheduled(fixedDelay = SWEEP_INTERVAL_MS)
    public void sweepIdleConnections() {
        int evicted = registry.evictIdle(HEARTBEAT_TIMEOUT_MS);
        if (evicted > 0) {
            log.info("[ws] 心跳巡检：踢掉 {} 条静默超过 {}s 的连接，在线连接剩 {}",
                    evicted, HEARTBEAT_TIMEOUT_MS / 1000, registry.onlineConnectionCount());
        }
    }

    private void handleChat(Long userId, JsonNode frame) {
        String content = frame.path("content").asText("");
        Long msgId;
        if (frame.hasNonNull("groupId")) {
            ChatMessageVO vo = chatService.sendToGroup(userId, frame.get("groupId").asLong(), content);
            msgId = vo.getId();
        } else if (frame.hasNonNull("receiverId")) {
            ChatMessageVO vo = chatService.sendToUser(userId, frame.get("receiverId").asLong(), content);
            msgId = vo.getId();
        } else {
            throw ChatErrorCode.INVALID_FRAME.ex("chat 帧必须带 groupId 或 receiverId");
        }
        // ack 表示"服务端已落库"，这时消息不会再丢，客户端可以停止重发
        registry.sendToUser(userId, toJson(Map.of("type", "ack", "msgId", msgId)));
        metrics.onAck();
    }

    private void handleRead(Long userId, JsonNode frame) {
        if (!frame.hasNonNull("msgId")) {
            throw ChatErrorCode.INVALID_FRAME.ex("read 帧必须带 msgId");
        }
        chatService.markRead(userId, frame.get("msgId").asLong());
    }

    /**
     * 从 {@code /ws?token=xxx} 里取令牌。浏览器发 WebSocket 握手带不了自定义 Header，
     * 所以令牌只能走 query —— 这也意味着它会进服务器访问日志，上线前要注意。
     */
    private Long authenticate(WebSocketSession session) {
        URI uri = session.getUri();
        if (uri == null) {
            return null;
        }
        String token = queryParam(uri.getQuery(), "token");
        if (token == null || token.isBlank()) {
            return null;
        }
        Claims claims = jwtUtil.parse(token);
        if (claims == null || !"access".equals(claims.get("type"))) {
            return null;
        }
        if (Boolean.TRUE.equals(redisTemplate.hasKey(BLACKLIST_PREFIX + claims.getId()))) {
            return null;
        }
        try {
            return Long.valueOf(claims.getSubject());
        } catch (NumberFormatException ex) {
            return null;
        }
    }

    private String queryParam(String query, String name) {
        if (query == null) {
            return null;
        }
        for (String pair : query.split("&")) {
            int eq = pair.indexOf('=');
            if (eq > 0 && name.equals(pair.substring(0, eq))) {
                return pair.substring(eq + 1);
            }
        }
        return null;
    }

    private void sendError(Long userId, IErrorCode code, String message) {
        registry.sendToUser(userId, toJson(Map.of(
                "type", "error",
                "code", code.getCode(),
                "message", message == null ? code.getMessage() : message)));
    }

    private String toJson(Object payload) {
        try {
            return objectMapper.writeValueAsString(payload);
        } catch (JsonProcessingException ex) {
            log.error("[ws] 序列化失败", ex);
            return "{\"type\":\"error\",\"code\":5000,\"message\":\"序列化失败\"}";
        }
    }

    private void closeQuietly(WebSocketSession session, CloseStatus status) {
        try {
            session.close(status);
        } catch (IOException ex) {
            log.debug("[ws] 关闭连接失败 sessionId={} : {}", session.getId(), ex.getMessage());
        }
    }
}
