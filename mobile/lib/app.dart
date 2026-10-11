import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_scope.dart';
import 'page/home_shell.dart';
import 'page/login_page.dart';
import 'state/activity_state.dart';
import 'state/chat_state.dart';
import 'state/session_state.dart';
import 'widget/ui.dart';

const Color kSeed = AppBrand.primary;

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
  const primary = AppBrand.primary;
  final scheme = ColorScheme.fromSeed(seedColor: primary).copyWith(
    primary: primary,
    secondary: AppBrand.grassDeep,
    error: const Color(0xFFEB4D5C),
    surface: Colors.white,
    onPrimary: Colors.white,
    outlineVariant: AppBrand.line,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    // 不显式写 fontFamily：引擎默认回落到 'Roboto'，而 pubspec 把 "Roboto"
    // 注册成了打包的 NotoSansSC——所有样式（包括没写字族的 const TextStyle）
    // 都落在本地字体上，不再触发 gstatic 切片下载。
    scaffoldBackgroundColor: const Color(0xFFF2F9FE),
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w900,
        color: AppBrand.ink,
        letterSpacing: -0.2,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBrand.rLg),
        side: BorderSide(color: AppBrand.line.withValues(alpha: 0.5)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF3F8FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBrand.rSm),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBrand.rSm),
        borderSide: const BorderSide(color: Color(0xFFE4EEF6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBrand.rSm),
        borderSide: BorderSide(color: primary, width: 1.7),
      ),
      labelStyle: const TextStyle(color: AppBrand.muted, fontSize: 14.5),
      hintStyle: const TextStyle(color: Color(0xFFB9C6D0), fontSize: 14.5),
    ),
    // 主按钮在全局就是黑胶囊：弹窗确认、报名、发布都统一。
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppBrand.black,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        elevation: 0,
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppBrand.ink,
        backgroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        side: const BorderSide(color: AppBrand.line, width: 1.5),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppBrand.primaryDeep,
        textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: AppBrand.primary,
      side: BorderSide(color: AppBrand.line, width: 1.5),
      shape: StadiumBorder(),
      showCheckmark: false,
      labelPadding: EdgeInsets.symmetric(horizontal: 12),
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 9),
      labelStyle: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppBrand.ink2),
      secondaryLabelStyle: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppBrand.ink,
      unselectedLabelColor: AppBrand.muted,
      labelStyle: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
      unselectedLabelStyle: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
      dividerColor: Colors.transparent,
      indicatorColor: AppBrand.primary,
      indicatorSize: TabBarIndicatorSize.label,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppBrand.black,
      contentTextStyle: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      elevation: 0,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppBrand.primary,
      linearTrackColor: Color(0xFFEDF4F9),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppBrand.primary,
      inactiveTrackColor: Color(0xFFE1EDF5),
      thumbColor: Colors.white,
      trackHeight: 5,
      thumbShape: RoundSliderThumbShape(elevation: 3, enabledThumbRadius: 10),
      overlayColor: Color(0x1E38B2F2),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBrand.rLg)),
      titleTextStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppBrand.ink),
      contentTextStyle: const TextStyle(fontSize: 14, height: 1.6, color: AppBrand.ink2),
    ),
    dividerTheme: const DividerThemeData(space: 1, thickness: 1, color: AppBrand.line),
    pageTransitionsTheme: PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        for (final p in TargetPlatform.values) p: const _SlideFadeBuilder(),
      },
    ),
  );
}

/// 全局页面转场：淡入 + 轻微上滑 + 缩放，替代系统默认的水平推入。
class _SlideFadeBuilder extends PageTransitionsBuilder {
  const _SlideFadeBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.035), end: Offset.zero).animate(curved),
        child: ScaleTransition(
          scale: Tween(begin: 0.98, end: 1.0).animate(curved),
          child: child,
        ),
      ),
    );
  }
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
