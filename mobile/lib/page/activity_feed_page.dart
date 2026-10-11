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
      backgroundColor: Colors.transparent,
      body: SkyBackground(
        child: Column(
          children: <Widget>[
            SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _topNav(context, state),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 6, 22, 14),
                    child: DisplayHeading(
                      lead: '附近有什么',
                      highlight: '好局',
                      subtitle: nickname.isEmpty ? '同城组局 · 找个搭子' : '$nickname · 同城组局，找个搭子',
                      size: 27,
                      align: TextAlign.left,
                      crossAxisAlignment: CrossAxisAlignment.start,
                    ),
                  ),
                  _filterBar(context, state),
                  if (state.geoEnabled) _radiusBar(context, state),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            Expanded(child: _body(context, state)),
          ],
        ),
      ),
    );
  }

  /// 顶部：城市 + 搜索胶囊。搜索不做真实检索（后端还没有全文检索接口），
  /// 点了只提示一句，保证"有入口但不假装能用"。
  Widget _topNav(BuildContext context, ActivityState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Row(
        children: <Widget>[
          const Text(
            '上海',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppBrand.ink),
          ),
          const SizedBox(width: 3),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppBrand.primary),
          const SizedBox(width: 12),
          Expanded(
            child: PressableScale(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('搜索还在路上，先用下面的分类逛逛')),
              ),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: AppBrand.cardSm,
                ),
                child: const Row(
                  children: <Widget>[
                    Icon(Icons.search_rounded, size: 17, color: AppBrand.muted),
                    SizedBox(width: 8),
                    Text(
                      '搜活动、搜搭子',
                      style: TextStyle(fontSize: 13, color: AppBrand.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          PressableScale(
            onTap: () => state.setGeo(!state.geoEnabled),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: state.geoEnabled ? AppBrand.primary : Colors.white,
                borderRadius: BorderRadius.circular(999),
                boxShadow: state.geoEnabled ? AppBrand.glow : AppBrand.cardSm,
              ),
              child: Icon(
                state.geoEnabled ? Icons.my_location_rounded : Icons.location_searching_rounded,
                size: 19,
                color: state.geoEnabled ? Colors.white : AppBrand.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterBar(BuildContext context, ActivityState state) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppBrand.primarySoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.place_rounded, size: 16, color: AppBrand.primaryDeep),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '演示坐标：北京国贸 · 半径 ${state.radius.toStringAsFixed(0)} km',
                style: const TextStyle(fontSize: 12.5, color: AppBrand.primaryDeep),
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
              child: const Row(
                children: <Widget>[
                  Text(
                    '改半径',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppBrand.primaryDeep,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, size: 18, color: AppBrand.primaryDeep),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ActivityState state) {
    if (state.feed.isEmpty && state.loading) {
      return const SingleChildScrollView(child: SkeletonList(rows: 3));
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
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 118),
        itemCount: state.feed.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
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
