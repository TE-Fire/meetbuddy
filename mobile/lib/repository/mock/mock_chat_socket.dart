import 'dart:async';
import 'dart:math';

import '../../model/chat_event.dart';
import '../../model/chat_message.dart';
import '../chat_socket.dart';
import 'mock_data.dart';

/// 内存 WebSocket 通道。
///
/// 行为对齐真实服务端的四条约定，前端逻辑才能原样换过去：
/// - 发出的消息先回 `ack(msgId)`，再回 `chat`（多端同步，自己也收得到）
/// - 群聊里另一位成员会在 1.2 秒后回一句，用来演示"对方在线"的样子
/// - 只读群（活动已取消）发言被 `3104` 拒
/// - 心跳回 `pong`
class MockChatSocket implements ChatSocket {
  MockChatSocket(this._store);

  final MockStore _store;

  final _events = StreamController<ChatEvent>.broadcast();
  final _connection = StreamController<bool>.broadcast();
  final Random _random = Random();

  bool _open = false;
  Timer? _joinTimer;

  @override
  Stream<ChatEvent> get events => _events.stream;

  @override
  Stream<bool> get connection => _connection.stream;

  @override
  bool get connected => _open;

  void _emit(ChatEvent e) {
    if (!_events.isClosed) {
      _events.add(e);
    }
  }

  @override
  Future<void> connect(String accessToken) async {
    _store.ensureSeeded();
    await Future<void>.delayed(const Duration(milliseconds: 260));
    _open = true;
    if (!_connection.isClosed) {
      _connection.add(true);
    }
    // 连上后模拟"重连补发"：把最近 1 条系统消息当离线积压推下来，用来演示该链路。
    _joinTimer?.cancel();
    _joinTimer = Timer(const Duration(milliseconds: 600), () {
      final me = _store.currentUserId;
      final pending = <ChatMessage>[];
      for (final g in _store.groups.where((g) => g.members.contains(me))) {
        for (final m in _store.groupMessages(g.id)) {
          if (m.senderId != me && m.id > (_store.readCursor[me]?[g.id] ?? 0)) {
            pending.add(m);
          }
        }
      }
      if (pending.isNotEmpty) {
        pending.sort((a, b) => a.id.compareTo(b.id));
        _emit(ChatEvent(type: 'offline', messages: pending));
      }
    });
  }

  @override
  Future<void> disconnect() async {
    _joinTimer?.cancel();
    _open = false;
    if (!_connection.isClosed) {
      _connection.add(false);
    }
  }

  @override
  void sendToGroup(int groupId, String content) {
    final me = _store.currentUserId;
    final group = _store.group(groupId);
    if (group == null) {
      _emit(ChatEvent(type: 'error', code: 3101, errorMessage: '群不存在'));
      return;
    }
    if (group.readonly) {
      _emit(ChatEvent(type: 'error', code: 3104, errorMessage: '活动已取消，群聊只读'));
      return;
    }
    final msg = _store.addGroupMessage(groupId, me, content);
    _emit(ChatEvent(type: 'ack', msgId: msg.id));
    _emit(ChatEvent(type: 'chat', message: msg));

    // 找个"别人"来回一句，纯演示用
    final others = group.members.where((id) => id != me && id != 0).toList();
    if (others.isNotEmpty) {
      final reply = others[_random.nextInt(others.length)];
      Timer(const Duration(milliseconds: 1200), () {
        if (!_open) {
          return;
        }
        final m = _store.addGroupMessage(groupId, reply, _cannedReply(content));
        _emit(ChatEvent(type: 'chat', message: m));
      });
    }
  }

  @override
  void sendToUser(int receiverId, String content) {
    // mock 下没有"别人的私聊"，只能给自己发一条，用来验证单聊链路渲染
    final me = _store.currentUserId;
    final msg = ChatMessage(
      id: 900000 + DateTime.now().millisecondsSinceEpoch % 100000,
      receiverId: receiverId,
      senderId: me,
      senderNickname: _store.users[me]?.nickname,
      content: content,
      createdAt: DateTime.now(),
    );
    _emit(ChatEvent(type: 'ack', msgId: msg.id));
    _emit(ChatEvent(type: 'chat', message: msg));
  }

  @override
  void markRead(int msgId) {
    final me = _store.currentUserId;
    for (final m in _store.messages) {
      if (m.id == msgId && m.groupId != null) {
        _store.markGroupRead(m.groupId!, me);
        return;
      }
    }
  }

  @override
  void sendHeartbeat() => _emit(const ChatEvent(type: 'pong'));

  static String _cannedReply(String incoming) {
    const replies = <String>[
      '好，我看看时间',
      '这个我有兴趣，算我一个',
      '场地我来订吧',
      '哈哈哈那必须去',
      '收到，到时候见',
    ];
    return incoming.length > 12 ? replies[1] : replies[incoming.length % replies.length];
  }

  @override
  Future<void> dispose() async {
    _joinTimer?.cancel();
    await _events.close();
    await _connection.close();
  }
}
