import 'dart:math' as math;

import 'package:flutter/material.dart';

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
class PressableScale extends StatefulWidget {
  const PressableScale({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// 列表入场动画：按 index 逐个延迟，淡入 + 上浮。
class StaggeredIn extends StatelessWidget {
  const StaggeredIn({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delay = (index > 10 ? 10 : index) * 55;
    final total = 360 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

/// 黑胶囊主按钮——这套设计语言的招牌。
/// 禁用时整体变灰；busy 时转圈并保持高度不跳。
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
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? AppBrand.black : const Color(0xFFC7D0D8),
            borderRadius: BorderRadius.circular(999),
            boxShadow: enabled ? AppBrand.inkGlow : null,
          ),
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
      ),
    );
  }
}

/// 白描边胶囊次按钮。
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.height = 54,
  });

  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppBrand.line, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 18, color: enabled ? AppBrand.ink : AppBrand.muted),
                const SizedBox(width: 7),
              ],
              Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: enabled ? AppBrand.ink : AppBrand.muted,
                ),
              ),
            ],
          ),
        ),
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

/// 骨架屏脉冲块。
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
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0xFFE9F1F7),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// 列表加载骨架：封面在上的活动卡占位。
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
                children: const <Widget>[
                  SkeletonBox(height: 104, radius: 18),
                  SizedBox(height: 12),
                  SkeletonBox(height: 16, radius: 6),
                  SizedBox(height: 10),
                  SkeletonBox(width: 150, height: 11, radius: 5),
                  SizedBox(height: 12),
                  SkeletonBox(height: 8, radius: 5),
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
