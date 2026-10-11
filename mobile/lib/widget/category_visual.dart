import 'package:flutter/material.dart';

import 'ui.dart';

/// 分类的视觉映射。
///
/// 刻意不加载封面图：mock 模式必须能离线跑，真机演示时也不该因为图挂了露出白块。
/// 用"分类图标 + 地图插画"代替，信息密度反而更高，也统一了整套视觉语言。
class CategoryVisual {
  const CategoryVisual(this.emoji, this.color, this.icon);

  final String emoji;
  final Color color;
  final IconData icon;

  static const Map<String, CategoryVisual> _map = <String, CategoryVisual>{
    '剧本杀': CategoryVisual('🎭', Color(0xFF7C6BFF), Icons.theater_comedy_outlined),
    '运动': CategoryVisual('🏸', Color(0xFF3FB07A), Icons.sports_tennis_outlined),
    '探店': CategoryVisual('🍜', Color(0xFFF0913F), Icons.ramen_dining_outlined),
    '桌游': CategoryVisual('🎲', Color(0xFF3B8DE8), Icons.casino_outlined),
    '户外': CategoryVisual('⛰️', Color(0xFF4CAF6D), Icons.terrain_outlined),
    '观影': CategoryVisual('🎬', Color(0xFFF06A6A), Icons.movie_outlined),
    '其他': CategoryVisual('✨', Color(0xFF6C7C8A), Icons.auto_awesome_outlined),
  };

  static CategoryVisual of(String category) => _map[category] ?? _map['其他']!;

  /// 卡片封面的柔色底：两端同色系，避免花。
  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[color.withValues(alpha: 0.30), color.withValues(alpha: 0.12)],
      );
}

/// 活动封面：地图插画（天空 + 草地 + 虚线路线 + 分类贴纸）。
/// 没有封面图时用它；有 coverUrl 时优先用图，加载失败回落到插画。
class ActivityCover extends StatelessWidget {
  const ActivityCover({
    super.key,
    required this.category,
    this.coverUrl,
    this.width,
    this.height = 120,
    this.radius = 22,
    this.badge,
    this.badgeColor = AppBrand.black,
    this.pins = const <MapPinSpec>[],
    this.stickerAngle = -0.14,
  });

  final String category;
  final String? coverUrl;
  final double? width;
  final double height;
  final double radius;
  final String? badge;
  final Color badgeColor;
  final List<MapPinSpec> pins;
  final double stickerAngle;

  @override
  Widget build(BuildContext context) {
    final visual = CategoryVisual.of(category);
    final url = coverUrl;
    if (url == null || url.isEmpty) {
      return _scene(visual);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _scene(visual),
        ),
      ),
    );
  }

  Widget _scene(CategoryVisual visual) => MapScene(
        width: width,
        height: height,
        radius: radius,
        badge: badge,
        badgeColor: badgeColor,
        sticker: visual.icon,
        stickerSecond: null,
        pins: pins,
        centerIcon: null,
      );
}

/// 分类筛选小胶囊。选中态是天空蓝实底 + 蓝投影。
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 9),
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? AppBrand.primary : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? AppBrand.primary : AppBrand.line,
                width: 1.5,
              ),
              boxShadow: selected ? AppBrand.glow : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? Colors.white : AppBrand.ink2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
