import '../../model/auth_session.dart';
import '../../model/json_util.dart';
import '../api_client.dart';
import '../auth_repository.dart';

/// 真实认证数据源，走 `/api/auth/**`。
class RealAuthRepository implements AuthRepository {
  RealAuthRepository(this._api);

  final ApiClient _api;

  @override
  Future<void> sendSmsCode(String phone) async {
    await _api.post('/api/auth/sms/send', body: <String, dynamic>{'phone': phone});
  }

  @override
  Future<AuthSession> loginWithPassword({
    required String phone,
    required String password,
  }) async {
    final data = await _api.post(
      '/api/auth/login/password',
      body: <String, dynamic>{'phone': phone, 'password': password},
    );
    return AuthSession.fromJson(asMap(data));
  }

  @override
  Future<AuthSession> loginWithSms({
    required String phone,
    required String code,
  }) async {
    final data = await _api.post(
      '/api/auth/sms/login',
      body: <String, dynamic>{'phone': phone, 'code': code},
    );
    return AuthSession.fromJson(asMap(data));
  }

  @override
  Future<AuthSession> register({
    required String phone,
    required String password,
    required String nickname,
    required String smsCode,
  }) async {
    final data = await _api.post(
      '/api/auth/register',
      body: <String, dynamic>{
        'phone': phone,
        'password': password,
        'nickname': nickname,
        'smsCode': smsCode,
      },
    );
    return AuthSession.fromJson(asMap(data));
  }

  @override
  Future<void> logout() async {
    await _api.post('/api/auth/logout');
  }
}
