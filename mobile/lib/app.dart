import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_scope.dart';
import 'page/home_shell.dart';
import 'page/login_page.dart';
import 'state/activity_state.dart';
import 'state/badge_state.dart';
import 'state/buddy_state.dart';
import 'state/chat_state.dart';
import 'state/credit_log_state.dart';
import 'state/notification_state.dart';
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
        ChangeNotifierProvider<BadgeState>(
          create: (_) => BadgeState(repo: scope.badge),
        ),
        ChangeNotifierProvider<CreditLogState>(
          create: (_) => CreditLogState(repo: scope.creditLog),
        ),
        ChangeNotifierProvider<BuddyState>(
          create: (_) => BuddyState(repo: scope.buddy),
        ),
        ChangeNotifierProvider<ChatState>(
          create: (_) => ChatState(repo: scope.chat, socket: scope.socket),
        ),
        ChangeNotifierProvider<NotificationState>(
          create: (_) => NotificationState(
            repo: scope.notification,
            socket: scope.socket,
          ),
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
      // 这些值现在只作用于**没有走 AppField 的地方**（如聊天输入框、下拉框的
      // 内嵌样式）。表单输入全部走 `widget/ui.dart` 的 `AppField`——它自带聚焦
      // 过渡动画，而 theme 里的 border/fill 切换是瞬时的，做不到"点亮"的过程。
      filled: true,
      fillColor: const Color(0xFFF3F8FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBrand.rSm),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBrand.rSm),
        borderSide: const BorderSide(color: Color(0xFFDEEBF4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBrand.rSm),
        borderSide: BorderSide(color: primary, width: 1.8),
      ),
      labelStyle: const TextStyle(color: AppBrand.muted, fontSize: 14.5),
      hintStyle: const TextStyle(color: Color(0xFFAEBCC6), fontSize: 14.5),
    ),
    // 光标与文字选中色统一成品牌蓝。默认是 Material 的蓝紫，
    // 在一套天蓝设计里出现两秒紫光标，是很损质感的细节。
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppBrand.primaryDeep,
      selectionColor: Color(0x3338B2F2),
      selectionHandleColor: AppBrand.primary,
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
      // 选中态投影换成品牌蓝辉光。默认的黑色投影在天蓝底色上会显脏，
      // 且"选中"这件事本身就该用品牌色来表达——颜色、字重、辉光三者同向才整齐。
      //
      // 没有 `selectedElevation` 这个参数（`ChipThemeData` 只有 `elevation` 与
      // `pressElevation`，选中态不单独控高度），所以选中态的"浮起"感只能靠
      // 颜色与辉光表达；真要控高度，得自己画 chip（`CategoryChip` 就是那么干的）。
      shadowColor: AppBrand.primary,
      elevation: 2,
      selectedShadowColor: AppBrand.primary,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppBrand.ink,
      unselectedLabelColor: AppBrand.muted,
      labelStyle: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
      unselectedLabelStyle: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
      dividerColor: Colors.transparent,
      indicatorColor: AppBrand.primary,
      indicatorSize: TabBarIndicatorSize.label,
      // 指示器换成**胶囊滑块**而不是默认的下划线。下划线在两个状态下只是"长度变了"，
      // 且 3px 高的一条线在 420px 的浅蓝渐变背景上几乎看不见——用户会以为根本没选中。
      // 胶囊实底 + 白字是这套设计语言里已有的一等公民（chip、按钮都是胶囊），
      // 复用它可以省掉"这里为什么长这样"的解释成本。
      //
      // 用 `_PillIndicator` 而非 `BoxDecoration`：后者需要 TabBar 自己去测每个 tab 的
      // 宽度并插值，跨 tab 拖动时会出现两个胶囊中间闪一个长方形的过渡帧。
      // `TabBarIndicatorSize.label` 保持不动——它是"胶囊只包住文字"，不是撑满整格。
      indicator: _PillIndicator(),
      // 指示器滑动给 300ms + 末端过冲，与底部导航的滑块同一节奏。
      indicatorAnimation: TabIndicatorAnimation.elastic,
      splashFactory: NoSplash.splashFactory,
      overlayColor: WidgetStatePropertyAll<Color>(Colors.transparent),
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

/// TabBar 的胶囊滑块指示器。
///
/// TabBar 会自动把指示器的采样区域裁到当前 tab 的 label 宽度内（`indicatorSize: label`），
/// 位置与跨 tab 的插值也由它算好后通过 `offset` 传进来——所以这里只负责"把一个胶囊画在
/// 给定矩形里"，不碰尺寸与位置。自己算宽度的话，两端 tab 文案长度不同时（'关注' / '粉丝'
/// 与 '我发起的' / '我报名的'）会出现胶囊跟着变宽变窄的抖动。
///
/// 形状用"高度一半"当圆角半径（即胶囊），不用固定 `BorderRadius.circular(999)`：
/// 后者在指示器被压到很窄时（长文案 + 小屏）会退化成两个圆加一条线；
/// 按当前高度算半径永远是对的。
class _PillIndicator extends Decoration {
  const _PillIndicator();

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _PillPainter();

  /// 上下各留 7、左右各留 14 的余量，胶囊才不会贴住文字。
  /// 这个值直接决定"胶囊比文字大多少"，改它等于改整个 TabBar 的视觉重量。
  @override
  EdgeInsetsGeometry get padding => const EdgeInsets.symmetric(horizontal: 14, vertical: 7);
}

class _PillPainter extends BoxPainter {
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) {
      return;
    }
    // 必须叠加 offset：它是 TabBar 算好的落点。漏掉的话所有胶囊都会画在左上角。
    final rect = offset & size;
    final radius = Radius.circular(size.height / 2);
    final rrect = RRect.fromRectAndRadius(rect, radius);
    // 一圈蓝色辉光，让胶囊"浮"在浅蓝渐变背景之上而不是贴在上面。
    canvas.drawShadow(Path()..addRRect(rrect), AppBrand.primary.withValues(alpha: 0.45), 3, false);
    canvas.drawRRect(rrect, Paint()..color = AppBrand.primary);
  }
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
      final notify = context.read<NotificationState>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        chat.bindMe(me.id);
        // 通知的红点也归"登录态"管：挂在 socket 上、并在挂的时候就把未读数拉一次，
        // 否则冷启动后要先点进通知页才会看到红点。
        notify.attach();
        notify.loadUnread();
        if (token != null) {
          chat.attach(token);
        }
      });
    }

    return const HomeShell();
  }
}
