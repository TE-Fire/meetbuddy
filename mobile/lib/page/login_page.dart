import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_scope.dart';
import '../config/env.dart';
import '../model/api_exception.dart';
import '../state/session_state.dart';
import '../widget/ui.dart';

enum _Mode { password, sms, register }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _nickname = TextEditingController();
  final _code = TextEditingController();

  _Mode _mode = _Mode.password;
  String? _error;
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _password.dispose();
    _nickname.dispose();
    _code.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _countdown -= 1);
      if (_countdown <= 0) {
        t.cancel();
      }
    });
  }

  Future<void> _sendCode() async {
    final session = context.read<SessionState>();
    setState(() => _error = null);
    try {
      await session.sendSmsCode(_phone.text.trim());
      _startCountdown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Env.useMock ? '验证码已发送（mock 固定 123456）' : '验证码已发送，开发期固定 123456')),
        );
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _submit() async {
    final session = context.read<SessionState>();
    final phone = _phone.text.trim();
    setState(() => _error = null);

    if (phone.length != 11) {
      setState(() => _error = '请输入 11 位手机号');
      return;
    }

    try {
      switch (_mode) {
        case _Mode.password:
          await session.loginWithPassword(phone, _password.text);
        case _Mode.sms:
          await session.loginWithSms(phone, _code.text.trim());
        case _Mode.register:
          if (_nickname.text.trim().isEmpty) {
            setState(() => _error = '给自己起个昵称吧');
            return;
          }
          await session.register(
            phone: phone,
            password: _password.text,
            nickname: _nickname.text.trim(),
            smsCode: _code.text.trim(),
          );
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    final scope = context.read<AppScope>();
    final scheme = Theme.of(context).colorScheme;
    final needsCode = _mode != _Mode.password;
    final needsPassword = _mode != _Mode.sms;

    return Scaffold(
      backgroundColor: AppBrand.skyTop,
      body: SkyBackground(
        height: 460,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    StaggeredIn(
                      index: 0,
                      child: const Padding(
                        padding: EdgeInsets.only(top: 10, bottom: 22),
                        child: DisplayHeading(
                          lead: '告别一个人',
                          highlight: '组局出发',
                          subtitle: '同城组局，找个搭子',
                          size: 29,
                          align: TextAlign.center,
                        ),
                      ),
                    ),
                    StaggeredIn(
                      index: 1,
                      child: const MapScene(
                        height: 208,
                        radius: 26,
                        badge: '📍 周六 19:00 · 4 人成局',
                        sticker: Icons.sports_esports_rounded,
                        stickerSecond: Icons.sports_tennis_rounded,
                        pins: <MapPinSpec>[
                          MapPinSpec('飞盘局', 0.50, 0.20),
                          MapPinSpec('桌游 4 缺 2', 0.10, 0.52, accent: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    StaggeredIn(
                      index: 2,
                      child: _modeSwitcher(),
                    ),
                    const SizedBox(height: 18),
                    StaggeredIn(
                      index: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          TextField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: '手机号',
                              prefixIcon: Icon(Icons.phone_iphone_rounded, size: 20),
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (_mode == _Mode.register) ...<Widget>[
                            TextField(
                              controller: _nickname,
                              decoration: const InputDecoration(
                                labelText: '昵称',
                                prefixIcon: Icon(Icons.badge_outlined, size: 20),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          if (needsPassword)
                            TextField(
                              controller: _password,
                              obscureText: true,
                              onSubmitted: (_) => _submit(),
                              decoration: const InputDecoration(
                                labelText: '密码',
                                prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
                              ),
                            ),
                          if (needsCode)
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: TextField(
                                    controller: _code,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: '验证码',
                                      prefixIcon: Icon(Icons.sms_outlined, size: 20),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                GhostButton(
                                  text: _countdown > 0 ? '${_countdown}s' : '获取验证码',
                                  height: 54,
                                  onPressed: _countdown > 0 ? null : _sendCode,
                                ),
                              ],
                            ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            alignment: Alignment.topCenter,
                            child: _error == null
                                ? const SizedBox(height: 16)
                                : Container(
                                    margin: const EdgeInsets.only(top: 16),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                    decoration: BoxDecoration(
                                      color: scheme.error.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        Icon(Icons.error_outline_rounded, size: 18, color: scheme.error),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _error!,
                                            style: TextStyle(fontSize: 13, color: scheme.error),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                          PrimaryButton(
                            text: _mode == _Mode.register ? '注册并登录' : '登录',
                            onPressed: session.busy ? null : _submit,
                            busy: session.busy,
                          ),
                          const SizedBox(height: 12),
                          GhostButton(
                            text: '微信一键登录',
                            icon: Icons.chat_bubble_rounded,
                            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('微信登录接入还在路上，先用手机号')),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Center(
                            child: Text(
                              '登录即代表同意 用户协议 与 隐私政策',
                              style: TextStyle(fontSize: 11, color: AppBrand.muted),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    StaggeredIn(
                      index: 4,
                      child: Column(
                        children: <Widget>[
                          Center(
                            child: Text(
                              scope.usingMock ? '数据源：内存假数据' : '数据源：${Env.apiBase}',
                              style: const TextStyle(fontSize: 12, color: AppBrand.muted),
                            ),
                          ),
                          if (scope.usingMock)
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Center(
                                child: Text(
                                  '演示账号 13800000001 / 123456，验证码固定 123456',
                                  style: TextStyle(fontSize: 12, color: AppBrand.muted),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 自定义分段切换。滑动的黑色药丸替代 SegmentedButton 的方盒感。
  Widget _modeSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: AppBrand.cardSm,
      ),
      child: Row(
        children: <Widget>[
          for (final m in _Mode.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: _mode == m,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _mode = m;
                    _error = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: _mode == m ? AppBrand.black : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _mode == m ? FontWeight.w800 : FontWeight.w600,
                          color: _mode == m ? Colors.white : AppBrand.muted,
                        ),
                        child: Text(switch (m) {
                          _Mode.password => '密码登录',
                          _Mode.sms => '验证码',
                          _Mode.register => '注册',
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
