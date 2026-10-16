import '../../model/credit_log.dart';
import '../../model/page_data.dart';

/// 信用分明细数据源。`GET /api/user/credit/logs`，按时间倒序分页。
abstract class CreditLogRepository {
  Future<PageData<CreditLog>> logs({int page = 1, int size = 20});
}
