import '../../model/chat_group.dart';
import '../../model/chat_message.dart';
import '../../model/json_util.dart';
import '../../model/page_data.dart';
import '../api_client.dart';
import '../chat_repository.dart';

/// 真实聊天数据源（HTTP 侧，只取历史）。实时收发由 [RealChatSocket] 负责。
class RealChatRepository implements ChatRepository {
  RealChatRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<ChatGroup>> groups() async {
    final data = await _api.get('/api/chat/groups');
    if (data is! List) {
      return const <ChatGroup>[];
    }
    return data
        .whereType<Map>()
        .map((e) => ChatGroup.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<PageData<ChatMessage>> groupMessages(
    int groupId, {
    int? before,
    int size = 30,
  }) async {
    final data = await _api.get(
      '/api/chat/group/$groupId/messages',
      query: <String, dynamic>{'before': before, 'size': size},
    );
    return PageData.fromJson(asMap(data), ChatMessage.fromJson);
  }

  @override
  Future<int> unread() async {
    final data = await _api.get('/api/chat/unread');
    return data is num ? data.toInt() : 0;
  }

  @override
  Future<Map<String, dynamic>> stats() async {
    final data = await _api.get('/api/chat/stats');
    return asMap(data);
  }
}
