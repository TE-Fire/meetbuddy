import 'app_notification.dart';
import 'chat_message.dart';
import 'json_util.dart';

/// WebSocket 下行帧。服务端会发这六种：
///
///   {"type":"chat",   "message":{...}}          新消息
///   {"type":"ack",    "msgId":1}                已落库，可停止重发
///   {"type":"offline","messages":[{...}]}       重连补发，按时间正序
///   {"type":"pong"}                             心跳应答
///   {"type":"error",  "code":3101,"message":"…"}  错误
///   {"type":"notify", "notification":{...}}     新站内通知（`NotificationVO`）
///
/// 注意 `message` 字段在两种帧里语义不同：chat 帧里是消息对象，error 帧里是错误文案。
/// 所以这里按 type 分流解析，不能统一 asString。
class ChatEvent {
  const ChatEvent({
    required this.type,
    this.message,
    this.messages = const <ChatMessage>[],
    this.notification,
    this.msgId,
    this.code,
    this.errorMessage,
  });

  final String type;
  final ChatMessage? message;
  final List<ChatMessage> messages;

  /// notify 帧携带的通知本体。带上它，页面收到推送就能直接把这行插到列表头部，
  /// 不必为了拿到刚推来的这一条再打一次 `GET /api/notification`。
  final AppNotification? notification;

  final int? msgId;
  final int? code;
  final String? errorMessage;

  bool get isChat => type == 'chat';
  bool get isAck => type == 'ack';
  bool get isOffline => type == 'offline';
  bool get isError => type == 'error';
  bool get isPong => type == 'pong';
  bool get isNotify => type == 'notify';

  factory ChatEvent.fromJson(Map<String, dynamic> json) {
    final type = asString(json['type']);
    if (type == 'error') {
      return ChatEvent(
        type: type,
        code: asIntOrNull(json['code']),
        errorMessage: asStringOrNull(json['message']),
      );
    }
    if (type == 'chat') {
      final raw = json['message'];
      return ChatEvent(
        type: type,
        message: raw is Map ? ChatMessage.fromJson(raw.cast<String, dynamic>()) : null,
      );
    }
    if (type == 'notify') {
      final raw = json['notification'];
      return ChatEvent(
        type: type,
        notification:
            raw is Map ? AppNotification.fromJson(raw.cast<String, dynamic>()) : null,
      );
    }
    if (type == 'offline') {
      final raw = json['messages'];
      return ChatEvent(
        type: type,
        messages: raw is List
            ? raw
                .whereType<Map>()
                .map((e) => ChatMessage.fromJson(e.cast<String, dynamic>()))
                .toList()
            : const <ChatMessage>[],
      );
    }
    return ChatEvent(type: type, msgId: asIntOrNull(json['msgId']));
  }
}
