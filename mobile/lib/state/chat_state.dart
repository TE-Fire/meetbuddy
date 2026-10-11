import 'dart:async';

import 'package:flutter/foundation.dart';

import '../model/api_exception.dart';
import '../model/chat_event.dart';
import '../model/chat_group.dart';
import '../model/chat_message.dart';
import '../repository/chat_repository.dart';
import '../repository/chat_socket.dart';

/// 聊天里的一行。乐观发送时 [pending] 为 true，收到 ack/chat 后转正。
class ChatEntry {
  ChatEntry(this.message, {this.pending = false});

  ChatMessage message;
  bool pending;
}

/// 聊天状态：群列表、每个群的消息、未读数、WebSocket 事件分发。
///
/// 事件分发集中在这里而不是各页面各听各的——同一条消息可能要同时更新
/// 群列表的顺序、当前会话的消息、以及底部导航的红点，只有一处持有全部状态才能做到。
class ChatState extends ChangeNotifier {
  ChatState({required ChatRepository repo, required ChatSocket socket})
      : _repo = repo,
        _socket = socket;

  final ChatRepository _repo;
  final ChatSocket _socket;

  StreamSubscription<ChatEvent>? _eventSub;
  StreamSubscription<bool>? _connSub;

  final List<ChatGroup> groups = <ChatGroup>[];
  final Map<int, List<ChatEntry>> _threads = <int, List<ChatEntry>>{};
  final Set<int> _loadedGroups = <int>{};

  bool _loadingGroups = false;
  bool connected = false;
  String? lastError;

  /// 最近一次 error 帧的码（31xx 段）。聊天页靠它把输入框置灰（3104 只读群）。
  int? lastErrorCode;
  int unreadTotal = 0;

  /// 当前打开的群。收到新消息时若不属于它，就把未读加上。
  int? activeGroupId;

  List<ChatEntry> thread(int groupId) => _threads[groupId] ?? const <ChatEntry>[];

  bool loaded(int groupId) => _loadedGroups.contains(groupId);

  bool get loadingGroups => _loadingGroups;

  /// 登录成功后由根组件调用。重复调用是安全的（会先断开旧连接）。
  Future<void> attach(String accessToken) async {
    await _eventSub?.cancel();
    await _connSub?.cancel();

    _eventSub = _socket.events.listen(_onEvent);
    _connSub = _socket.connection.listen((open) {
      connected = open;
      notifyListeners();
    });

    try {
      await _socket.connect(accessToken);
    } on ApiException catch (e) {
      lastError = e.message;
      notifyListeners();
    }
    await loadGroups();
  }

  Future<void> loadGroups() async {
    _loadingGroups = true;
    notifyListeners();
    try {
      final list = await _repo.groups();
      groups
        ..clear()
        ..addAll(list);
      unreadTotal = await _repo.unread();
      lastError = null;
    } on ApiException catch (e) {
      lastError = e.message;
    } finally {
      _loadingGroups = false;
      notifyListeners();
    }
  }

  Future<void> openGroup(int groupId) async {
    activeGroupId = groupId;
    if (!_loadedGroups.contains(groupId)) {
      try {
        final page = await _repo.groupMessages(groupId);
        _threads[groupId] = page.list.map((m) => ChatEntry(m)).toList();
        _loadedGroups.add(groupId);
      } on ApiException catch (e) {
        lastError = e.message;
      }
    }
    await _markRead(groupId);
    notifyListeners();
  }

  void closeGroup(int groupId) {
    if (activeGroupId == groupId) {
      activeGroupId = null;
    }
  }

  void sendToGroup(int groupId, String content) {
    final text = content.trim();
    if (text.isEmpty) {
      return;
    }
    final me = _myId;
    if (me == null) {
      return;
    }
    // 乐观上屏：不等服务端回包，界面立刻能看到自己说的话。
    final optimistic = ChatMessage(
      id: -DateTime.now().microsecondsSinceEpoch,
      groupId: groupId,
      senderId: me,
      senderNickname: '我',
      content: text,
      createdAt: DateTime.now(),
    );
    (_threads[groupId] ??= <ChatEntry>[]).add(ChatEntry(optimistic, pending: true));
    notifyListeners();

    if (!_socket.connected) {
      lastError = '连接已断开，正在重连…';
      notifyListeners();
    }
    _socket.sendToGroup(groupId, text);
  }

  int? _myId;

  /// 由 attach 之前调用，让乐观消息知道"我"是谁。真实模式下从 SessionState 取。
  void bindMe(int userId) => _myId = userId;

  Future<void> _markRead(int groupId) async {
    final entries = _threads[groupId];
    if (entries == null || entries.isEmpty) {
      return;
    }
    final last = entries.last.message;
    _socket.markRead(last.id);
    final i = groups.indexWhere((g) => g.id == groupId);
    if (i >= 0 && groups[i].unread > 0) {
      final g = groups[i];
      groups[i] = ChatGroup(
        id: g.id,
        activityId: g.activityId,
        name: g.name,
        memberCount: g.memberCount,
        role: g.role,
        lastMessage: g.lastMessage,
        lastMessageAt: g.lastMessageAt,
        unread: 0,
      );
      unreadTotal = await _repo.unread();
    }
  }

  void _onEvent(ChatEvent event) {
    if (event.isError) {
      lastError = event.errorMessage;
      lastErrorCode = event.code;
      notifyListeners();
      return;
    }
    if (event.isOffline) {
      for (final m in event.messages) {
        _appendIncoming(m);
      }
      notifyListeners();
      return;
    }
    if (event.isChat && event.message != null) {
      _appendIncoming(event.message!);
      notifyListeners();
      return;
    }
    // ack / pong：ack 用来把乐观消息转正
    if (event.isAck && event.msgId != null) {
      _resolvePending(event.msgId!);
      notifyListeners();
    }
  }

  void _appendIncoming(ChatMessage message) {
    final groupId = message.groupId;
    // 单聊先只记提示，M6 的会话页再补
    if (groupId == null) {
      return;
    }
    final entries = _threads[groupId];

    // 自己发的消息先把对应的乐观行转正，避免同一条出现两遍
    if (entries != null && message.senderId == _myId) {
      final i = entries.indexWhere((e) => e.pending && e.message.content == message.content);
      if (i >= 0) {
        entries[i] = ChatEntry(message);
        _touchGroup(groupId, message);
        return;
      }
    }

    if (entries != null) {
      if (!entries.any((e) => e.message.id == message.id)) {
        entries.add(ChatEntry(message));
      }
    }
    final isActive = activeGroupId == groupId;
    _touchGroup(groupId, message, bumpUnread: !isActive);
    if (isActive) {
      _socket.markRead(message.id);
    }
  }

  void _resolvePending(int msgId) {
    for (final entries in _threads.values) {
      for (final e in entries) {
        if (e.pending) {
          e.pending = false;
          return;
        }
      }
    }
  }

  /// 更新群列表里的"最后一条消息"与排序，并在需要时累加未读。
  void _touchGroup(int groupId, ChatMessage message, {bool bumpUnread = false}) {
    final i = groups.indexWhere((g) => g.id == groupId);
    if (i < 0) {
      // 新群（比如刚报名进的群）不在列表里，重新拉一次
      unawaited(loadGroups());
      return;
    }
    final g = groups[i];
    groups[i] = ChatGroup(
      id: g.id,
      activityId: g.activityId,
      name: g.name,
      memberCount: g.memberCount,
      role: g.role,
      lastMessage: message.isSystem ? message.content : '${message.senderNickname ?? '有人'}：${message.content}',
      lastMessageAt: message.createdAt ?? DateTime.now(),
      unread: bumpUnread ? g.unread + 1 : g.unread,
    );
    groups.sort((a, b) {
      if (a.lastMessageAt == null && b.lastMessageAt == null) return 0;
      if (a.lastMessageAt == null) return 1;
      if (b.lastMessageAt == null) return -1;
      return b.lastMessageAt!.compareTo(a.lastMessageAt!);
    });
    if (bumpUnread) {
      unreadTotal += 1;
    }
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }
}
