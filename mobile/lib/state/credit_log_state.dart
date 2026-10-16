import '../model/api_exception.dart';
import '../model/credit_log.dart';
import '../repository/credit_log_repository.dart';
import 'package:flutter/foundation.dart';

/// 信用分明细状态。分页口径与通知一致：一页 20 条，"这一页拿回来的条数"
/// 判断到底（不用 total——翻页途中若有新流水插入，total 会变）。
class CreditLogState extends ChangeNotifier {
  CreditLogState({required CreditLogRepository repo}) : _repo = repo;

  final CreditLogRepository _repo;

  static const int _size = 20;

  final List<CreditLog> items = <CreditLog>[];
  bool loading = false;
  bool loadingMore = false;
  bool finished = false;
  String? lastError;

  int _page = 0;

  Future<void> refresh() async {
    if (loading) {
      return;
    }
    loading = true;
    notifyListeners();
    try {
      final page = await _repo.logs(page: 1, size: _size);
      items
        ..clear()
        ..addAll(page.list);
      _page = 1;
      finished = page.list.length < _size;
      lastError = null;
    } on ApiException catch (e) {
      lastError = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (loadingMore || finished || loading) {
      return;
    }
    loadingMore = true;
    notifyListeners();
    try {
      final page = await _repo.logs(page: _page + 1, size: _size);
      items.addAll(page.list);
      _page += 1;
      finished = page.list.length < _size;
      lastError = null;
    } on ApiException catch (e) {
      lastError = e.message;
    } finally {
      loadingMore = false;
      notifyListeners();
    }
  }
}
