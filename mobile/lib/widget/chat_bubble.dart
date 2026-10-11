import 'package:flutter/material.dart';

import '../model/chat_message.dart';
import 'ui.dart';

/// 聊天气泡。系统消息走中间一枚灰色药丸，不画气泡。
/// 自己的消息用品牌渐变，新消息带一个轻快的淡入上浮。
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.mine,
    this.pending = false,
    this.showSender = true,
  });

  final ChatMessage message;
  final bool mine;
  final bool pending;
  final bool showSender;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 40),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFE9ECF5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.content,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.5),
            ),
          ),
        ),
      );
    }

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: mine ? AppBrand.brand : null,
        color: mine ? null : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(mine ? 16 : 4),
          bottomRight: Radius.circular(mine ? 4 : 16),
        ),
        border: mine ? null : Border.all(color: AppBrand.line),
        boxShadow: mine
            ? <BoxShadow>[
                BoxShadow(
                  color: AppBrand.primary.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Text(
        message.content,
        style: TextStyle(fontSize: 14.5, color: mine ? Colors.white : AppBrand.ink, height: 1.45),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        left: mine ? 48 : 12,
        right: mine ? 12 : 48,
        top: 5,
        bottom: 5,
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child),
        ),
        child: Column(
          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: <Widget>[
            if (!mine && showSender)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  message.senderNickname ?? '匿名用户',
                  style: const TextStyle(fontSize: 12, color: AppBrand.muted),
                ),
              ),
            Row(
              mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                if (mine && pending)
                  Padding(
                    padding: const EdgeInsets.only(right: 6, bottom: 4),
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.6, color: scheme.outline),
                    ),
                  ),
                Flexible(child: bubble),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
