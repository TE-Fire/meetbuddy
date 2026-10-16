import '../../model/credit_log.dart';
import '../../model/page_data.dart';
import '../credit_log_repository.dart';
import 'mock_data.dart';

/// 内存信用明细数据源。分页语义与后端一致：按时间倒序，一页 20 条。
class MockCreditLogRepository implements CreditLogRepository {
  MockCreditLogRepository(this._store);

  final MockStore _store;

  @override
  Future<PageData<CreditLog>> logs({int page = 1, int size = 20}) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _store.ensureSeeded();
    final all = _store.creditLogsOf(_store.me.id);
    final start = (page - 1) * size;
    final list = start >= all.length
        ? const <CreditLog>[]
        : all.sublist(start, (start + size).clamp(0, all.length));
    return PageData<CreditLog>(list: list, total: all.length, page: page, size: size);
  }
}
