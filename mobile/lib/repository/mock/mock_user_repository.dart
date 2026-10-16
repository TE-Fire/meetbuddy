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
    final cur = _store.me;
    _store.users[cur.id] = cur.copyWith(tags: tags);
  }

  @override
  Future<User> updateProfile({
    required String nickname,
    String? bio,
    required int gender,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final cur = _store.me;
    // 不用 copyWith：它的 `?? this.bio` 语义表达不了"把简介清空"。
    final updated = User(
      id: cur.id,
      phone: cur.phone,
      nickname: nickname,
      avatar: cur.avatar,
      gender: gender,
      bio: (bio == null || bio.trim().isEmpty) ? null : bio.trim(),
      creditScore: cur.creditScore,
      tags: cur.tags,
    );
    _store.users[cur.id] = updated;
    return updated;
  }
}
