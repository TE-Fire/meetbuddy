import '../model/app_notification.dart';
import '../model/page_data.dart';

/// 站内通知数据源。规则见 `docs/05-通知与提醒.md`。
///
/// "列表"与"未读数"刻意分成两个方法：后端 `PageVO` 不带统计字段（与 chat-list
/// 同款口径），未读数是单独一次 `GET /api/notification/unread`。合成一个返回体
/// 看着方便，但会让"只想知道红点有没有"的调用方白拉一整页。
abstract class NotificationRepository {
  Future<PageData<AppNotification>> list({int page = 1, int size = 20});

  /// 未读条数。底部导航的"消息"红点是**聊天未读 + 通知未读**两者之和。
  Future<int> unread();

  /// 标记单条已读。后端幂等。
  Future<void> markRead(int id);

  /// 全部标记已读，返回这次实际改动的条数。
  Future<int> readAll();
}
