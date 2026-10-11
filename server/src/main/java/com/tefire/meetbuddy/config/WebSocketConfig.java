package com.tefire.meetbuddy.config;

import com.tefire.meetbuddy.ws.ChatWebSocketHandler;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;

/**
 * 注册 WebSocket 端点 {@code /ws}（见 docs/03 第六节）。
 *
 * <p>两点说明：
 *
 * <ul>
 *   <li><b>不走 AuthInterceptor</b>。拦截器只挂在 {@code /api/**} 上（见 {@code WebMvcConfig}），
 *       浏览器发 WebSocket 握手时带不了自定义 Header，令牌只能放 query
 *       （{@code /ws?token=xxx}），所以校验在握手回调里自己做，见 {@code ChatWebSocketHandler}。</li>
 *   <li><b>放开了 Origin 校验</b>。开发期 Flutter 跑在 {@code localhost:随机端口}，
 *       来源不固定；上线前应改成白名单，这一点记在 server/README.md 的遗留项里。</li>
 * </ul>
 */
@Configuration
@EnableWebSocket
@RequiredArgsConstructor
public class WebSocketConfig implements WebSocketConfigurer {

    private final ChatWebSocketHandler chatWebSocketHandler;

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        registry.addHandler(chatWebSocketHandler, "/ws")
                .setAllowedOriginPatterns("*");
    }
}
