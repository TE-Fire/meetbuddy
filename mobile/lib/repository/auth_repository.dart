import '../model/auth_session.dart';

/// 认证数据源。mock 与真实实现共用这一套签名，见 docs/01 第八节。
abstract class AuthRepository {
  /// 发送短信验证码。dev profile 下后端不下发真实短信，固定码 123456。
  Future<void> sendSmsCode(String phone);

  Future<AuthSession> loginWithPassword({
    required String phone,
    required String password,
  });

  Future<AuthSession> loginWithSms({
    required String phone,
    required String code,
  });

  Future<AuthSession> register({
    required String phone,
    required String password,
    required String nickname,
    required String smsCode,
  });

  Future<void> logout();
}
