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
                          AppField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            hintText: '手机号',
                            prefixIcon: Icons.phone_iphone_rounded,
                          ),
                          const SizedBox(height: 14),
                          if (_mode == _Mode.register) ...<Widget>[
                            AppField(
                              controller: _nickname,
                              hintText: '昵称',
                              prefixIcon: Icons.badge_outlined,
                            ),
                            const SizedBox(height: 14),
                          ],
                          if (needsPassword)
                            AppField(
                              controller: _password,
                              obscureText: true,
                              hintText: '密码',
                              prefixIcon: Icons.lock_outline_rounded,
                              textInputAction: TextInputAction.go,
                              onSubmitted: (_) => _submit(),
                            ),
                          if (needsCode)
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: AppField(
                                    controller: _code,
                                    keyboardType: TextInputType.number,
                                    hintText: '验证码',
                                    prefixIcon: Icons.sms_outlined,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _CodeButton(
                                  countdown: _countdown,
                                  onSend: _sendCode,
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

/// 「获取验证码」按钮。
///
/// 刻意不复用 [GhostButton]，因为三种状态在语义上不是"可用/不可用"两档：
/// - **可点**：白底描边，右侧一个纸飞机图标，表示"发出去"；
/// - **发送中**：转圈，表示请求在路上。这一档缺了的话，弱网下用户会以为没点上而连点，
///   而后端对同一号码有频控——真正的后果是一串"操作太频繁"的报错；
/// - **倒计时**：**不是禁用态**，是"已经发出去了，在等"。所以不能画成灰掉的按钮
///   （灰按钮读起来是"这个功能坏了"）。改成浅蓝底 + 蓝色文字 + 一个逐渐收短的进度环，
///   把"还剩多久"同时用数字和环形说一遍。
///
/// 宽度**固定 116**：三档文案是「获取验证码」/「发送中」/「60s」，字数不同。
/// 不固定的话这个按钮会随秒数变化宽窄，把左边的输入框推来推去——倒计时每跳一秒，
/// 用户正在输入的手机号就横移一次，这是最烦人的一类抖动。
class _CodeButton extends StatefulWidget {
  const _CodeButton({required this.countdown, required this.onSend});

  final int countdown;
  final Future<void> Function() onSend;

  @override
  State<_CodeButton> createState() => _CodeButtonState();
}

class _CodeButtonState extends State<_CodeButton> {
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final counting = widget.countdown > 0;
    // 三档互斥：发送中 → 倒计时 → 可点。文案上 `_sending` 优先，因为"请求在路上"
    // 比"还有 58 秒"更该被看到；而配色上两者共用一套（都是"等着"）。
    final busy = _sending || counting;
    return SizedBox(
      width: 116,
      height: 54,
      child: GhostButton(
        text: _sending ? '发送中' : (counting ? '${widget.countdown}s' : '获取验证码'),
        height: 54,
        // 倒计时与发送中都传 null：点不了，也就不该有按压反馈
        // （有反馈等于承诺"点到了"，而实际上什么也不会发生）。
        // 它们**不是禁用态**——配色由下面四个覆盖口接管，不会走进灰按钮那条路。
        onPressed: busy ? null : _tap,
        icon: _sending
            ? null
            : (counting ? Icons.hourglass_bottom_rounded : Icons.send_rounded),
        iconColor: busy ? AppBrand.primaryDeep : null,
        textColor: busy ? AppBrand.primaryDeep : null,
        background: busy ? AppBrand.primarySoft.withValues(alpha: 0.45) : null,
        borderColor: busy ? AppBrand.primary.withValues(alpha: 0.35) : null,
        child: counting ? _CountdownRing(remaining: widget.countdown) : null,
      ),
    );
  }

  Future<void> _tap() async {
    setState(() => _sending = true);
    try {
      await widget.onSend();
    } finally {
      // _sendCode 内部失败时自己不抛（错误走页面上的 _error 条），所以这里一定收得到尾巴。
      // finally 而不是 try 之后：中途返回或抛异常时按钮不能卡在"发送中"。
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }
}

/// 倒计时进度环。用 [CircularProgressIndicator] 的 `value` 驱动，
/// 不给 value 就是无限转圈（那是"加载中"），给了才是"还剩这么多"。
class _CountdownRing extends StatelessWidget {
  const _CountdownRing({required this.remaining});

  final int remaining;

  /// 与 [_CodeButtonState] 之外的后端频控窗口一致：60 秒。
  static const int _window = 60;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 15,
      height: 15,
      child: CircularProgressIndicator(
        value: remaining.clamp(0, _window) / _window,
        strokeWidth: 2,
        backgroundColor: AppBrand.primary.withValues(alpha: 0.18),
        valueColor: const AlwaysStoppedAnimation<Color>(AppBrand.primary),
      ),
    );
  }
}
