import '../../model/chat_group.dart';
import '../../model/chat_message.dart';
import '../../model/page_data.dart';
import '../chat_repository.dart';
import 'mock_data.dart';

/// 内存聊天数据源（HTTP 侧，只取历史）。实时收发由 [MockChatSocket] 负责。
class MockChatRepository implements ChatRepository {
  MockChatRepository(this._store);

  final MockStore _store;

  static Future<void> _latency([int ms = 220]) => Future<void>.delayed(Duration(milliseconds: ms));

  @override
  Future<List<ChatGroup>> groups() async {
    await _latency();
    _store.ensureSeeded();
    final me = _store.currentUserId;
    final mine = _store.groups.where((g) => g.members.contains(me)).toList();
    final list = mine.map((g) => _store.toChatGroup(g, me)).toList()
      ..sort((a, b) {
        final x = a.lastMessageAt;
        final y = b.lastMessageAt;
        if (x == null && y == null) return 0;
        if (x == null) return 1;
        if (y == null) return -1;
        return y.compareTo(x);
      });
    return list;
  }

  @override
  Future<PageData<ChatMessage>> groupMessages(
    int groupId, {
    int? before,
    int size = 30,
  }) async {
    await _latency(180);
    _store.ensureSeeded();
    var all = _store.groupMessages(groupId);
    if (before != null) {
      all = all.where((m) => m.id < before).toList();
    }
    final total = all.length;
    final slice = all.length <= size ? all : all.sublist(all.length - size);
    return PageData<ChatMessage>(list: slice, total: total, page: 1, size: size);
  }

  @override
  Future<int> unread() async {
    await _latency(120);
    _store.ensureSeeded();
    final me = _store.currentUserId;
    return _store.groups
        .where((g) => g.members.contains(me))
        .fold<int>(0, (sum, g) => sum + _store.unreadInGroup(g.id, me));
  }

  @override
  Future<Map<String, dynamic>> stats() async {
    await _latency(120);
    return <String, dynamic>{
      'accepted': 0,
      'deliveredOnline': 0,
      'queuedOffline': 0,
      'replayed': 0,
      'rejected': 0,
      'acks': 0,
      'realtimeDeliveryRate': 0,
      'eventualDeliveryRate': 0,
      'offlineBacklog': 0,
      'onlineConnections': 0,
      'onlineUsers': 0,
      'note': 'MOCK 数据源不计投递指标',
    };
  }
}
