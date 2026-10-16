import '../model/api_exception.dart';
import '../model/badge.dart';
import '../repository/badge_repository.dart';
import 'package:flutter/foundation.dart';

/// 徽章墙状态。
///
/// 只有一页、八枚，没有分页也没有本地写操作（解锁由后端在业务动作里顺手完成，
/// 前端拿不到"再去解锁一次"的入口），所以这个 state 只保留 [load]。
/// 徽章墙读一次就够，但 [AppShell] 切换 tab / 从后台回来时会再调 [refresh]，
/// 防止用户在别的页面干完了某件事、回来看到的还是旧进度。
class BadgeState extends ChangeNotifier {
  BadgeState({required BadgeRepository repo}) : _repo = repo;

  final BadgeRepository _repo;

  List<Badge> items = const <Badge>[];
  bool loading = false;
  String? lastError;

  int get earned => items.where((b) => b.unlocked).length;

  /// 未解锁且有进度组的徽章数——页面顶部"进行中 n"用。
  int get inProgress =>
      items.where((b) => !b.unlocked && b.group != 'NONE' && b.target > 0).length;

  Future<void> load() async {
    if (loading) {
      return;
    }
    loading = true;
    notifyListeners();
    try {
      items = await _repo.mine();
      lastError = null;
    } on ApiException catch (e) {
      lastError = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
