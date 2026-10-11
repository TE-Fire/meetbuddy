import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_scope.dart';
import '../model/activity.dart';
import '../model/user.dart';
import '../state/activity_state.dart';
import '../state/session_state.dart';
import '../widget/activity_card.dart';
import '../widget/state_views.dart';
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
        appBar: AppBar(
          title: const Text('我的'),
          actions: <Widget>[
            IconButton(
              tooltip: '退出登录',
              onPressed: () => _confirmLogout(context),
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: NestedScrollView(
          headerSliverBuilder: (_, _) => <Widget>[
            SliverToBoxAdapter(child: _header(context, me, scope.usingMock)),
          ],
          body: Column(
            children: <Widget>[
              const TabBar(
                tabs: <Widget>[
                  Tab(text: '我发起的'),
                  Tab(text: '我报名的'),
                ],
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
    );
  }

  /// `me` 由 build() 判空后传进来，这里不再做第二次 `!`——
  /// headerSliverBuilder 是延迟调用的闭包，多一个断言点就多一个崩溃面。
  Widget _header(BuildContext context, User me, bool usingMock) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[scheme.primary, scheme.primary.withValues(alpha: 0.75)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                child: Text(
                  me.nickname.characters.first,
                  style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(me.nickname,
                        style: const TextStyle(fontSize: 19, color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      me.phone.length == 11 ? '${me.phone.substring(0, 3)}****${me.phone.substring(7)}' : me.phone,
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text('${me.creditScore}',
                      style: const TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.w800)),
                  Text('信用分', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
                ],
              ),
            ],
          ),
          if ((me.bio ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Text(me.bio!, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.92), height: 1.5)),
          ],
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Icon(usingMock ? Icons.science_outlined : Icons.cloud_done_outlined,
                  size: 15, color: Colors.white.withValues(alpha: 0.85)),
              const SizedBox(width: 6),
              Text(
                usingMock ? '数据源：内存假数据（USE_MOCK）' : '数据源：已连接本地后端',
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
              ),
            ],
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) => ActivityCard(
          activity: items[i],
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
