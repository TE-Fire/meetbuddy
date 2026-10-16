import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/api_exception.dart';
import '../model/auth_session.dart';
import '../model/user.dart';
import '../repository/api_client.dart';
import '../repository/auth_repository.dart';
import '../repository/chat_socket.dart';
import '../repository/user_repository.dart';

/// 登录态。
///
/// 令牌持久化到 SharedPreferences：Web 上是 localStorage，真机上是沙盒文件，
/// 两种平台共用一份代码。启动时先读本地令牌把界面点亮，再拉一次 `/user/me` 校验，
/// 这样冷启动不会闪一下登录页。
class SessionState extends ChangeNotifier {
  SessionState({
    required AuthRepository auth,
    required UserRepository user,
    required ApiClient api,
    required ChatSocket socket,
  })  : _auth = auth,
        _user = user,
        _api = api,
        _socket = socket;

  static const String _kAccess = 'meetbuddy.accessToken';
  static const String _kRefresh = 'meetbuddy.refreshToken';
  static const String _kUser = 'meetbuddy.user';

  final AuthRepository _auth;
  final UserRepository _user;
  final ApiClient _api;
  final ChatSocket _socket;

  User? _me;
  bool _restoring = true;
  bool _busy = false;

  User? get me => _me;
  String? get accessToken => _api.accessToken;
  bool get loggedIn => _me != null;
  bool get restoring => _restoring;
  bool get busy => _busy;

  /// 冷启动：读本地令牌 -> 点亮界面 -> 后台校验。
  Future<void> restore() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final access = sp.getString(_kAccess);
      final cached = sp.getString(_kUser);
      if (access == null || cached == null) {
        return;
      }
      _api.setToken(access);
      _me = User.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      notifyListeners();
      _restoring = false;
      notifyListeners();

      // 校验令牌是否还有效；失败就当没登录，不要留一个假登录态在界面上。
      final fresh = await _user.me();
      _me = fresh;
      await sp.setString(_kUser, jsonEncode(_userToJson(fresh)));
      notifyListeners();
      return;
    } catch (_) {
      await _clear();
    } finally {
      if (_restoring) {
        _restoring = false;
        notifyListeners();
      }
    }
  }

  Future<void> sendSmsCode(String phone) => _auth.sendSmsCode(phone);

  Future<void> loginWithPassword(String phone, String password) async {
    await _run(() => _auth.loginWithPassword(phone: phone, password: password));
  }

  Future<void> loginWithSms(String phone, String code) async {
    await _run(() => _auth.loginWithSms(phone: phone, code: code));
  }

  Future<void> register({
    required String phone,
    required String password,
    required String nickname,
    required String smsCode,
  }) async {
    await _run(() => _auth.register(
          phone: phone,
          password: password,
          nickname: nickname,
          smsCode: smsCode,
        ));
  }

  Future<void> _run(Future<AuthSession> Function() action) async {
    _busy = true;
    notifyListeners();
    try {
      final session = await action();
      await _apply(session);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _apply(AuthSession session) async {
    _api.setToken(session.accessToken);
    _me = session.user;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kAccess, session.accessToken);
    await sp.setString(_kRefresh, session.refreshToken);
    await sp.setString(_kUser, jsonEncode(_userToJson(session.user)));
    notifyListeners();
  }

  Future<void> logout() async {
    // 先断开长连接再清令牌：反过来的话，socket 的 close 会带着一个已失效的握手重试。
    await _socket.disconnect();
    try {
      await _auth.logout();
    } on ApiException {
      // 后端登出失败不该拦住本地退出
    }
    await _clear();
  }

  Future<void> refreshMe() async {
    if (!loggedIn) {
      return;
    }
    _me = await _user.me();
    notifyListeners();
  }

  /// 更新资料。成功后连本地缓存一起刷新——否则下一次冷启动会拿旧昵称点亮界面，
  /// 要等 `/user/me` 回来才纠正，中间会闪一下旧值。
  Future<void> updateProfile({
    required String nickname,
    String? bio,
    required int gender,
  }) async {
    _busy = true;
    notifyListeners();
    try {
      final updated = await _user.updateProfile(nickname: nickname, bio: bio, gender: gender);
      _me = updated;
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kUser, jsonEncode(_userToJson(updated)));
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// 标签走独立端点，后端不在这条路径上回传 UserVO，所以直接在本地合并，
  /// 省掉一次 `/user/me` 往返。
  Future<void> updateTags(List<String> tags) async {
    _busy = true;
    notifyListeners();
    try {
      await _user.updateTags(tags);
      final cur = _me;
      if (cur != null) {
        final updated = cur.copyWith(tags: tags);
        _me = updated;
        final sp = await SharedPreferences.getInstance();
        await sp.setString(_kUser, jsonEncode(_userToJson(updated)));
      }
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _clear() async {
    _api.setToken(null);
    _me = null;
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kAccess);
    await sp.remove(_kRefresh);
    await sp.remove(_kUser);
    notifyListeners();
  }

  Map<String, dynamic> _userToJson(User u) => <String, dynamic>{
        'id': u.id,
        'phone': u.phone,
        'nickname': u.nickname,
        'avatar': u.avatar,
        'gender': u.gender,
        'bio': u.bio,
        'creditScore': u.creditScore,
        'tags': u.tags,
      };
}
