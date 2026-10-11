import '../model/chat_group.dart';
import '../model/chat_message.dart';
import '../model/page_data.dart';

/// 聊天数据源（HTTP 侧，只负责历史数据）。实时收发走 [ChatSocket]。
abstract class ChatRepository {
  /// 我的群列表，带最后一条消息与未读数。
  Future<List<ChatGroup>> groups();

  /// 群历史。before 传上一页最小的 id，向上翻页；为 null 时取最新一页。
  Future<PageData<ChatMessage>> groupMessages(
    int groupId, {
    int? before,
    int size = 30,
  });

  /// 未读总数，底部导航的红点用。
  Future<int> unread();

  /// 投递计数快照：accepted、实时/最终到达率、离线积压、在线连接数。
  Future<Map<String, dynamic>> stats();
}
