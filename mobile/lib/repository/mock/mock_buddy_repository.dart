import '../../model/buddy.dart';
import '../buddy_repository.dart';
import 'mock_data.dart';

/// 内存找搭子数据源。
///
/// 与 `MockActivityRepository` 一样只收 `MockStore`：匹配结果的坐标、分数、共同标签都
/// 由 store 算（store 持有所有用户与需求的真实数据），这里只负责转成模型并截断。
class MockBuddyRepository implements BuddyRepository {
  MockBuddyRepository(this._store);

  final MockStore _store;

  @override
  Future<List<BuddyRequest>> mine() async {
    return _store
        .buddyRequestsOf(_store.currentUserId)
        .map((r) => _toRequest(r))
        .toList();
  }

  @override
  Future<List<BuddyMatch>> match({
    required double lng,
    required double lat,
    required double radius,
    int limit = 20,
  }) async {
    final myTags = _store.me.tags;
    return _store
        .matchBuddies(lng: lng, lat: lat, radius: radius, myTags: myTags, limit: limit)
        .map((v) => BuddyMatch(
              userId: v.record.userId,
              nickname: v.nickname,
              avatar: v.avatar,
              creditScore: v.creditScore,
              requestId: v.record.id,
              title: v.record.title,
              category: v.record.category,
              timeRange: v.record.timeRange,
              score: v.score,
              distance: v.distanceKm,
              commonTags: v.commonTags,
              reason: v.reason,
            ))
        .toList();
  }

  @override
  Future<int> create({
    required String title,
    String? description,
    required String category,
    required double lng,
    required double lat,
    String? timeRange,
    required List<String> tags,
  }) async {
    final r = _store.addBuddy(
      userId: _store.currentUserId,
      title: title,
      description: description,
      category: category,
      lng: lng,
      lat: lat,
      timeRange: timeRange,
      tags: tags,
    );
    return r.id;
  }

  @override
  Future<void> close(int id) async => _store.closeBuddy(id);

  BuddyRequest _toRequest(MockBuddyRecord r) {
    final owner = _store.users[r.userId];
    return BuddyRequest(
      id: r.id,
      userId: r.userId,
      nickname: owner?.nickname ?? '匿名用户',
      avatar: owner?.avatar,
      title: r.title,
      description: r.description,
      category: r.category,
      timeRange: r.timeRange,
      status: r.status,
      tags: r.tags,
      creditScore: owner?.creditScore ?? 60,
      createdAt: r.createdAt,
    );
  }
}
