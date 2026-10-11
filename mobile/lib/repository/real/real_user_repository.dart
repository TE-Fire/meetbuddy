import '../../model/json_util.dart';
import '../../model/user.dart';
import '../api_client.dart';
import '../user_repository.dart';

/// 真实用户数据源，走 `/api/user/**`。
class RealUserRepository implements UserRepository {
  RealUserRepository(this._api);

  final ApiClient _api;

  @override
  Future<User> me() async {
    final data = await _api.get('/api/user/me');
    return User.fromJson(asMap(data));
  }

  @override
  Future<void> updateLocation({required double lng, required double lat}) async {
    await _api.post('/api/user/location', body: <String, dynamic>{'lng': lng, 'lat': lat});
  }

  @override
  Future<void> updateTags(List<String> tags) async {
    await _api.put('/api/user/tags', body: <String, dynamic>{'tags': tags});
  }
}
