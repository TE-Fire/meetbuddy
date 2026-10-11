import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_scope.dart';
import '../config/env.dart';
import '../model/api_exception.dart';
import '../state/session_state.dart';

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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Center(child: Text('🤝', style: TextStyle(fontSize: 26))),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('搭子', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                          Text('同城组局，找个搭子', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),

                  SegmentedButton<_Mode>(
                    segments: const <ButtonSegment<_Mode>>[
                      ButtonSegment<_Mode>(value: _Mode.password, label: Text('密码登录')),
                      ButtonSegment<_Mode>(value: _Mode.sms, label: Text('验证码')),
                      ButtonSegment<_Mode>(value: _Mode.register, label: Text('注册')),
                    ],
                    selected: <_Mode>{_mode},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => setState(() {
                      _mode = s.first;
                      _error = null;
                    }),
                  ),
                  const SizedBox(height: 22),

                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: '手机号',
                      prefixIcon: Icon(Icons.phone_iphone),
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (_mode == _Mode.register) ...<Widget>[
                    TextField(
                      controller: _nickname,
                      decoration: const InputDecoration(
                        labelText: '昵称',
                        prefixIcon: Icon(Icons.badge_outlined),
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
                        prefixIcon: Icon(Icons.lock_outline),
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
                              prefixIcon: Icon(Icons.sms_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 56,
                          child: OutlinedButton(
                            onPressed: _countdown > 0 ? null : _sendCode,
                            child: Text(_countdown > 0 ? '${_countdown}s' : '获取验证码'),
                          ),
                        ),
                      ],
                    ),

                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.error_outline, size: 18, color: scheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!, style: TextStyle(fontSize: 13, color: scheme.error)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: session.busy ? null : _submit,
                    child: session.busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                          )
                        : Text(_mode == _Mode.register ? '注册并登录' : '登录'),
                  ),

                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      scope.usingMock ? '数据源：内存假数据' : '数据源：${Env.apiBase}',
                      style: TextStyle(fontSize: 12, color: scheme.outline),
                    ),
                  ),
                  if (scope.usingMock)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Center(
                        child: Text(
                          '演示账号 13800000001 / 123456，验证码固定 123456',
                          style: TextStyle(fontSize: 12, color: scheme.outline),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
