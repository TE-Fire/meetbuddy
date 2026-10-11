import 'json_util.dart';
import 'user.dart';

/// 登录/注册/刷新的返回体，对应后端 TokenVO。
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final User user;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        accessToken: asString(json['accessToken']),
        refreshToken: asString(json['refreshToken']),
        user: User.fromJson((json['user'] as Map?)?.cast<String, dynamic>() ?? const {}),
      );
}
