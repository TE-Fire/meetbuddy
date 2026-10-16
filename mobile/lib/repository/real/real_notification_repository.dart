import '../../model/app_notification.dart';
import '../../model/json_util.dart';
import '../../model/page_data.dart';
import '../api_client.dart';
import '../notification_repository.dart';

/// 真实通知数据源。四个方法对应后端四个端点，路径与语义一一对上，不做本地合并。
class RealNotificationRepository implements NotificationRepository {
  RealNotificationRepository(this._api);

  final ApiClient _api;

  @override
  Future<PageData<AppNotification>> list({int page = 1, int size = 20}) async {
    final data = await _api.get(
      '/api/notification',
      query: <String, Object?>{'page': page, 'size': size},
    );
    return PageData.fromJson(asMap(data), AppNotification.fromJson);
  }

  @override
  Future<int> unread() async {
    final data = await _api.get('/api/notification/unread');
    return asInt(data);
  }

  @override
  Future<void> markRead(int id) async {
    await _api.post('/api/notification/$id/read');
  }

  @override
  Future<int> readAll() async {
    final data = await _api.post('/api/notification/read-all');
    return asInt(data);
  }
}
