import 'json_util.dart';

/// 对应后端 ChatMessageVO。单聊时 groupId 为空，群聊时 receiverId 为空。
class ChatMessage {
  const ChatMessage({
    required this.id,
    this.groupId,
    this.receiverId,
    required this.senderId,
    this.senderNickname,
    this.senderAvatar,
    this.msgType = 'TEXT',
    this.content = '',
    this.readStatus,
    this.createdAt,
  });

  final int id;
  final int? groupId;
  final int? receiverId;
  final int senderId;
  final String? senderNickname;
  final String? senderAvatar;
  final String msgType;
  final String content;
  final int? readStatus;
  final DateTime? createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: asInt(json['id']),
        groupId: asIntOrNull(json['groupId']),
        receiverId: asIntOrNull(json['receiverId']),
        senderId: asInt(json['senderId']),
        senderNickname: asStringOrNull(json['senderNickname']),
        senderAvatar: asStringOrNull(json['senderAvatar']),
        msgType: asString(json['msgType'], 'TEXT'),
        content: asString(json['content']),
        readStatus: asIntOrNull(json['readStatus']),
        createdAt: asDateOrNull(json['createdAt']),
      );

  bool get isSystem => msgType == 'SYSTEM';

  bool isMine(int myId) => senderId == myId;
}
