import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_scope.dart';
import '../model/activity.dart';
import '../model/user.dart';
import '../state/activity_state.dart';
import '../state/session_state.dart';
import '../widget/activity_card.dart';
import '../widget/state_views.dart';
import '../widget/ui.dart';
import 'activity_detail_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<ActivityState>().loadMine();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    final activities = context.watch<ActivityState>();
    final scope = context.read<AppScope>();
    final me = session.me;

    if (me == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('我的'),
          actions: <Widget>[
            IconButton(
              tooltip: '退出登录',
              onPressed: () => _confirmLogout(context),
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: SkyBackground(
          height: 380,
          child: NestedScrollView(
            headerSliverBuilder: (_, _) => <Widget>[
              SliverToBoxAdapter(child: _header(context, me, scope.usingMock, activities)),
            ],
            body: Column(
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 4, 18, 10),
                  child: TabBar(
                    tabs: <Widget>[
                      Tab(text: '我发起的'),
                      Tab(text: '我报名的'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: <Widget>[
                      _list(context, activities.organized, '还没发起过活动', '去活动页点右下角，做第一个组局的人'),
                      _list(context, activities.joined, '还没报名过活动', '看看活动流里有什么合适的'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// `me` 由 build() 判空后传进来，这里不再做第二次 `!`——
  /// headerSliverBuilder 是延迟调用的闭包，多一个断言点就多一个崩溃面。
  Widget _header(BuildContext context, User me, bool usingMock, ActivityState activities) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: Column(
        children: <Widget>[
          // 头像：白描边圆角方块 + 天空蓝渐变底
          Container(
            width: 86,
            height: 86,
            decoration: const BoxDecoration(
              gradient: AppBrand.brand,
              borderRadius: BorderRadius.all(Radius.circular(30)),
              boxShadow: AppBrand.glow,
            ),
            alignment: Alignment.center,
            child: Text(
              me.nickname.characters.first,
              style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                me.nickname,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppBrand.ink),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppBrand.primarySoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '信用分 ${me.creditScore}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppBrand.primaryDeep,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            (me.bio ?? '').isNotEmpty
                ? me.bio!
                : (me.phone.length == 11
                    ? '${me.phone.substring(0, 3)}****${me.phone.substring(7)}'
                    : me.phone),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: AppBrand.muted),
          ),
          const SizedBox(height: 18),

          // 数据卡
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppBrand.rMd),
              boxShadow: AppBrand.card,
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: <Widget>[
                _Stat(value: '${me.creditScore}', label: '信用分'),
                _Stat(value: '${activities.organized.length}', label: '我发起的'),
                _Stat(value: '${activities.joined.length}', label: '我报名的'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  usingMock ? Icons.science_outlined : Icons.cloud_done_outlined,
                  size: 15,
                  color: AppBrand.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  usingMock ? '数据源：内存假数据（USE_MOCK）' : '数据源：已连接本地后端',
                  style: const TextStyle(fontSize: 12, color: AppBrand.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, List<Activity> items, String emptyTitle, String emptyHint) {
    if (items.isEmpty) {
      return EmptyView(title: emptyTitle, hint: emptyHint, icon: Icons.event_note_outlined);
    }
    return RefreshIndicator(
      onRefresh: () => context.read<ActivityState>().loadMine(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 110),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, i) => ActivityCard(
          activity: items[i],
          // "我的"两个 Tab 可能同屏各有一份同 id 活动，Hero 会撞 tag
          hero: false,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => ActivityDetailPage(activityId: items[i].id)),
            );
            if (context.mounted) {
              await context.read<ActivityState>().loadMine();
            }
          },
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录？'),
        content: const Text('会断开实时连接，本地保存的令牌一并清掉。'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('退出')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<SessionState>().logout();
    }
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppBrand.ink),
          ),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppBrand.muted)),
        ],
      ),
    );
  }
}
