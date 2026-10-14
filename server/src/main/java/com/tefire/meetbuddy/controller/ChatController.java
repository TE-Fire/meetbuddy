package com.tefire.meetbuddy.controller;

import com.tefire.meetbuddy.common.PageVO;
import com.tefire.meetbuddy.common.Result;
import com.tefire.meetbuddy.common.UserContext;
import com.tefire.meetbuddy.service.ChatService;
import com.tefire.meetbuddy.vo.ChatGroupVO;
import com.tefire.meetbuddy.vo.ChatMessageVO;
import com.tefire.meetbuddy.vo.ChatSessionVO;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/**
 * HTTP 侧只负责历史数据，实时收发走 WebSocket（见 docs/03 第六节）。
 * 路径都在 {@code /api/chat/**}，因此由 {@code AuthInterceptor} 统一要求登录。
 */
@RestController
@RequestMapping("/api/chat")
@RequiredArgsConstructor
@Validated
public class ChatController {

    private final ChatService chatService;

    @GetMapping("/groups")
    public Result<List<ChatGroupVO>> groups() {
        return Result.ok(chatService.myGroups(UserContext.getUserId()));
    }

    /** 我的单聊会话列表：每个有过私聊的对方一项，带最后一条与未读数，按最近消息倒序 */
    @GetMapping("/sessions")
    public Result<List<ChatSessionVO>> sessions() {
        return Result.ok(chatService.mySessions(UserContext.getUserId()));
    }

    @GetMapping("/group/{id}/messages")
    public Result<PageVO<ChatMessageVO>> groupMessages(
            @PathVariable Long id,
            @RequestParam(required = false) Long before,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) long size) {
        return Result.ok(chatService.groupMessages(UserContext.getUserId(), id, before, size));
    }

    @GetMapping("/session/{userId}/messages")
    public Result<PageVO<ChatMessageVO>> sessionMessages(
            @PathVariable("userId") Long peerId,
            @RequestParam(required = false) Long before,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) long size) {
        return Result.ok(chatService.sessionMessages(UserContext.getUserId(), peerId, before, size));
    }

    @GetMapping("/unread")
    public Result<Long> unread() {
        return Result.ok(chatService.unreadTotal(UserContext.getUserId()));
    }

    /**
     * 投递计数快照（到达率、离线积压、在线连接数）。M4 验收和论文的"到达率可统计"读这个。
     * 放 {@code /api/chat/stats} 而不是管理端：单机演示，不想为它单独做鉴权。
     */
    @GetMapping("/stats")
    public Result<Map<String, Object>> stats() {
        return Result.ok(chatService.stats());
    }
}
