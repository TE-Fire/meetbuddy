import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/env.dart';

/// 视觉基元与动效原语。
///
/// 设计语言参照「圆周旅迹」：天空蓝品牌色 + 草地绿辅色 + 黑色胶囊主按钮 +
/// 淡蓝天空渐变底 + 大圆角白卡 + 地图化插画（草地形 / 蓝色虚线路线 / 白色图钉）。
/// 所有颜色、圆角、阴影、插画都收敛在这里，页面里不再散落手写的 Color(0x...)。
class AppBrand {
  AppBrand._();

  /// 品牌天空蓝。主按钮已改为黑胶囊，这里的蓝用于强调、进度、气泡与插画。
  static const Color primary = Color(0xFF38B2F2);
  static const Color primaryDeep = Color(0xFF189BE0);
  static const Color primarySoft = Color(0xFFE1F4FE);

  /// 草地绿：地图插画的"地面"，也用作正向状态与次强调。
  static const Color grass = Color(0xFFC4ECA6);
  static const Color grassDeep = Color(0xFF7CC96B);
  static const Color grassSoft = Color(0xFFEFF9E8);

  /// 路线蓝（虚线导航线）。
  static const Color route = Color(0xFF4FC3F7);

  /// 主按钮黑。
  static const Color black = Color(0xFF171A1D);

  /// 兼容旧命名：非品牌渐变场景下的"第二色"。
  static const Color secondary = grassDeep;

  /// 强提醒（未读徽标）。
  static const Color hot = Color(0xFFFF5B7A);

  static const Color ink = Color(0xFF182028);
  static const Color ink2 = Color(0xFF3C4A56);
  static const Color muted = Color(0xFF93A1AD);
  static const Color line = Color(0xFFE4EEF6);
  static const Color bg = Color(0xFFF4FAFF);

  /// 天空底色（页面顶部到底部）。
  static const Color skyTop = Color(0xFFDDF0FC);
  static const Color skyBottom = Color(0xFFF4FAFF);

  /// 品牌渐变：天空蓝的两端，用于自身气泡、头像底、渐变插画。
  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF59BCF5), primaryDeep],
  );

  static const LinearGradient sky = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[skyTop, skyBottom],
  );

  /// 卡片弥散阴影（大而柔，是这套风格"有质感"的主要来源）。
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(color: Color(0x141F6696), blurRadius: 34, offset: Offset(0, 14)),
  ];
  static const List<BoxShadow> cardSm = <BoxShadow>[
    BoxShadow(color: Color(0x121F6696), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const List<BoxShadow> shadowSm = cardSm;

  /// 天空蓝投影（渐变按钮 / FAB / 强调元素）。
  static const List<BoxShadow> glow = <BoxShadow>[
    BoxShadow(color: Color(0x3D38B2F2), blurRadius: 20, offset: Offset(0, 9)),
  ];

  /// 黑胶囊按钮的投影。
  static const List<BoxShadow> inkGlow = <BoxShadow>[
    BoxShadow(color: Color(0x33171A1D), blurRadius: 22, offset: Offset(0, 10)),
  ];

  /// 圆角梯级。
  static const double rLg = 26;
  static const double rMd = 20;
  static const double rSm = 14;
}

/// 天空渐变底：淡蓝天 → 近白，右上角一抹草地绿。页面根部铺一层就有"空气感"。
class SkyBackground extends StatelessWidget {
  const SkyBackground({super.key, required this.child, this.height});

  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: height ?? 420,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[AppBrand.skyTop, Color(0x00F4FAFF)],
              ),
            ),
          ),
        ),
        Positioned(
          right: -70,
          top: -60,
          child: Blob(size: 200, color: AppBrand.grass.withValues(alpha: 0.34)),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

/// 按压缩放反馈。可点卡片套一层，替代生硬的"点了没反应"。
///
/// 两点容易踩的：
/// ① 手势回调是按帧触发的，`onTapDown` 里必须判断状态有没有真的变——只在第一次
///    按下时 setState，否则按住不动会每帧重建一次子树。
/// ② 缩放要**带上投影一起缩**。只缩内容的话，卡片边缘在缩放的一瞬间会露出底下的
///    阴影，放大到 0.97 的位移在浅色底上看得出来（是"抖"而不是"按下去"）。
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
    this.blur = 12,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// 按下的缩放比。0.97 适合整卡，0.94 适合小圆钮（大卡缩太多会显得在飞）。
  final double scale;

  /// 按下时投影的模糊半径，默认略小于常态，制造"压近桌面"的感觉。
  final double blur;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) {
      setState(() => _down = v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final inner = AnimatedScale(
      // 按下 110ms 快、回弹 220ms 慢：和弹簧的"快压慢回"一致，
      // 两边同速的话会像在匀速放大一个图标，是最典型的"僵"。
      scale: _down ? widget.scale : 1.0,
      duration: Duration(milliseconds: _down ? 110 : 220),
      curve: _down ? Curves.easeOut : Curves.easeOutBack,
      child: widget.child,
    );
    return GestureDetector(
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap,
      // 整层再叠一层极轻微的压暗。只靠缩放，浅色卡片上几乎看不出"按下去了"；
      // 补一层 3% 的暗度，按下这一下的"重量"才成立（macOS 的按钮用就是这个手法）。
      child: AnimatedOpacity(
        opacity: _down ? 0.94 : 1,
        duration: Duration(milliseconds: _down ? 90 : 240),
        child: inner,
      ),
    );
  }
}

/// 弹一下：点"收藏"这类**状态翻转**的图标用。
///
/// 与 [PressableScale] 的分工是语义上的：那个表示"按住了"，这个表示"变了"。
/// 收藏这种不可逆的确认动作需要有一下明确的"叮"，不然点完只换了个图标形状，
/// 用户会怀疑到底点上没有。
class BouncyTap extends StatefulWidget {
  const BouncyTap({super.key, required this.child, this.onTap, this.enabled = true});

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<BouncyTap> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  /// 0 → 0.18 → -0.06 → 0 的过冲曲线（`Curves.elasticOut` 太夸张，收不住）。
  late final Animation<double> _bang = TweenSequence<double>(<TweenSequenceItem<double>>[
    TweenSequenceItem(tween: Tween<double>(begin: 1, end: 1.18).chain(CurveTween(curve: Curves.easeOut)), weight: 28),
    TweenSequenceItem(tween: Tween<double>(begin: 1.18, end: 0.94).chain(CurveTween(curve: Curves.easeInOut)), weight: 34),
    TweenSequenceItem(tween: Tween<double>(begin: 0.94, end: 1).chain(CurveTween(curve: Curves.easeOut)), weight: 38),
  ]).animate(_c);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.enabled && widget.onTap != null;
    return GestureDetector(
      onTap: on
          ? () {
              _c.forward(from: 0);
              widget.onTap!();
            }
          : null,
      child: ScaleTransition(scale: _bang, child: widget.child),
    );
  }
}

/// 列表入场动画：按 index 逐个延迟，淡入 + 上浮。
///
/// 延迟刻意压得很短（38ms/项，最多 6 项），总时长控制在 600ms 内——
/// 入场是"看到的代价"，不是演出。之前 55ms/项、上限 10 项，第 10 行要等 550ms
/// 才开始动，滑动时会有"内容在后面追手指"的拖沓感。
class StaggeredIn extends StatelessWidget {
  const StaggeredIn({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delay = (index > 6 ? 6 : index) * 38;
    final total = 300 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 10 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

/// 黑胶囊主按钮——这套设计语言的招牌。
/// 禁用时整体变灰；busy 时转圈并保持高度不跳。
///
/// 按下反馈**不套 [PressableScale]**：这颗按钮宽近满屏、高 54，整块缩放会让左右边缘
/// 来回缩进，像条橡皮筋；改为内部按压缩并叠高光（见 [_BouncyButtonBody]），
/// "按下去了"由内往外传，视觉重量才落在手指底下。
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.busy = false,
    this.height = 54,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool busy;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      child: _BouncyButtonBody(
        enabled: enabled,
        onPressed: onPressed,
        height: height,
        // 材质走 [_darkFace]（上 #2E353C 下 #14171A + 顶部受光边）。
        // 下面两个纯色只在**禁用**时用：渐变按钮置灰时会有"灰得有层次"的怪感，
        // 禁用态就该是一块平的、明确没有质地的颜色。
        face: enabled ? _darkFace : null,
        pressedColor: enabled ? const Color(0xFF3A4249) : const Color(0xFFC7D0D8),
        baseColor: enabled ? AppBrand.black : const Color(0xFFC7D0D8),
        radius: BorderRadius.circular(999),
        glow: enabled ? AppBrand.inkGlow : null,
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
              )
            : Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
      ),
    );
  }
}

/// 白描边胶囊次按钮。
///
/// 与主按钮共用 [_BouncyButtonBody]，所以按下时的"压下去"手感两端一致——
/// 同一屏里主次按钮反馈量不同，用户会觉得其中一颗是坏的。
///
/// 配色留了覆盖口（`background` / `borderColor` / `textColor` / `iconColor`）：默认是白底黑字，
/// 但"倒计时中"这类**非禁用、非正常**的中间态需要第三种配色，而它不该被硬编码进这个通用组件。
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.child,
    this.height = 54,
    this.background,
    this.borderColor,
    this.textColor,
    this.iconColor,
    this.pressedBackground,
  });

  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// 附在文字之后的自定义部件（如验证码的倒计时环）。
  /// 用 `child` 而不是把倒计时环写进 GhostButton：这个组件被 7 处复用，
  /// 塞任何一处专属的东西进去，其余 6 处都要背这个参数。
  final Widget? child;

  final double height;
  final Color? background;
  final Color? borderColor;
  final Color? textColor;
  final Color? iconColor;

  /// 按下时的底色。**必须是不透明的实色**：早先这里用 `background.withValues(alpha: 0.78)`
  /// 从底色推，结果浅蓝底（#E1F4FE）推出来的合成值比原色还浅，按下时底色等于消失，
  /// 看着像按钮被抠掉了一块。浅色系的"更深一档"只能靠换色，不能靠调透明度。
  final Color? pressedBackground;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    // 三个覆盖色一旦给出，就**不再**按 enabled 回落成灰。
    // 这是让"倒计时"这类中间态能复用本组件的关键：它 onPressed 是 null（点不了、
    // 也不该有按压反馈），但配色必须自己说了算——否则会被当成"功能坏了"的灰按钮。
    final fg = textColor ?? (enabled ? AppBrand.ink : AppBrand.muted);
    final base = background ?? Colors.white;
    return Semantics(
      button: true,
      enabled: enabled,
      child: _BouncyButtonBody(
        enabled: enabled,
        onPressed: onPressed,
        height: height,
        // 白底按钮同样要材质。纯白是最难有质感的颜色——它没有层次可言，
        // 加一条 3 个色阶的竖向渐变（白 → #F6FAFD）就有了"这是一张纸而不是一个色块"。
        // 覆盖口给出的自定义底色一律走纯色（face 为 null），中间态不参与材质。
        face: background == null && borderColor == null ? _lightFace : null,
        baseColor: base,
        // 白底按钮不能靠变暗表示按下——白再暗也是白。改成填一层极浅的品牌蓝，
        // 同时边框转蓝，按下的"确认感"来自颜色而不是亮度。
        pressedColor: pressedBackground ?? const Color(0xFFD3EDFC),
        radius: BorderRadius.circular(999),
        border: Border.all(color: borderColor ?? AppBrand.line, width: 1.5),
        pressedBorder: Border.all(
          color: AppBrand.primary.withValues(alpha: 0.55),
          width: 1.5,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 18, color: iconColor ?? (enabled ? AppBrand.ink : AppBrand.muted)),
              const SizedBox(width: 7),
            ],
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: fg),
            ),
            if (child != null) ...<Widget>[
              const SizedBox(width: 7),
              child!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 胶囊按钮的按下反馈本体。主/次按钮共用，保证两者"呼吸"节奏一致。
///
/// 三件事同时动，缺一件都会显得僵：
/// ① **缩放 0.965**（比整卡的 0.97 略深）——胶囊横向长，缩太少看不出来；
/// ② **底色/边框过渡 90ms 压下 / 200ms 回弹**——快压慢回，和 [PressableScale] 同一套节奏；
/// ③ **按下时投影收掉**——真正"贴近桌面"的是影子，只缩不缩影，按钮会像浮在原地缩小。
///
/// 渐变参数见 [_ButtonFace]：按下与常态走**两套渐变**而不是两套纯色。
/// 纯色平涂的按钮无论加多少动画都是"一块色块在动"；有了从亮到暗的微弱渐变
/// 和顶部一条受光边，它才变成一个**有厚度的实体**，按压时是"压进一个东西里"。
class _BouncyButtonBody extends StatefulWidget {
  const _BouncyButtonBody({
    required this.enabled,
    required this.onPressed,
    required this.height,
    required this.baseColor,
    required this.pressedColor,
    required this.radius,
    required this.child,
    this.glow,
    this.border,
    this.pressedBorder,
    this.face,
  });

  final bool enabled;
  final VoidCallback? onPressed;
  final double height;
  final Color baseColor;
  final Color pressedColor;
  final BorderRadius radius;
  final Widget child;
  final List<BoxShadow>? glow;
  final BoxBorder? border;
  final BoxBorder? pressedBorder;

  /// 按钮的"材质"。传 null 表示纯色（覆盖口用的中间态走这条）。
  /// 见 [_ButtonFace]：常态与按下各自一条渐变。
  final _ButtonFace? face;

  @override
  State<_BouncyButtonBody> createState() => _BouncyButtonBodyState();
}

/// 按钮表面的材质定义：常态与按下各一条竖向渐变。
///
/// 为什么要渐变：**纯色没有方向信息**。`#171A1D` 涂满一个胶囊，它是一块平面；
/// 而从 `#2E353C` 渐到 `#14171A`，上亮下暗，它立刻有了"受光面"和"厚度"——
/// 这正是真实按钮、真机 UI 与"设计稿截图"的差别。代价只有一次 `LinearGradient`。
///
/// 两条渐变的明度差刻意压得很小（黑底 10 个色阶、白底 3 个色阶）：
/// 差大了会变成"渐变按钮"这种上个十年的风格，且在小尺寸上出现色带。
/// 这一档是"看得出有层次、但说不出哪来的"程度。
class _ButtonFace {
  const _ButtonFace({required this.idle, required this.pressed, this.sheen = true});

  /// 常态渐变。`[0]` 为顶部色，`[1]` 为底部色。
  final List<Color> idle;

  /// 按下时的渐变。通常整条压暗一档，方向不变。
  final List<Color> pressed;

  /// 顶部是否画一条 1px 受光边。深色按钮开（模拟高光），浅色按钮可关。
  final bool sheen;
}

/// 深色胶囊的材质：上 `#2E353C` 下 `#14171A`，顶部一条 16% 白的高光线。
/// 按下时整条压暗到 `#242A30` → `#0E1113`——同时把渐变方向稍微"反转"的错觉
/// 是靠压暗实现的，不做真的方向反转（反转会让按钮像被翻过来）。
const _ButtonFace _darkFace = _ButtonFace(
  idle: <Color>[Color(0xFF2E353C), Color(0xFF14171A)],
  pressed: <Color>[Color(0xFF242A30), Color(0xFF0E1113)],
);

/// 白色胶囊的材质：上纯白下 `#F6FAFD`。差 3 个色阶，刚刚好。
/// 顶部高光关闭——白底加白线看不见，反而会糊掉边框。
const _ButtonFace _lightFace = _ButtonFace(
  idle: <Color>[Color(0xFFFFFFFF), Color(0xFFF6FAFD)],
  pressed: <Color>[Color(0xFFF2F8FC), Color(0xFFE6F1F9)],
  sheen: false,
);

class _BouncyButtonBodyState extends State<_BouncyButtonBody> {
  bool _down = false;

  void _set(bool v) {
    // 和 PressableScale 同一条：onTapDown 在按住期间可能每帧回调，必须判等。
    if (_down != v && mounted) {
      setState(() => _down = v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.enabled;
    final pressed = _down && on;
    final face = widget.face;
    final colors = face == null
        ? null
        : (pressed ? face.pressed : face.idle);
    return GestureDetector(
      onTapDown: on ? (_) => _set(true) : null,
      onTapUp: on ? (_) => _set(false) : null,
      onTapCancel: on ? () => _set(false) : null,
      onTap: on ? widget.onPressed : null,
      child: AnimatedScale(
        scale: pressed ? 0.965 : 1,
        duration: Duration(milliseconds: pressed ? 90 : 200),
        curve: pressed ? Curves.easeOut : Curves.easeOutBack,
        child: AnimatedContainer(
          duration: Duration(milliseconds: pressed ? 90 : 200),
          curve: Curves.easeOut,
          height: widget.height,
          alignment: Alignment.center,
          // 有材质时用渐变，没有（中间态覆盖口）时退回纯色。
          // 渐变与纯色之间 `BoxDecoration.lerp` 是能插值的，中间帧是两条渐变的混合。
          decoration: BoxDecoration(
            color: colors == null ? (pressed ? widget.pressedColor : widget.baseColor) : null,
            gradient: colors == null
                ? null
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: colors,
                  ),
            borderRadius: widget.radius,
            border: pressed ? (widget.pressedBorder ?? widget.border) : widget.border,
            // 按下时影子不置 null 而**缩到同色零位移**。`BoxDecoration.lerp` 对
            // `null` 与 `List<BoxShadow>` 之间是不插值的：给 null 会让 90ms 的过渡里
            // 影子在某一帧整个消失——看起来不是"按下去"，是"闪了一下"。
            // 同色、零位移、小半径，视觉上等同于没有，但插值能一路算过去。
            boxShadow: pressed && widget.glow != null
                ? widget.glow!.map((s) => s.copyWith(blurRadius: 0, offset: Offset.zero, spreadRadius: 0)).toList()
                : widget.glow,
          ),
          // 顶部受光边：一条 1px 的半透明白线，压在渐变最上方。
          // 深色按钮必须有——没有它，渐变只是"上亮下暗的一块"；
          // 有了它，那条亮边就是"这个面的上缘被光照到了"，厚度才成立。
          // 用 Stack 而不是 border：border 会同时画在四条边上，而受光只来自上方。
          child: face != null && face.sheen
              ? Stack(
                  children: <Widget>[
                    Positioned.fill(child: widget.child),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: Container(
                        height: 1,
                        margin: EdgeInsets.symmetric(horizontal: widget.radius.topLeft.x * 0.55),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              Colors.white.withValues(alpha: 0.02),
                              Colors.white.withValues(alpha: 0.16),
                              Colors.white.withValues(alpha: 0.02),
                            ],
                            stops: const <double>[0, 0.5, 1],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : widget.child,
        ),
      ),
    );
  }
}

/// 带聚焦过渡的输入框。**所有表单输入都走它**，不要直接用 `TextField`。
///
/// 为什么要包一层而不是靠 `inputDecorationTheme`：Flutter 的 `InputDecorator` 在
/// focus 变化时是**瞬时重建**的——border 与 fillColor 直接跳变，没有过渡。
/// 而"被点亮"的质感恰恰来自这个过程：填充从灰蓝褪成白、边框转蓝并加粗、
/// 图标跟着变色、外圈浮起一层蓝光。四件事同步走 180ms，输入框才像一个**活的表面**，
/// 而不是一块贴上去的灰板。theme 里改多少颜色都做不到这件事。
///
/// 实现上把 `TextField` 剥到只剩文字（`border: InputBorder.none` + `filled: false`），
/// 背景、边框、光晕、padding 全部由外层的 `AnimatedContainer` 画。
/// 内外的 padding 只留一处（外层的 `_contentPadding`），否则会叠加成双倍内边距。
///
/// **字段名用 `hintText` 而不是 `labelText`，这是刻意的。** Flutter 的 floating label
/// 在 focus / 有内容时会上浮到 border 的位置，而这个组件的 border 是自己画的
/// （TextField 那层是 `InputBorder.none`）——label 上浮后会画在容器顶缘，
/// 跟自己的边框重叠、甚至溢出到 padding 外。项目里的表单都只有三四个字段，
/// 不需要靠浮动标签省空间，常驻提示反而更稳。
class AppField extends StatefulWidget {
  const AppField({
    super.key,
    required this.controller,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.maxLength,
    this.counterText = '',
    this.onSubmitted,
    this.validator,
    this.enabled = true,
    this.autofocus = false,
    this.textInputAction,
    this.radius = AppBrand.rSm,
  });

  final TextEditingController controller;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int maxLines;
  final int? maxLength;
  final String counterText;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final bool enabled;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final double radius;

  @override
  State<AppField> createState() => _AppFieldState();
}

class _AppFieldState extends State<AppField> {
  // 自己建 FocusNode 而不是透传：调用方都不需要编程聚焦，
  // 而这个 node 是"视觉动画的唯一真相"——它和 TextField 的真实 focus 必须是同一个，
  // 否则会出现"框亮了但光标没进去"。
  late final FocusNode _focus = FocusNode();

  /// 校验失败的文字。由内部 TextFormField 的 validator 回填。
  /// 边框要跟着变红，所以外层必须知道校验结果——而 validator 的返回值只有
  /// TextFormField 自己收得到，只能在这里用 `autovalidateMode` +
  /// 一个不干活的 FormState 间接拿到。
  ///
  /// 用 `GlobalKey<FormFieldState>` 而不是把 validator 结果往外传：
  /// 调用方（如 `_EditProfileSheet`）已经在用 Form 之外的裸字段，
  /// 要求它们各自维护一个错误状态会把校验逻辑摊到每个页面里。
  final GlobalKey<FormFieldState> _fieldKey = GlobalKey<FormFieldState>();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    super.dispose();
  }

  void _onFocusChanged() => setState(() {});

  bool get _on => _focus.hasFocus;

  bool get _invalid {
    // hasError 只有在**真的校验过**之后才有意义。没触发过校验时它恒为 false，
    // 所以空字段刚进页面不会一片红。
    return _fieldKey.currentState?.hasError ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.enabled && _on;
    final bad = widget.enabled && _invalid;
    // 禁用态单独一条配色线：不参与 focus 动画，也不显示光标，
    // 否则"置灰了但还能点进去打字"会让人以为系统坏了。
    const disabledFill = Color(0xFFEDF1F5);
    const disabledLine = Color(0xFFDCE5EC);
    const idleFill = Color(0xFFF3F8FC);
    const idleLine = Color(0xFFDEEBF4);
    // 错误态用「淡粉底 + 玫红边」，不用纯红 #F44336：
    // 这套设计的底色是天蓝，纯红在里面像贴上去的警示条，跟整体不融洽。
    // 玫红（与 AppBrand.hot 同色相）压深一档，既看得见又不破坏色调。
    const errorFill = Color(0xFFFEF4F6);
    const errorLine = AppBrand.hot;

    // 外层 Column：输入框本体 + 下方的错误行。
    // 错误文字刻意渲染在**外面**而不是让 TextFormField 自己显示——内部那行会被
    // contentPadding 与 maxLines 搅乱高度，且配色跟自绘的边框不同源。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: !widget.enabled
                ? disabledFill
                : (bad ? errorFill : (on ? Colors.white : idleFill)),
            borderRadius: BorderRadius.circular(widget.radius),
            // 常态边框刻意用 #DEEBF4 而不是主题里的 #E4EEF6：填充是 #F3F8FC，
            // 两者只差 0x0F——等于没有边框，输入框看起来是一坨平灰块。
            // 压深一档后轮廓才立得住，又不会抢过聚焦态的蓝。
            border: Border.all(
              color: !widget.enabled
                  ? disabledLine
                  : (bad ? errorLine : (on ? AppBrand.primary : idleLine)),
              width: on || bad ? 1.8 : 1.5,
            ),
            // 聚焦与错误都用外圈光晕，只是颜色不同。两者同时出现时错误优先——
            // 正在改的字段不该用蓝光盖住"这里有问题"。
            boxShadow: bad
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppBrand.hot.withValues(alpha: 0.16),
                      blurRadius: 8,
                      offset: Offset.zero,
                    ),
                  ]
                : (on
                    ? <BoxShadow>[
                        // 聚焦时外圈浮起一层 8px 蓝光，浓度 14%。
                        // 这是"点亮"最廉价也最有效的一笔——只靠边框变色，
                        // 在浅蓝渐变背景上会被背景吃掉。
                        BoxShadow(
                          color: AppBrand.primary.withValues(alpha: 0.14),
                          blurRadius: 8,
                          spreadRadius: 0,
                          offset: Offset.zero,
                        ),
                      ]
                    : null),
          ),
          child: Row(
            crossAxisAlignment: widget.maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: <Widget>[
              if (widget.prefixIcon != null) ...<Widget>[
                // 图标颜色跟着 focus 走，180ms 插值。瞬时切换也可以接受，
                // 但插值让"聚焦"这件事有了一个可以感知的过程，而不是闪一下。
                TweenAnimationBuilder<Color?>(
                  tween: ColorTween(
                    end: on ? AppBrand.primaryDeep : (widget.enabled ? AppBrand.muted : const Color(0xFFB6C1CA)),
                  ),
                  duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              builder: (context, color, _) => Icon(widget.prefixIcon, size: 20, color: color),
            ),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: TextFormField(
              key: _fieldKey,
              controller: widget.controller,
              focusNode: _focus,
              enabled: widget.enabled,
              autofocus: widget.autofocus,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              maxLines: widget.maxLines,
              maxLength: widget.maxLength,
              textInputAction: widget.textInputAction,
              onFieldSubmitted: widget.onSubmitted,
              validator: widget.validator,
              cursorColor: AppBrand.primaryDeep,
              // 光标与选中色统一成品牌蓝。默认是 Material 的蓝紫，
              // 在一套天蓝设计里出现两秒紫光标，是很损质感的细节。
              selectionControls: MaterialTextSelectionControls(),
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                height: 1.25,
                color: widget.enabled ? AppBrand.ink : AppBrand.muted,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText,
                counterText: widget.counterText,
                isDense: true,
                filled: false,
                // 这六行是整套方案的前提：把 TextField 自己的边框和背景全部关掉，
                // 只留文字。漏一个就会看到两层边框叠在一起。
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                // 错误文字由外层渲染（见下面 `_errorLine`），这里必须压掉。
                // 不设的话它会在输入框内部占一行，把整框撑高、且配色与边框不同源。
                errorStyle: const TextStyle(height: 0, fontSize: 0, color: Colors.transparent),
                errorMaxLines: 1,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
                // 多行时上下留多一点，光标在第一行中间而不是贴边。
                hintStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFAEBCC6),
                ),
              ),
            ),
          ),
          if (widget.suffixIcon != null) ...<Widget>[
            const SizedBox(width: 8),
            widget.suffixIcon!,
          ],
            ],
          ),
        ),
        // 错误行：跟着 FormFieldState 走，不自己维护错误状态——两份必然不一致。
        // 放在输入框下方而不是让 TextFormField 内部显示：内部那行会被
        // contentPadding 与 maxLines 搅乱高度，且配色跟自绘边框不同源。
        _ErrorLine(state: _fieldKey.currentState),
      ],
    );
  }
}

/// 跟着 FormFieldState 走的错误文字。校验结果变化时才重建，
/// 不自己维护一份错误状态——两份状态必然不一致。
class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.state});

  final FormFieldState<Object?>? state;

  @override
  Widget build(BuildContext context) {
    final text = state?.errorText;
    if (text == null || text.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 14, top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline_rounded, size: 14, color: AppBrand.hot),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: AppBrand.hot,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 大标题：黑粗体 + 关键词品牌蓝高亮，副标题小灰字。
/// 引导页与各区首屏的标题都走它，保证"两行式"读感一致。
class DisplayHeading extends StatelessWidget {
  const DisplayHeading({
    super.key,
    required this.lead,
    this.highlight = '',
    this.subtitle,
    this.size = 26,
    this.align = TextAlign.center,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final String lead;
  final String highlight;
  final String? subtitle;
  final double size;
  final TextAlign align;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: <Widget>[
        RichText(
          textAlign: align,
          text: TextSpan(
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w900,
              height: 1.32,
              letterSpacing: 0.3,
              color: AppBrand.ink,
            ),
            children: <TextSpan>[
              TextSpan(text: lead),
              if (highlight.isNotEmpty)
                TextSpan(text: highlight, style: const TextStyle(color: AppBrand.primary)),
            ],
          ),
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            textAlign: align,
            style: const TextStyle(fontSize: 12.5, color: AppBrand.muted, letterSpacing: 0.6),
          ),
        ],
      ],
    );
  }
}

/// 黑色小标签（封面左上角的"今天 19:30"这类）。
class InkTag extends StatelessWidget {
  const InkTag(this.text, {super.key, this.color = AppBrand.black, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        boxShadow: AppBrand.cardSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 12, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// 信息软标签：浅底 + 深字，用于"📍浦东 · 滨江步道""免费"这类元信息。
class SoftTag extends StatelessWidget {
  const SoftTag(this.text, {super.key, this.tone = SoftTagTone.sky, this.icon});

  final String text;
  final SoftTagTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      SoftTagTone.sky => (AppBrand.primarySoft, AppBrand.primaryDeep),
      SoftTagTone.grass => (AppBrand.grassSoft, const Color(0xFF4E8F3C)),
      SoftTagTone.warm => (const Color(0xFFFFF3E8), const Color(0xFFC77A2A)),
      SoftTagTone.plain => (const Color(0xFFF1F5F8), AppBrand.ink2),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 3),
          ],
          Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

enum SoftTagTone { sky, grass, warm, plain }

/// 名额进度条：细蓝圆角条 + 右侧计数。
class ProgressCap extends StatelessWidget {
  const ProgressCap({
    super.key,
    required this.current,
    required this.max,
    this.showText = true,
  });

  final int current;
  final int max;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final ratio = max <= 0 ? 0.0 : (current / max).clamp(0.0, 1.0);
    final full = current >= max;
    return Row(
      children: <Widget>[
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: ratio),
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutCubic,
              builder: (context, t, _) => LinearProgressIndicator(
                value: t,
                minHeight: 7,
                backgroundColor: const Color(0xFFEDF4F9),
                valueColor: AlwaysStoppedAnimation<Color>(
                  full ? const Color(0xFFB26A00) : AppBrand.primary,
                ),
              ),
            ),
          ),
        ),
        if (showText) ...<Widget>[
          const SizedBox(width: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              '$current/$max 人',
              key: ValueKey<int>(current),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: full ? const Color(0xFFB26A00) : AppBrand.primaryDeep,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 头像堆叠：报名成员摘要。
/// 未读徽标超过 99 显示 99+。
///
/// 放在这里而不是某个页面里：底部导航、消息页铃铛、通知列表三处都要画角标，
/// 三份各自的截断规则迟早会不一致（一处 99+、一处 100+）。
String bucketBadge(int n) => n > 99 ? '99+' : '$n';

/// 头像外形：资料卡用圆角方，列表/药丸里用正圆。
enum UserAvatarShape { rounded, circle }

/// 用户头像：有图用图，无图或加载失败回落首字母渐变底。
///
/// 归一化（相对路径拼 `apiBase`、绝对地址原样返回）只在这里做一次。以前每个
/// 展示点各写一遍"是不是 http 开头"，漏一处就在真机上留一个破图；把 `Env.imgUrl`
/// 收进组件后，调用方直接把后端返回的 `avatar` 原样传进来即可。
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.nickname,
    this.avatar,
    this.size = 42,
    this.shape = UserAvatarShape.rounded,
    this.glow = false,
  });

  final String nickname;

  /// 后端原样返回的 avatar：可能是相对路径、绝对地址或空。
  final String? avatar;
  final double size;
  final UserAvatarShape shape;

  /// 资料页那种要"浮起来"的头像才开投影，列表里不开。
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final url = Env.imgUrl(avatar);
    final first = nickname.isEmpty ? '?' : nickname.characters.first;
    final circle = shape == UserAvatarShape.circle;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: url == null ? AppBrand.brand : null,
        color: url == null ? null : const Color(0xFFEAF3FA),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(size * 0.35),
        boxShadow: glow ? AppBrand.glow : null,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: url == null
          ? _letter(first, Colors.white)
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _letter(first, AppBrand.primaryDeep),
            ),
    );
  }

  Widget _letter(String first, Color color) => Text(
        first,
        style: TextStyle(fontSize: size * 0.42, color: color, fontWeight: FontWeight.w900),
      );
}

class AvatarStack extends StatelessWidget {
  const AvatarStack({super.key, required this.names, this.size = 26, this.max = 4});

  final List<String> names;
  final double size;
  final int max;

  static const List<Color> _palette = <Color>[
    Color(0xFFFF9F6B),
    Color(0xFF6BC5FF),
    Color(0xFF7CC96B),
    Color(0xFFB79CFF),
    Color(0xFFFF8FB1),
  ];

  @override
  Widget build(BuildContext context) {
    final shown = names.take(max).toList();
    final rest = names.length - shown.length;
    return SizedBox(
      height: size,
      width: size + (shown.length + (rest > 0 ? 1 : 0) - 1).clamp(0, 99) * (size - 8),
      child: Stack(
        children: <Widget>[
          for (int i = 0; i < shown.length; i++)
            Positioned(
              left: i * (size - 8),
              child: _circle(
                shown[i],
                AppBrand.primary,
                _palette[i % _palette.length],
              ),
            ),
          if (rest > 0)
            Positioned(
              left: shown.length * (size - 8),
              child: _circle('+$rest', AppBrand.muted, const Color(0xFFEDEFF2)),
            ),
        ],
      ),
    );
  }

  Widget _circle(String name, Color fg, Color bg) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? '?' : name.characters.first,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
          color: fg == AppBrand.muted ? AppBrand.muted : Colors.white,
        ),
      ),
    );
  }
}

/// 单个地图图钉：白色圆角卡 + 下方小三角。
class MapPin extends StatelessWidget {
  const MapPin(this.text, {super.key, this.accent = false});

  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            boxShadow: AppBrand.cardSm,
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: accent ? AppBrand.primaryDeep : AppBrand.ink,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Transform.translate(
            offset: const Offset(0, -3),
            child: Transform.rotate(
              angle: math.pi / 4,
              child: Container(width: 10, height: 10, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

/// 贴纸：轻微旋转的白色圆角方块 + 图标。地图插画的"人味"来源。
class Sticker extends StatelessWidget {
  const Sticker(this.icon, {super.key, this.size = 46, this.angle = -0.14});

  final IconData icon;
  final double size;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.3),
          boxShadow: AppBrand.cardSm,
        ),
        child: Icon(icon, size: size * 0.48, color: AppBrand.primaryDeep),
      ),
    );
  }
}

/// 地图插画。整套设计的记忆点：天空底 + 草地形 + 蓝色虚线路线 + 白图钉 + 贴纸。
/// 活动封面、引导页插画都用它，替换掉之前的纯色渐变块。
class MapScene extends StatelessWidget {
  const MapScene({
    super.key,
    this.height = 180,
    this.width,
    this.radius = 24,
    this.badge,
    this.badgeColor = AppBrand.black,
    this.sticker,
    this.stickerSecond,
    this.pins = const <MapPinSpec>[],
    this.route = true,
    this.centerIcon,
  });

  final double height;
  final double? width;
  final double radius;
  final String? badge;
  final Color badgeColor;
  final IconData? sticker;
  final IconData? stickerSecond;
  final List<MapPinSpec> pins;
  final bool route;
  final IconData? centerIcon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: LayoutBuilder(
          builder: (context, c) {
            final cw = c.maxWidth;
            final ch = c.maxHeight;
            return Stack(
              children: <Widget>[
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[Color(0xFFE3F4FE), Color(0xFFF6FCFF)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -cw * 0.30,
                  top: ch * 0.34,
                  child: _hill(cw * 1.5, ch * 0.92, AppBrand.grass),
                ),
                Positioned(
                  left: cw * 0.28,
                  top: ch * 0.10,
                  child: _hill(cw * 1.1, ch * 0.74, const Color(0xFFD3F2BC)),
                ),
                if (route)
                  Positioned.fill(
                    child: CustomPaint(painter: _RoutePainter()),
                  ),
                if (centerIcon != null)
                  Center(
                    child: Icon(centerIcon, size: height * 0.30, color: Colors.white.withValues(alpha: 0.95)),
                  ),
                if (badge != null)
                  Positioned(left: 12, top: 12, child: InkTag(badge!, color: badgeColor)),
                for (final p in pins)
                  Positioned(left: cw * p.x, top: ch * p.y, child: MapPin(p.text, accent: p.accent)),
                if (sticker != null)
                  Positioned(right: cw * 0.06, top: ch * 0.10, child: Sticker(sticker!)),
                if (stickerSecond != null)
                  Positioned(
                    right: cw * 0.14,
                    bottom: ch * 0.16,
                    child: Sticker(stickerSecond!, size: 38, angle: 0.18),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _hill(double w, double h, Color color) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.all(Radius.elliptical(w / 2, h / 2)),
        ),
      );
}

/// 图钉位置：x/y 为相对封面宽高的 0~1 比例。
class MapPinSpec {
  const MapPinSpec(this.text, this.x, this.y, {this.accent = false});

  final String text;
  final double x;
  final double y;
  final bool accent;
}

/// 蓝色虚线路线：一条从左上草坡走到右上草坡的弧线，两端各一个点。
class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.13, size.height * 0.80)
      ..cubicTo(
        size.width * 0.36, size.height * 0.66,
        size.width * 0.30, size.height * 0.42,
        size.width * 0.52, size.height * 0.40,
      )
      ..cubicTo(
        size.width * 0.76, size.height * 0.38,
        size.width * 0.70, size.height * 0.16,
        size.width * 0.87, size.height * 0.13,
      );

    final paint = Paint()
      ..color = AppBrand.route
      ..strokeWidth = math.max(2.6, size.height * 0.022)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      const dash = 1.0;
      const gap = 11.0;
      while (distance < metric.length) {
        final next = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }

    canvas.drawCircle(
      Offset(size.width * 0.13, size.height * 0.80),
      math.max(5, size.height * 0.032),
      Paint()..color = AppBrand.primary,
    );
    canvas.drawCircle(
      Offset(size.width * 0.13, size.height * 0.80),
      math.max(5, size.height * 0.032),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(
      Offset(size.width * 0.87, size.height * 0.13),
      math.max(5, size.height * 0.032),
      Paint()..color = AppBrand.grassDeep,
    );
    canvas.drawCircle(
      Offset(size.width * 0.87, size.height * 0.13),
      math.max(5, size.height * 0.032),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 骨架屏占位块。
///
/// 用**扫光**（一条浅色高光从左到右流过）而不是整块呼吸明暗：
/// 整块一起变暗变亮，看起来更像"内容空洞"而不是"正在加载"；
/// 而且多个块同时呼吸时相位是散的，扫光只要方向一致就自然像一条波在流。
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.radius = 12});

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // 高光带从 -1 走到 2，两端各留出一段空白，避免"边缘突然出现一条线"
        final t = _controller.value * 3 - 1;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(t - 0.6, 0),
              end: Alignment(t + 0.6, 0),
              colors: const <Color>[
                Color(0xFFE4EDF4),
                Color(0xFFF5FAFD),
                Color(0xFFE4EDF4),
              ],
              stops: const <double>[0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// 列表加载骨架：封面在上的活动卡占位。
///
/// 每行错开一点启动（40ms），扫光才有"从上往下走"的层次；
/// 全部同时启动会看成同一块在闪。
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.rows = 4, this.padding = const EdgeInsets.all(16)});

  final int rows;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        children: <Widget>[
          for (int i = 0; i < rows; i++) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _Shimmer(child: SkeletonBox(height: 104, radius: 18)),
                  const SizedBox(height: 12),
                  _Shimmer(child: SkeletonBox(height: 16, radius: 6)),
                  const SizedBox(height: 10),
                  _Shimmer(child: SkeletonBox(width: 150, height: 11, radius: 5)),
                  const SizedBox(height: 12),
                  _Shimmer(child: SkeletonBox(height: 8, radius: 5)),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

/// 给骨架块叠一层整体淡入，让"骨架 → 内容"的切换不是硬切。
///
/// 用 `TweenAnimationBuilder` 而不是 `AnimatedOpacity`：后者要求外部传状态，
/// 而这里只需要"挂载时淡入一次"，多一个状态位就多一处能写错的地方。
class _Shimmer extends StatelessWidget {
  const _Shimmer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      builder: (context, t, c) => Opacity(opacity: t, child: c),
      child: child,
    );
  }
}

/// 小节标题：品牌蓝小方块 + 加粗文字。
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: AppBrand.primary,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppBrand.ink),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// 装饰圆斑：天空底的氛围元素。
class Blob extends StatelessWidget {
  const Blob({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
