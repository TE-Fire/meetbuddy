/// 找搭子数据源。与活动的"组局"是两条独立产品线：需求没有人数上限、没有截止时间，
/// 匹配靠地理就近 + 兴趣标签重合 + 信用分加权（见 docs/01 第七节）。
library;

import '../model/buddy.dart';

abstract class BuddyRepository {
  /// 我发布的需求。
  Future<List<BuddyRequest>> mine();

  /// 加权匹配。候选取自 Redis GEO，按 docs/01 的公式排序。
  /// [radius] 单位公里，区间 [0.5, 500]。
  Future<List<BuddyMatch>> match({
    required double lng,
    required double lat,
    required double radius,
    int limit = 20,
  });

  /// 发布需求，返回新需求 id。
  Future<int> create({
    required String title,
    String? description,
    required String category,
    required double lng,
    required double lat,
    String? timeRange,
    required List<String> tags,
  });

  /// 关闭需求（OPEN → CLOSED）。
  Future<void> close(int id);
}
