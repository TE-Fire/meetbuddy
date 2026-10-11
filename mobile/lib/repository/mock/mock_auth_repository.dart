import '../../model/api_exception.dart';
import '../../model/auth_session.dart';
import '../auth_repository.dart';
import 'mock_data.dart';

/// 内存认证数据源。行为刻意对齐真实后端的错误码，这样切到真后端时页面提示不用改。
class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this._store);

  final MockStore _store;

  /// 模拟网络往返，让加载态真的看得见（否则 Future 立刻完成，转圈一闪而过）。
  static Future<void> _latency([int ms = 320]) => Future<void>.delayed(Duration(milliseconds: ms));

  @override
  Future<void> sendSmsCode(String phone) async {
    await _latency();
    if (phone.length != 11) {
      throw ApiException(1001, '手机号格式不正确');
    }
  }

  @override
  Future<AuthSession> loginWithPassword({
    required String phone,
    required String password,
  }) async {
    await _latency();
    _store.ensureSeeded();
    final user = _store.byPhone(phone);
    if (user == null || !_store.checkPassword(phone, password)) {
      throw ApiException(1006, '手机号或密码错误');
    }
    _store.currentUserId = user.id;
    return AuthSession(accessToken: 'mock-access-${user.id}', refreshToken: 'mock-refresh-${user.id}', user: user);
  }

  @override
  Future<AuthSession> loginWithSms({required String phone, required String code}) async {
    await _latency();
    _store.ensureSeeded();
    if (code != '123456') {
      throw ApiException(3001, '验证码错误');
    }
    var user = _store.byPhone(phone);
    user ??= _store.addUser(phone: phone, nickname: '用户${phone.substring(7)}', password: '123456');
    _store.currentUserId = user.id;
    return AuthSession(accessToken: 'mock-access-${user.id}', refreshToken: 'mock-refresh-${user.id}', user: user);
  }

  @override
  Future<AuthSession> register({
    required String phone,
    required String password,
    required String nickname,
    required String smsCode,
  }) async {
    await _latency();
    _store.ensureSeeded();
    if (smsCode != '123456') {
      throw ApiException(3001, '验证码错误');
    }
    if (_store.byPhone(phone) != null) {
      throw ApiException(1005, '该手机号已注册');
    }
    final user = _store.addUser(phone: phone, nickname: nickname, password: password);
    _store.currentUserId = user.id;
    return AuthSession(accessToken: 'mock-access-${user.id}', refreshToken: 'mock-refresh-${user.id}', user: user);
  }

  @override
  Future<void> logout() => _latency(120);
}
