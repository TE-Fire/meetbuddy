import 'json_util.dart';

/// 对应后端 ChatGroupVO。列表页要的最后一条消息与未读数都一次带出，不用逐群再请求。
class ChatGroup {
  const ChatGroup({
    required this.id,
    this.activityId,
    required this.name,
    this.memberCount = 0,
    this.role = 'MEMBER',
    this.lastMessage,
    this.lastMessageAt,
    this.unread = 0,
  });

  final int id;
  final int? activityId;
  final String name;
  final int memberCount;

  /// OWNER / MEMBER
  final String role;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unread;

  factory ChatGroup.fromJson(Map<String, dynamic> json) => ChatGroup(
        id: asInt(json['id']),
        activityId: asIntOrNull(json['activityId']),
        name: asString(json['name'], '未命名群聊'),
        memberCount: asInt(json['memberCount']),
        role: asString(json['role'], 'MEMBER'),
        lastMessage: asStringOrNull(json['lastMessage']),
        lastMessageAt: asDateOrNull(json['lastMessageAt']),
        unread: asInt(json['unread']),
      );
}
