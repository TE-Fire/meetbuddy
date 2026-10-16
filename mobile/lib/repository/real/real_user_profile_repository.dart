import '../../model/json_util.dart';
import '../../model/page_data.dart';
import '../../model/user_brief.dart';
import '../../model/user_profile.dart';
import '../api_client.dart';
import '../user_profile_repository.dart';

/// 真实个人主页数据源。
///
/// 关注/取关走 POST / DELETE 同一路径，后端按方法区分——不用 `PUT {on:true}`，
/// 是因为"关注"本身是幂等资源创建，POST/DELETE 的语义更准，也让两边都能直接
/// 承受网络重试（重复 POST 只是把已有的边再确认一次）。
class RealUserProfileRepository implements UserProfileRepository {
  RealUserProfileRepository(this._api);

  final ApiClient _api;

  @override
  Future<UserProfile> profile(int userId) async {
    final data = await _api.get('/api/user/$userId/profile');
    return UserProfile.fromJson(asMap(data));
  }

  @override
  Future<void> follow(int userId, {required bool on}) async {
    if (on) {
      await _api.post('/api/user/$userId/follow');
    } else {
      await _api.delete('/api/user/$userId/follow');
    }
  }

  @override
  Future<PageData<UserBrief>> following(int userId, {int page = 1, int size = 20}) async {
    final data = await _api.get(
      '/api/user/$userId/following',
      query: <String, Object?>{'page': page, 'size': size},
    );
    return PageData.fromJson(asMap(data), UserBrief.fromJson);
  }

  @override
  Future<PageData<UserBrief>> followers(int userId, {int page = 1, int size = 20}) async {
    final data = await _api.get(
      '/api/user/$userId/followers',
      query: <String, Object?>{'page': page, 'size': size},
    );
    return PageData.fromJson(asMap(data), UserBrief.fromJson);
  }
}
