import 'package:flutter/material.dart';

/// 分类的视觉映射。
///
/// 刻意不加载封面图：mock 模式必须能离线跑，真机演示时也不该因为图挂了露出白块。
/// 用分类色块 + 图标代替，信息密度反而更高。
class CategoryVisual {
  const CategoryVisual(this.emoji, this.color, this.icon);

  final String emoji;
  final Color color;
  final IconData icon;

  static const Map<String, CategoryVisual> _map = <String, CategoryVisual>{
    '剧本杀': CategoryVisual('🎭', Color(0xFF7C4DFF), Icons.theater_comedy_outlined),
    '运动': CategoryVisual('🏸', Color(0xFF00A67E), Icons.sports_tennis_outlined),
    '探店': CategoryVisual('🍜', Color(0xFFF2994A), Icons.ramen_dining_outlined),
    '桌游': CategoryVisual('🎲', Color(0xFF2E6BE6), Icons.casino_outlined),
    '户外': CategoryVisual('⛰️', Color(0xFF219653), Icons.terrain_outlined),
    '观影': CategoryVisual('🎬', Color(0xFFEB5757), Icons.movie_outlined),
    '其他': CategoryVisual('✨', Color(0xFF6B7280), Icons.auto_awesome_outlined),
  };

  static CategoryVisual of(String category) => _map[category] ?? _map['其他']!;

  /// 卡片封面的渐变。两端同色系，避免花。
  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[color.withValues(alpha: 0.92), color.withValues(alpha: 0.62)],
      );
}

/// 活动封面。没有 coverUrl 时渲染分类渐变色块。
class ActivityCover extends StatelessWidget {
  const ActivityCover({
    super.key,
    required this.category,
    this.coverUrl,
    this.width = 96,
    this.height = 96,
    this.radius = 14,
  });

  final String category;
  final String? coverUrl;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final visual = CategoryVisual.of(category);
    final url = coverUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: url == null || url.isEmpty
            ? _placeholder(visual)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(visual),
              ),
      ),
    );
  }

  Widget _placeholder(CategoryVisual visual) => DecoratedBox(
        decoration: BoxDecoration(gradient: visual.gradient),
        child: Center(
          child: Text(visual.emoji, style: TextStyle(fontSize: height * 0.36)),
        ),
      );
}

/// 分类筛选小胶囊。
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
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? scheme.primary : Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
