import '../../model/app_notification.dart';
import '../../model/page_data.dart';
import '../notification_repository.dart';
import 'mock_data.dart';

/// 内存通知数据源。已读态是**真的会变**的，否则"点一条红点少一个"这条
/// 最容易写错的交互在 mock 下永远测不出来。
class MockNotificationRepository implements NotificationRepository {
  MockNotificationRepository(this._store);

  final MockStore _store;

  @override
  Future<PageData<AppNotification>> list({int page = 1, int size = 20}) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    _store.ensureSeeded();
    final all = _store.notifications;
    final from = (page - 1) * size;
    if (from >= all.length) {
      return PageData<AppNotification>(list: <AppNotification>[], total: all.length, page: page, size: size);
    }
    return PageData<AppNotification>(
      list: all.sublist(from, (from + size).clamp(0, all.length)),
      total: all.length,
      page: page,
      size: size,
    );
  }

  @override
  Future<int> unread() async {
    _store.ensureSeeded();
    return _store.unreadNotifications();
  }

  @override
  Future<void> markRead(int id) async {
    // 找不到或本来就已读，都当成功——后端也是幂等的，这里保持一致，
    // 免得页面得为一个"重复点同一条"的分支写特判。
    _store.markNotificationRead(id);
  }

  @override
  Future<int> readAll() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _store.markAllNotificationsRead();
  }
}
