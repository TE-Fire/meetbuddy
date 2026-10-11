import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/activity_state.dart';
import '../state/session_state.dart';
import '../widget/activity_card.dart';
import '../widget/category_visual.dart';
import '../widget/state_views.dart';
import '../widget/ui.dart';
import 'activity_detail_page.dart';

class ActivityFeedPage extends StatefulWidget {
  const ActivityFeedPage({super.key});

  @override
  State<ActivityFeedPage> createState() => _ActivityFeedPageState();
}

class _ActivityFeedPageState extends State<ActivityFeedPage> {
  static const List<double> _radii = <double>[1, 3, 5, 10, 20, 50, 100];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final state = context.read<ActivityState>();
      if (state.feed.isEmpty) {
        state.loadFeed();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ActivityState>();
    final nickname = context.select<SessionState, String>((s) => s.me?.nickname ?? '');

    return Scaffold(
      appBar: AppBar(
        title: Text('$nickname，附近有什么'),
        actions: <Widget>[
          IconButton(
            tooltip: state.geoEnabled ? '关闭就近筛选' : '开启就近筛选（演示坐标：国贸）',
            onPressed: () => state.setGeo(!state.geoEnabled),
            icon: Icon(
              state.geoEnabled ? Icons.my_location : Icons.location_searching,
              color: state.geoEnabled ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _filterBar(context, state),
          if (state.geoEnabled) _radiusBar(context, state),
          const SizedBox(height: 4),
          Expanded(child: _body(context, state)),
        ],
      ),
    );
  }

  Widget _filterBar(BuildContext context, ActivityState state) {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: <Widget>[
          CategoryChip(
            label: '全部',
            selected: state.category == null,
            onTap: () => state.setCategory(null),
          ),
          for (final c in ActivityState.categories)
            CategoryChip(
              label: c,
              selected: state.category == c,
              onTap: () => state.setCategory(c),
            ),
        ],
      ),
    );
  }

  Widget _radiusBar(BuildContext context, ActivityState state) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.place, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '演示坐标：北京国贸 · 半径 ${state.radius.toStringAsFixed(0)} km',
              style: TextStyle(fontSize: 12.5, color: scheme.primary),
            ),
          ),
          PopupMenuButton<double>(
            initialValue: state.radius,
            tooltip: '选择半径',
            onSelected: state.setRadius,
            itemBuilder: (_) => <PopupMenuEntry<double>>[
              for (final r in _radii)
                PopupMenuItem<double>(value: r, child: Text('${r.toStringAsFixed(0)} km')),
            ],
            child: Row(
              children: <Widget>[
                Text('改半径', style: TextStyle(fontSize: 12.5, color: scheme.primary, fontWeight: FontWeight.w600)),
                Icon(Icons.arrow_drop_down, size: 18, color: scheme.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, ActivityState state) {
    if (state.feed.isEmpty && state.loading) {
      return const SingleChildScrollView(child: SkeletonList(rows: 5));
    }
    if (state.feed.isEmpty && state.error != null) {
      return ErrorView(message: state.error!, onRetry: () => state.loadFeed());
    }
    if (state.feed.isEmpty) {
      return EmptyView(
        title: state.geoEnabled ? '这个范围内还没有活动' : '还没有活动',
        hint: state.geoEnabled ? '把半径调大一点，或者关掉就近筛选看看全部' : '点右下角发起一个，做第一个组局的人',
        icon: Icons.explore_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: () => state.loadFeed(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: state.feed.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          if (i == state.feed.length) {
            return LoadMoreFooter(
              loading: state.loading,
              hasMore: state.hasMore,
              onLoad: state.loadMore,
            );
          }
          final a = state.feed[i];
          return StaggeredIn(
            index: i,
            child: ActivityCard(
              activity: a,
              distanceKm: state.distanceFrom(a),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => ActivityDetailPage(activityId: a.id)),
                );
                // 详情页里可能报了名/取消了，回来后刷新一次，避免卡片数字是旧的
                await state.loadFeed();
              },
            ),
          );
        },
      ),
    );
  }
}
