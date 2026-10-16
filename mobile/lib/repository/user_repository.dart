import '../model/user.dart';

/// 用户数据源。
abstract class UserRepository {
  Future<User> me();

  /// 上报坐标，后端同时刷新 Redis GEO 索引——不报坐标就进不了就近匹配的候选集。
  Future<void> updateLocation({required double lng, required double lat});

  /// 覆盖式更新兴趣标签，传什么就是什么。
  Future<void> updateTags(List<String> tags);

  /// 更新资料，返回更新后的自己。
  ///
  /// 后端 `PUT /user/profile` 是覆盖式语义：nickname/gender 必传，bio 传空即清空。
  /// 头像不在这一批里——Flutter 侧选图要引原生插件（见 docs/14 的未做项）。
  Future<User> updateProfile({
    required String nickname,
    String? bio,
    required int gender,
  });
}
