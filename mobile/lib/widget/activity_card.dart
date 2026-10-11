import 'package:flutter/material.dart';

import '../model/activity.dart';
import 'category_visual.dart';

/// 活动流卡片。
class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, required this.activity, this.distanceKm, this.onTap});

  final Activity activity;
  final double? distanceKm;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ActivityCover(category: activity.category, coverUrl: activity.coverUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      activity.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.3),
                    ),
                    const SizedBox(height: 6),
                    _MetaRow(icon: Icons.schedule, text: _timeText(activity.startTime)),
                    const SizedBox(height: 4),
                    _MetaRow(
                      icon: Icons.place_outlined,
                      text: distanceKm == null
                          ? activity.address
                          : '${activity.address} · 距你 ${_km(distanceKm!)}',
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        _StatusPill(activity: activity),
                        const Spacer(),
                        Icon(Icons.group_outlined, size: 15, color: scheme.outline),
                        const SizedBox(width: 3),
                        Text(
                          '${activity.currentParticipants}/${activity.maxParticipants}',
                          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
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
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Icon(icon, size: 15, color: scheme.outline),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final visual = CategoryVisual.of(activity.category);
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: visual.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            activity.category,
            style: TextStyle(fontSize: 12, color: visual.color, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          activity.statusLabel,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: switch (activity.status) {
              'OPEN' => const Color(0xFF1E8E3E),
              'FULL' => const Color(0xFFB26A00),
              'CANCELLED' => const Color(0xFFB3261E),
              _ => Theme.of(context).colorScheme.outline,
            },
          ),
        ),
      ],
    );
  }
}
