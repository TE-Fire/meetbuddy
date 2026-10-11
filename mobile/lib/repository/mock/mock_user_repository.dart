import '../../model/user.dart';
import '../user_repository.dart';
import 'mock_data.dart';

/// 内存用户数据源。
class MockUserRepository implements UserRepository {
  MockUserRepository(this._store);

  final MockStore _store;

  /// 最后一次上报的坐标。活动流用它算"距你 x km"，并模拟后端的半径筛选。
  double? lastLng;
  double? lastLat;

  @override
  Future<User> me() async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    _store.ensureSeeded();
    return _store.me;
  }

  @override
  Future<void> updateLocation({required double lng, required double lat}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    lastLng = lng;
    lastLat = lat;
  }

  @override
  Future<void> updateTags(List<String> tags) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}
