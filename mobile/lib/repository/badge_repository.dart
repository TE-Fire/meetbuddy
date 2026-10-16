import '../model/badge.dart';

/// 徽章墙数据源。`GET /api/badge/mine` 返回全部徽章（含未解锁与进度）。
///
/// 只有一个接口，没有写操作——徽章由后端 `BadgeEnum` 定义、`BadgeScanJob` 定时评定，
/// 客户端不存在"点亮"某一枚的入口。所以这里不提供 markRead 之类的方法。
abstract class BadgeRepository {
  Future<List<Badge>> mine();
}
