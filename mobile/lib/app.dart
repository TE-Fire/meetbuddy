import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_scope.dart';
import 'page/home_shell.dart';
import 'page/login_page.dart';
import 'state/activity_state.dart';
import 'state/chat_state.dart';
import 'state/session_state.dart';

const Color kSeed = Color(0xFF2E6BE6);

class MeetbuddyApp extends StatelessWidget {
  const MeetbuddyApp({super.key, required this.scope});

  final AppScope scope;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppScope>.value(value: scope),
        ChangeNotifierProvider<SessionState>(
          create: (_) => SessionState(
            auth: scope.auth,
            user: scope.user,
            api: scope.api,
            socket: scope.socket,
          )..restore(),
        ),
        ChangeNotifierProvider<ActivityState>(
          create: (_) => ActivityState(activity: scope.activity, user: scope.user),
        ),
        ChangeNotifierProvider<ChatState>(
          create: (_) => ChatState(repo: scope.chat, socket: scope.socket),
        ),
      ],
      child: MaterialApp(
        title: '搭子 · Meetbuddy',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const _RootGate(),
      ),
    );
  }
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: kSeed);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF6F7FB),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFFF6F7FB),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerTheme: const DividerThemeData(space: 1, thickness: 1),
  );
}

/// 登录门卫 + 长连接绑定。
///
/// 这里是全 App 唯一知道"登录态变了要重连 WebSocket"的地方，
/// 放在页面里做的话，每个页面都得重复一遍这段逻辑。
class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  int? _attachedUserId;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();

    if (session.restoring) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!session.loggedIn) {
      _attachedUserId = null;
      return const LoginPage();
    }

    final me = session.me!;
    if (_attachedUserId != me.id) {
      _attachedUserId = me.id;
      final token = session.accessToken;
      final chat = context.read<ChatState>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        chat.bindMe(me.id);
        if (token != null) {
          chat.attach(token);
        }
      });
    }

    return const HomeShell();
  }
}
