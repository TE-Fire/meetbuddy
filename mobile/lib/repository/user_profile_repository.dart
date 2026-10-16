import '../model/page_data.dart';
import '../model/user_brief.dart';
import '../model/user_profile.dart';

/// 个人主页数据源。
///
/// "我的"页上的关注/粉丝计数、他人主页的全部内容都走这里，关注与取关也归它——
/// 关注关系是"用户之间的边"，从主页发起，没必要再拆一个 repository 出来。
abstract class UserProfileRepository {
  /// 公开资料 + 计数。看自己也看别人都用它——`following` 字段在后端就区分了视角。
  Future<UserProfile> profile(int userId);

  /// 关注 / 取关。后端是幂等的：重复关注不报错、重复取关也不报错，
  /// 所以这里不返回新状态，调用方自己维护乐观值。
  Future<void> follow(int userId, {required bool on});

  /// TA 关注的人。
  Future<PageData<UserBrief>> following(int userId, {int page = 1, int size = 20});

  /// 关注 TA 的人。
  Future<PageData<UserBrief>> followers(int userId, {int page = 1, int size = 20});
}
