import '../model/chat_event.dart';

/// WebSocket 通道抽象。
///
/// 单独拆出来而不是塞进 [ChatRepository]：连接是有状态的（连/断/重连/心跳），
/// 而 repository 的每个方法都是无状态请求。混在一起 mock 会很难写。
abstract class ChatSocket {
  /// 连接状态：true 表示已连上。
  Stream<bool> get connection;

  /// 服务端下行帧。
  Stream<ChatEvent> get events;

  bool get connected;

  /// 用 access token 建连，地址是 `/ws?token=`（浏览器握手带不了自定义 Header）。
  Future<void> connect(String accessToken);

  /// 断开但保留通道对象。退出登录时用它——[dispose] 会把 StreamController 关掉，
  /// 之后重新登录就再也连不上了。
  Future<void> disconnect();

  void sendToGroup(int groupId, String content);

  void sendToUser(int receiverId, String content);

  void markRead(int msgId);

  void sendHeartbeat();

  Future<void> dispose();
}
