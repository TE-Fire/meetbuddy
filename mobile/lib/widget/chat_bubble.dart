import 'package:flutter/material.dart';

import '../model/chat_message.dart';

/// 聊天气泡。系统消息走中间一条灰字，不画气泡。
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 40),
        child: Center(
          child: Text(
            message.content,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.outline, height: 1.5),
          ),
        ),
      );
    }

    final bubbleColor = mine ? scheme.primary : Colors.white;
    final textColor = mine ? scheme.onPrimary : scheme.onSurface;

    return Padding(
      padding: EdgeInsets.only(
        left: mine ? 48 : 12,
        right: mine ? 12 : 48,
        top: 5,
        bottom: 5,
      ),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: <Widget>[
          if (!mine && showSender)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                message.senderNickname ?? '匿名用户',
                style: TextStyle(fontSize: 12, color: scheme.outline),
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
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft: Radius.circular(mine ? 14 : 4),
                      bottomRight: Radius.circular(mine ? 4 : 14),
                    ),
                    border: mine ? null : Border.all(color: scheme.outlineVariant),
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(fontSize: 15, color: textColor, height: 1.4),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
