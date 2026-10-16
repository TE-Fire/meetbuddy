import '../../model/credit_log.dart';
import '../../model/json_util.dart';
import '../../model/page_data.dart';
import '../api_client.dart';
import '../credit_log_repository.dart';

/// 真实信用明细数据源。
class RealCreditLogRepository implements CreditLogRepository {
  RealCreditLogRepository(this._api);

  final ApiClient _api;

  @override
  Future<PageData<CreditLog>> logs({int page = 1, int size = 20}) async {
    final data = await _api.get(
      '/api/user/credit/logs',
      query: <String, Object?>{'page': page, 'size': size},
    );
    return PageData.fromJson(asMap(data), CreditLog.fromJson);
  }
}
