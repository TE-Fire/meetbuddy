import '../../model/api_exception.dart';
import '../../model/page_data.dart';
import '../../model/recent_activity.dart';
import '../../model/user_brief.dart';
import '../../model/user_profile.dart';
import '../user_profile_repository.dart';
import 'mock_data.dart';

/// 内存个人主页数据源。
///
/// 关注关系是**真的可变的**（点关注确实会让计数 +1，列表里也确实多一个人）——
/// 这部分不能编常量，因为"乐观更新失败要回滚"的界面行为只有在真实变化下才看得出来。
/// 计数为 0 的空态也是同一道理。
class MockUserProfileRepository implements UserProfileRepository {
  MockUserProfileRepository(this._store);

  final MockStore _store;

  @override
  Future<UserProfile> profile(int userId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    _store.ensureSeeded();
    final u = _store.users[userId];
    if (u == null) {
      throw ApiException(1003, '用户不存在');
    }
    final isMe = userId == _store.currentUserId;
    return UserProfile(
      userId: u.id,
      nickname: u.nickname,
      avatar: u.avatar,
      bio: u.bio,
      creditScore: u.creditScore,
      banned: false,
      tags: u.tags,
      badges: _store.badgesOf(u.id),
      recentActivities: <RecentActivity>[
        for (final a in _store.recentFor(u.id))
          RecentActivity(
            id: a.id,
            title: a.title,
            coverUrl: a.coverUrl,
            status: a.status,
            startTime: a.startTime,
            role: a.organizerId == u.id ? 'ORGANIZER' : 'PARTICIPANT',
          ),
      ],
      // mock 里 hosted/joined 记的是"相关活动数"而非"已完成数"（理由见
      // MockStore.recentFor 的注释）；真实后端这两个字段只统计 FINISHED。
      hostedCount: _store.activities.where((a) => a.organizerId == u.id).length,
      joinedCount:
          _store.activities.where((a) => a.signedUp.contains(u.id)).length,
      followerCount: _store.followerCountOf(u.id),
      followingCount: _store.followingCountOf(u.id),
      // 看自己时恒为 false——后端也是这个口径，不能靠前端 if 兜。
      following: isMe ? false : _store.isFollowing(_store.currentUserId, u.id),
    );
  }

  @override
  Future<void> follow(int userId, {required bool on}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _store.ensureSeeded();
    final me = _store.currentUserId;
    if (userId == me) {
      throw ApiException(1001, '不能关注自己');
    }
    if (!_store.users.containsKey(userId)) {
      throw ApiException(1003, '用户不存在');
    }
    _store.setFollow(me, userId, on: on);
  }

  @override
  Future<PageData<UserBrief>> following(int userId, {int page = 1, int size = 20}) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    _store.ensureSeeded();
    return _page(_store.followingIdsOf(userId), page, size);
  }

  @override
  Future<PageData<UserBrief>> followers(int userId, {int page = 1, int size = 20}) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    _store.ensureSeeded();
    return _page(_store.followerIdsOf(userId), page, size);
  }

  /// 与后端 PageVO 同款分页：`total` 是总条数而不是总数页，页面靠
  /// `page * size < total` 判断还有没有下一页。
  PageData<UserBrief> _page(List<int> ids, int page, int size) {
    final from = (page - 1) * size;
    if (from >= ids.length) {
      return PageData<UserBrief>(list: <UserBrief>[], total: ids.length, page: page, size: size);
    }
    final slice = ids.sublist(from, (from + size).clamp(0, ids.length));
    final rows = <UserBrief>[];
    for (final id in slice) {
      final u = _store.users[id];
      if (u == null) {
        continue; // 关注过但账号已不在数据里的兜底，不让它变成 null 崩
      }
      rows.add(
        UserBrief(
          userId: u.id,
          nickname: u.nickname,
          avatar: u.avatar,
          creditScore: u.creditScore,
          banned: false,
        ),
      );
    }
    return PageData<UserBrief>(list: rows, total: ids.length, page: page, size: size);
  }
}
