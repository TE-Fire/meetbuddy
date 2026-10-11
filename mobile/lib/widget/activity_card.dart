import 'package:flutter/material.dart';

import '../model/activity.dart';
import 'category_visual.dart';
import 'ui.dart';

/// 活动流卡片。白卡弥散阴影 + 按压缩放；封面带 Hero，进详情无缝放大。
class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.activity,
    this.distanceKm,
    this.onTap,
    this.hero = true,
  });

  final Activity activity;
  final double? distanceKm;
  final VoidCallback? onTap;

  /// Hero 默认开。同屏可能出现同一活动id 的页面（如"我的"两个 Tab）要关掉，
  /// 否则同 tag 的两个 Hero 会让转场动画抛异常。
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final cover = ActivityCover(
      category: activity.category,
      coverUrl: activity.coverUrl,
      width: 86,
      height: 86,
      radius: 16,
    );

    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppBrand.card,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            hero
                ? Hero(tag: 'activity-cover-${activity.id}', child: cover)
                : cover,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    activity.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                      color: AppBrand.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _MetaRow(icon: Icons.schedule_rounded, text: _timeText(activity.startTime)),
                  const SizedBox(height: 4),
                  _MetaRow(
                    icon: Icons.place_rounded,
                    text: distanceKm == null
                        ? activity.address
                        : '${activity.address} · 距你 ${_km(distanceKm!)}',
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      _CategoryPill(activity: activity),
                      const SizedBox(width: 8),
                      _StatusLabel(activity: activity),
                      const Spacer(),
                      _Capacity(
                        current: activity.currentParticipants,
                        max: activity.maxParticipants,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _timeText(DateTime? t) {
    if (t == null) {
      return '时间待定';
    }
    final now = DateTime.now();
    final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
    final tomorrow = now.add(const Duration(days: 1));
    final isTomorrow = t.year == tomorrow.year && t.month == tomorrow.month && t.day == tomorrow.day;
    final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final md = '${t.month}月${t.day}日';
    if (sameDay) return '今天 $hm';
    if (isTomorrow) return '明天 $hm';
    return '$md $hm';
  }

  static String _km(double v) => v < 1 ? '${(v * 1000).round()} m' : '${v.toStringAsFixed(1)} km';
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 14, color: AppBrand.muted),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF5A6172)),
          ),
        ),
      ],
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final visual = CategoryVisual.of(activity.category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: visual.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        activity.category,
        style: TextStyle(fontSize: 12, color: visual.color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.activity});

  final Activity activity;

  static Color _color(String status) => switch (status) {
        'OPEN' => const Color(0xFF22A45D),
        'FULL' => const Color(0xFFB26A00),
        'CANCELLED' => const Color(0xFFE5484D),
        _ => AppBrand.muted,
      };

  @override
  Widget build(BuildContext context) {
    final c = _color(activity.status);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: c),
        ),
        const SizedBox(width: 4),
        Text(
          activity.statusLabel,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c),
        ),
      ],
    );
  }
}

/// 名额徽标。数字变化时用 AnimatedSwitcher 做一个轻快的滑动淡入。
class _Capacity extends StatelessWidget {
  const _Capacity({required this.current, required this.max});

  final int current;
  final int max;

  @override
  Widget build(BuildContext context) {
    final full = current >= max;
    final color = full ? const Color(0xFFB26A00) : AppBrand.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: full ? const Color(0xFFFFF3E0) : AppBrand.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.5), end: Offset.zero).animate(anim),
            child: child,
          ),
        ),
        child: Row(
          key: ValueKey<int>(current),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.group_rounded, size: 13, color: color),
            const SizedBox(width: 3),
            Text(
              '$current/$max',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
