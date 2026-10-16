import '../../model/activity.dart';
import '../../model/activity_draft.dart';
import '../../model/json_util.dart';
import '../../model/page_data.dart';
import '../activity_repository.dart';
import '../api_client.dart';

/// 真实活动数据源，走 `/api/activity/**`。
class RealActivityRepository implements ActivityRepository {
  RealActivityRepository(this._api);

  final ApiClient _api;

  @override
  Future<PageData<Activity>> list({
    String? category,
    String? status,
    String? sortBy,
    double? lng,
    double? lat,
    double? radius,
    int page = 1,
    int size = 20,
  }) async {
    final data = await _api.get('/api/activity', query: <String, dynamic>{
      'category': category,
      'status': status,
      'sortBy': sortBy,
      'lng': lng,
      'lat': lat,
      'radius': radius,
      'page': page,
      'size': size,
    });
    return PageData.fromJson(asMap(data), Activity.fromJson);
  }

  @override
  Future<Activity> detail(int id) async {
    final data = await _api.get('/api/activity/$id');
    return Activity.fromJson(asMap(data));
  }

  @override
  Future<CreatedActivity> create(ActivityDraft draft) async {
    final data = await _api.post('/api/activity', body: draft.toJson());
    return CreatedActivity.fromJson(asMap(data));
  }

  @override
  Future<void> update(int id, ActivityDraft draft) async {
    // 编辑与发布复用同一个请求体（后端 ActivityCreateRequest），
    // 所以这里直接拿 draft.toJson()——不为"编辑"再造一套字段名。
    await _api.put('/api/activity/$id', body: draft.toJson());
  }

  @override
  Future<void> signUp(int id, {String? remark}) async {
    await _api.post('/api/activity/$id/signup', body: <String, dynamic>{'remark': remark});
  }

  @override
  Future<void> cancelSignUp(int id) async {
    await _api.delete('/api/activity/$id/signup');
  }

  @override
  Future<void> cancelActivity(int id) async {
    await _api.post('/api/activity/$id/cancel');
  }

  @override
  Future<void> favorite(int id, {required bool on}) async {
    if (on) {
      await _api.post('/api/activity/$id/favorite');
    } else {
      await _api.delete('/api/activity/$id/favorite');
    }
  }

  @override
  Future<PageData<Activity>> mineOrganized({int page = 1, int size = 20}) async {
    final data = await _api.get(
      '/api/activity/mine/organized',
      query: <String, dynamic>{'page': page, 'size': size},
    );
    return PageData.fromJson(asMap(data), Activity.fromJson);
  }

  @override
  Future<PageData<Activity>> mineJoined({int page = 1, int size = 20}) async {
    final data = await _api.get(
      '/api/activity/mine/joined',
      query: <String, dynamic>{'page': page, 'size': size},
    );
    return PageData.fromJson(asMap(data), Activity.fromJson);
  }
}
