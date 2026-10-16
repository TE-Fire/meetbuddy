import '../../model/badge.dart';
import '../../model/json_util.dart';
import '../api_client.dart';
import '../badge_repository.dart';

class RealBadgeRepository implements BadgeRepository {
  RealBadgeRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Badge>> mine() async {
    final data = await _api.get('/api/badge/mine');
    // 后端直接回一个 JSON 数组，没有信封。用 asMapList 而不是 asList——
    // 它会把每个元素都过一遍 asMap，元素类型不对时抛的是可读的错误，
    // 而不是等到 fromJson 里才崩。后端哪天改成 { list: [...] } 也能立刻发现。
    return asMapList(data).map(Badge.fromJson).toList();
  }
}
