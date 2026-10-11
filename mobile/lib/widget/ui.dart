import 'package:flutter/material.dart';

/// 视觉基元与动效原语。品牌色、渐变、阴影、骨架屏都收敛在这里，
/// 页面里不再散落手写的 Color(0x...) 与 BoxShadow。
class AppBrand {
  AppBrand._();

  /// 品牌主色（靛蓝）与辅助紫，构成品牌渐变。
  static const Color primary = Color(0xFF5B7FFF);
  static const Color secondary = Color(0xFF8E5CFF);

  /// 热色：未读数等强提醒。
  static const Color hot = Color(0xFFFF6B8B);

  static const Color ink = Color(0xFF1B2033);
  static const Color muted = Color(0xFF868DA3);
  static const Color line = Color(0xFFE7EAF5);
  static const Color bg = Color(0xFFF4F6FB);

  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[primary, secondary],
  );

  /// 卡片弥散阴影。
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(color: Color(0x141B2B4D), blurRadius: 18, offset: Offset(0, 6)),
  ];

  /// 品牌色投影（渐变按钮 / FAB / 强调元素）。
  static const List<BoxShadow> glow = <BoxShadow>[
    BoxShadow(color: Color(0x3D5B7FFF), blurRadius: 18, offset: Offset(0, 8)),
  ];
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
/// 用"拉长总时长 + Interval 曲线"实现延迟，不需要 Timer。
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

/// 品牌渐变主按钮。禁用时整体变灰；busy 时转圈并保持高度不跳。
/// 手写而不是 FilledButton，是为了拿到渐变背景 + 品牌投影。
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.busy = false,
    this.height = 52,
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
            gradient: enabled ? AppBrand.brand : null,
            color: enabled ? null : const Color(0xFFC7CBDB),
            borderRadius: BorderRadius.circular(18),
            boxShadow: enabled ? AppBrand.glow : null,
          ),
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                )
              : Text(
                  text,
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
          color: const Color(0xFFE7EAF3),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// 列表加载骨架：几行"封面 + 三行字"的灰卡。
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
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: <Widget>[
                  const SkeletonBox(width: 84, height: 84, radius: 16),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const <Widget>[
                        SkeletonBox(height: 16, radius: 6),
                        SizedBox(height: 10),
                        SkeletonBox(width: 150, height: 11, radius: 5),
                        SizedBox(height: 8),
                        SkeletonBox(width: 92, height: 11, radius: 5),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// 小节标题：品牌渐变竖条 + 加粗文字。
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            gradient: AppBrand.brand,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppBrand.ink)),
      ],
    );
  }
}

/// 装饰圆斑：渐变卡与登录页背景的氛围元素。
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
