import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/activity.dart';
import '../state/activity_state.dart';
import '../widget/activity_card.dart';
import '../widget/category_visual.dart';
import '../widget/state_views.dart';
import '../widget/ui.dart';
import 'activity_detail_page.dart';

/// 我的日程。规则与口径见小程序 `pages/schedule/schedule.js`，Flutter 端逐条对齐。
///
/// 数据源复用 [ActivityState] 的 organized / joined（`loadMine(size: 100)`）——
/// "我的"页已经在拉这两个列表，日程页再建一份仓储只会让两处数字对不上。
/// 分组、排序、筛选都在页面内按 dateKey 现算，不落 state：这些是纯展示口径，
/// 换个页面（比如以后的"周视图"）算法要变，state 不该跟着长。
class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

/// 筛选口径。取值与小程序 `data-f` 一致：all / host / join。
enum _ScheduleFilter {
  all('全部'),
  host('我发起'),
  join('我报名');

  const _ScheduleFilter(this.label);

  final String label;
}

/// 按日期分组的一天。label 是"今天 / 明天 / 后天 / 周X / X月X日"，
/// past 表示这一天里最早结束的活动都已过去（整组灰显 + "已结束"标签）。
class _DayGroup {
  _DayGroup({required this.key, required this.label, required this.past, required this.items});

  final String key;
  final String label;
  final bool past;
  final List<_ScheduleItem> items;
}

/// 一条日程。role 决定"我发起 / 我报名"标签与筛选归属。
class _ScheduleItem {
  _ScheduleItem({required this.activity, required this.host});

  final Activity activity;
  final bool host;

  bool get past {
    final end = activity.endTime ?? activity.startTime;
    // 结束时间已过才算「已过去」，进行中(ONGOING)的活动不灰显——与小程序同口径
    return end != null && end.isBefore(DateTime.now());
  }
}

class _SchedulePageState extends State<SchedulePage> {
  _ScheduleFilter _filter = _ScheduleFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // 每次进页面重拉：报名/取消可能发生在详情页，且这是 onShow 级的页面
        context.read<ActivityState>().loadMine(size: 100);
      }
    });
  }

  /// 日期分组键：`YYYY-MM-DD`。字符串可直接比较大小，省得反复比年月日。
  static String _dateKey(DateTime t) {
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    return '${t.year}-$m-$d';
  }

  /// 日期标签：今天 / 明天 / 后天 / 周X / X月X日。与小程序 `dateLabel` 逐字对齐。
  static String _dateLabel(DateTime t) {
    final now = DateTime.now();
    final a = DateTime(t.year, t.month, t.day);
    final b = DateTime(now.year, now.month, now.day);
    final diff = a.difference(b).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '明天';
    if (diff == 2) return '后天';
    if (diff > 2 && diff < 7) return '周${'日一二三四五六'[t.weekday % 7]}';
    return '${t.month}月${t.day}日';
  }

  /// 合并两个列表并按当前筛选分组排序。
  ///
  /// 顺序与小程序 `applyFilter` 一致：未来组在前（按日期升序）、过去组在后
  /// （按日期降序，最近的过去排在前）；组内按开始时间升序。
  /// 去重时 host 优先——同一个活动既是我发起的又是我报名的（理论上不会，
  /// 后端禁止组织者报名），以"我发起"身份呈现更诚实。
  List<_DayGroup> _groups(ActivityState state) {
    final byId = <int, _ScheduleItem>{};
    for (final a in state.organized) {
      byId[a.id] = _ScheduleItem(activity: a, host: true);
    }
    for (final a in state.joined) {
      byId.putIfAbsent(a.id, () => _ScheduleItem(activity: a, host: false));
    }

    final all = byId.values.where((item) {
      switch (_filter) {
        case _ScheduleFilter.all:
          return true;
        case _ScheduleFilter.host:
          return item.host;
        case _ScheduleFilter.join:
          return !item.host;
      }
    }).toList();

    final todayKey = _dateKey(DateTime.now());
    final buckets = <String, List<_ScheduleItem>>{};
    for (final item in all) {
      final t = item.activity.startTime;
      if (t == null) {
        continue;
      }
      final key = _dateKey(t);
      buckets.putIfAbsent(key, () => <_ScheduleItem>[]).add(item);
    }

    final future = <_DayGroup>[];
    final past = <_DayGroup>[];
    for (final entry in buckets.entries) {
      final items = entry.value..sort((x, y) => x.activity.startTime!.compareTo(y.activity.startTime!));
      final first = items.first.activity.startTime!;
      final group = _DayGroup(
        key: entry.key,
        label: _dateLabel(first),
        // 整组标"已结束"要求这一天**每一场都过去**。小程序看的是当天最早一场
        // （items[0].past），会把"上午场已过、晚上还有局"的白天整片灰掉；
        // 单场是否灰显由 [_EventTile] 各自按 endTime 判，两者不冲突。
        past: items.every((item) => item.past),
        items: items,
      );
      if (entry.key.compareTo(todayKey) >= 0) {
        future.add(group);
      } else {
        past.add(group);
      }
    }
    future.sort((a, b) => a.key.compareTo(b.key));
    past.sort((a, b) => b.key.compareTo(a.key));
    return future + past;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ActivityState>();
    final groups = _groups(state);
    final loading = state.loading && state.organized.isEmpty && state.joined.isEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('我的日程')),
      body: SkyBackground(
        child: Column(
          children: <Widget>[
            _FilterBar(
              filter: _filter,
              onChanged: (f) => setState(() => _filter = f),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => state.loadMine(size: 100),
                child: loading
                    ? const SingleChildScrollView(child: SkeletonList(rows: 4))
                    : groups.isEmpty
                        ? ListView(
                            children: <Widget>[
                              const SizedBox(height: 70),
                              EmptyView(
                                title: '还没有安排',
                                hint: '去发现页发起或报名一个活动，它会自动出现在这里',
                                icon: Icons.event_available_outlined,
                              ),
                            ],
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                            children: <Widget>[
                              for (int i = 0; i < groups.length; i++) ...<Widget>[
                                if (i > 0) const SizedBox(height: 18),
                                _DayGroupCard(group: groups[i]),
                              ],
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 顶部分段筛选。用 [TabBar] 的胶囊指示器（全局主题已有 [_PillIndicator] 那套），
/// 但这里不是 TabController 驱动的页面切换，改用自绘滑块更直接：
/// 三段等宽，滑块位置 = index / 2，无需测量。
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filter, required this.onChanged});

  final _ScheduleFilter filter;
  final ValueChanged<_ScheduleFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
      child: Container(
        height: 42,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(999),
          boxShadow: AppBrand.cardSm,
        ),
        child: Stack(
          children: <Widget>[
            AnimatedAlign(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              alignment: Alignment(-1 + filter.index.toDouble(), 0),
              child: FractionallySizedBox(
                widthFactor: 1 / _ScheduleFilter.values.length,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppBrand.ink,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: Row(
                children: <Widget>[
                  for (final f in _ScheduleFilter.values)
                    Expanded(
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: f == filter ? Colors.white : AppBrand.muted,
                          ),
                          child: Text(f.label),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 滑块在上层文字底下会透出来，所以拆成两层：滑块层 + 文字层各自 IgnorePointer，
            // 点击由最外层的 GestureDetector 按横向比例分发。
            Row(
              children: <Widget>[
                for (int i = 0; i < _ScheduleFilter.values.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(_ScheduleFilter.values[i]),
                      child: const SizedBox.expand(),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayGroupCard extends StatelessWidget {
  const _DayGroupCard({required this.group});

  final _DayGroup group;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Row(
            children: <Widget>[
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: group.past ? AppBrand.muted : AppBrand.primary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 9),
              Text(
                group.label,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: group.past ? AppBrand.muted : AppBrand.ink,
                ),
              ),
              if (group.past) ...<Widget>[
                const SizedBox(width: 8),
                const SoftTag('已结束', tone: SoftTagTone.plain),
              ],
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppBrand.rMd),
            boxShadow: AppBrand.cardSm,
          ),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < group.items.length; i++)
                _EventTile(
                  item: group.items[i],
                  showDivider: i != group.items.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.item, required this.showDivider});

  final _ScheduleItem item;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final a = item.activity;
    final past = item.past;
    final start = a.startTime;
    final hm = start == null
        ? '待定'
        : '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';

    return Column(
      children: <Widget>[
        PressableScale(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => ActivityDetailPage(activityId: a.id)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // 左列：开始时间 + 身份标签。固定宽度让右列的标题左缘对齐成一条线
                SizedBox(
                  width: 52,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        hm,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: past ? AppBrand.muted : AppBrand.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SoftTag(
                        item.host ? '我发起' : '我报名',
                        tone: item.host ? SoftTagTone.warm : SoftTagTone.sky,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${CategoryVisual.of(a.category).emoji} ${a.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: past ? AppBrand.muted : AppBrand.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${ActivityCard.shortAddress(a.address)} · ${a.statusLabel} · '
                        '${a.currentParticipants}/${a.maxParticipants}人',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: AppBrand.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: past ? AppBrand.line : AppBrand.muted,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 14, endIndent: 14, color: AppBrand.line),
      ],
    );
  }
}
