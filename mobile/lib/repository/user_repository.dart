import '../model/user.dart';

/// 用户数据源。
abstract class UserRepository {
  Future<User> me();

  /// 上报坐标，后端同时刷新 Redis GEO 索引——不报坐标就进不了就近匹配的候选集。
  Future<void> updateLocation({required double lng, required double lat});

  /// 覆盖式更新兴趣标签，传什么就是什么。
  Future<void> updateTags(List<String> tags);
}
