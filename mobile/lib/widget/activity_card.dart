import 'package:flutter/material.dart';

import '../model/activity.dart';
import 'category_visual.dart';
import 'ui.dart';

/// 活动流卡片：地图插画封面在上的大圆角白卡。
/// 封面带 Hero，进详情无缝放大；名额进度条与头像堆叠让"还差几个人"一眼可见。
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
    final timeText = _timeText(activity.startTime);
    final badgeColor = timeText.startsWith('今天') ? AppBrand.primary : AppBrand.black;

    final cover = ActivityCover(
      category: activity.category,
      coverUrl: activity.coverUrl,
      height: 118,
      radius: 0,
      badge: timeText,
      badgeColor: badgeColor,
      pins: const <MapPinSpec>[
        MapPinSpec('集合点', 0.42, 0.30, accent: true),
      ],
    );

    return PressableScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppBrand.rLg),
          boxShadow: AppBrand.card,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppBrand.rLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Stack(
                children: <Widget>[
                  hero ? Hero(tag: 'activity-cover-${activity.id}', child: cover) : cover,
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: AppBrand.cardSm,
                      ),
                      child: const Icon(Icons.favorite, size: 16, color: AppBrand.hot),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      activity.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                        color: AppBrand.ink,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: <Widget>[
                        SoftTag(
                          distanceKm == null
                              ? activity.address
                              : '${_short(activity.address)} · ${_km(distanceKm!)}',
                          icon: Icons.place_rounded,
                        ),
                        SoftTag(activity.category, tone: SoftTagTone.grass),
                        if (activity.status != 'OPEN')
                          SoftTag(activity.statusLabel, tone: SoftTagTone.warm),
                      ],
                    ),
                    const SizedBox(height: 13),
                    ProgressCap(
                      current: activity.currentParticipants,
                      max: activity.maxParticipants,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(child: _who(context)),
                        const Text(
                          '去看看 ›',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppBrand.primaryDeep,
                          ),
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

  Widget _who(BuildContext context) {
    final names = activity.participants.isNotEmpty
        ? activity.participants.map((p) => p.nickname).toList()
        : <String>[if (activity.organizerNickname != null) activity.organizerNickname!];
    if (names.isEmpty) {
      return const Text(
        '还没有人报名，来做第一个',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12.5, color: AppBrand.muted),
      );
    }
    return Row(
      children: <Widget>[
        AvatarStack(names: names, size: 26),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            activity.organizerNickname != null ? '${activity.organizerNickname} 发起' : '已有人报名',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppBrand.muted),
          ),
        ),
      ],
    );
  }

  /// 地址太长时只留最后一段（"朝阳区建国门外大街 1 号" → "建国门外大街 1 号"）。
  static String _short(String address) {
    final parts = address.split('·').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final tail = parts.isEmpty ? address : parts.last;
    return tail.length <= 14 ? tail : '${tail.substring(0, 13)}…';
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

  static String _km(double v) => v < 1 ? '${(v * 1000).round()}m' : '${v.toStringAsFixed(1)}km';
}
