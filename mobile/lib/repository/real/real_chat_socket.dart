import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../config/env.dart';
import '../../model/api_exception.dart';
import '../../model/chat_event.dart';
import '../chat_socket.dart';

/// 真实 WebSocket 通道。地址 `/ws?token=`，因为浏览器发起握手时带不了自定义 Header。
///
/// 这里不做自动重连——重连要判断"是不是令牌失效"（失效了再连多少次都没用），
/// 而令牌在 [AuthState] 手里，所以重连策略放上层，这里只忠实反映连接状态。
class RealChatSocket implements ChatSocket {
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  final _events = StreamController<ChatEvent>.broadcast();
  final _connection = StreamController<bool>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeatTimer;
  bool _open = false;

  @override
  Stream<ChatEvent> get events => _events.stream;

  @override
  Stream<bool> get connection => _connection.stream;

  @override
  bool get connected => _open;

  @override
  Future<void> connect(String accessToken) async {
    await _teardown();

    final uri = Uri.parse('${Env.wsBase}/ws?token=$accessToken');
    final channel = WebSocketChannel.connect(uri);
    _channel = channel;
    _subscription = channel.stream.listen(
      _onFrame,
      onDone: _onClosed,
      onError: (Object _) => _onClosed(),
      cancelOnError: false,
    );

    try {
      await channel.ready;
    } catch (e) {
      await _teardown();
      throw ApiException(-1, 'WebSocket 连接失败：$e');
    }

    _open = true;
    _connection.add(true);
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) => sendHeartbeat());
  }

  void _onFrame(dynamic raw) {
    if (raw is! String) {
      return;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _events.add(ChatEvent.fromJson(map));
    } catch (_) {
      // 单帧解析失败不该拖垮整条连接，丢掉即可
    }
  }

  void _onClosed() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _channel = null;
    if (_open) {
      _open = false;
      _connection.add(false);
    }
  }

  void _send(Map<String, Object?> frame) {
    final channel = _channel;
    if (channel == null) {
      return; // 没连上就丢；调用方看 connection 流自己决定要不要提示
    }
    channel.sink.add(jsonEncode(frame));
  }

  @override
  void sendToGroup(int groupId, String content) =>
      _send(<String, Object?>{'type': 'chat', 'groupId': groupId, 'content': content});

  @override
  void sendToUser(int receiverId, String content) =>
      _send(<String, Object?>{'type': 'chat', 'receiverId': receiverId, 'content': content});

  @override
  void markRead(int msgId) => _send(<String, Object?>{'type': 'read', 'msgId': msgId});

  @override
  void sendHeartbeat() => _send(<String, Object?>{'type': 'heartbeat'});

  @override
  Future<void> disconnect() async {
    final wasOpen = _open;
    await _teardown();
    if (wasOpen && !_connection.isClosed) {
      _connection.add(false);
    }
  }

  Future<void> _teardown() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    final channel = _channel;
    _channel = null;
    _open = false;
    await channel?.sink.close();
  }

  @override
  Future<void> dispose() async {
    await _teardown();
    await _events.close();
    await _connection.close();
  }
}
