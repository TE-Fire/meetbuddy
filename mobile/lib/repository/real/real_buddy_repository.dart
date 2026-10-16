import '../../model/buddy.dart';
import '../../model/json_util.dart';
import '../api_client.dart';
import '../buddy_repository.dart';

/// 真实找搭子数据源。
class RealBuddyRepository implements BuddyRepository {
  RealBuddyRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<BuddyRequest>> mine() async {
    final data = await _api.get('/api/buddy');
    return asMapList(data).map(BuddyRequest.fromJson).toList();
  }

  @override
  Future<List<BuddyMatch>> match({
    required double lng,
    required double lat,
    required double radius,
    int limit = 20,
  }) async {
    final data = await _api.get(
      '/api/buddy/match',
      query: <String, Object?>{
        'lng': lng,
        'lat': lat,
        'radius': radius,
        'limit': limit,
      },
    );
    return asMapList(data).map(BuddyMatch.fromJson).toList();
  }

  @override
  Future<int> create({
    required String title,
    String? description,
    required String category,
    required double lng, required double lat,
    String? timeRange,
    required List<String> tags,
  }) async {
    final data = await _api.post(
      '/api/buddy',
      body: <String, Object?>{
        'title': title,
        'description': description,
        'category': category,
        'lng': lng,
        'lat': lat,
        'timeRange': timeRange,
        'tags': tags,
      },
    );
    return asInt(data);
  }

  @override
  Future<void> close(int id) async {
    await _api.put('/api/buddy/$id/close');
  }
}
