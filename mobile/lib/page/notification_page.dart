import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/app_notification.dart';
import '../state/notification_state.dart';
import '../widget/state_views.dart';
import '../widget/ui.dart';
import 'activity_detail_page.dart';
import 'user_profile_page.dart';

/// 通知中心。规则见 `docs/05-通知与提醒.md`。
///
/// 入口挂在「消息」页的铃铛上（小程序同样如此），不占底部导航的一格——
/// 通知是"消息"域的一部分，单独一格会让人以为它是第四个模块。
class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // 进页面就重拉：通知可能是在别的页面上收到的（WS 只推了一帧，列表还没建）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationState>().refresh();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 260) {
      context.read<NotificationState>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NotificationState>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('通知'),
        actions: <Widget>[
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () => _markAll(context, state),
              child: const Text('全部已读'),
            ),
        ],
      ),
      body: SkyBackground(child: _body(context, state)),
    );
  }

  Future<void> _markAll(BuildContext context, NotificationState state) async {
    final ok = await state.readAll();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '已全部标为已读' : (state.lastError ?? '操作失败')),
        backgroundColor: ok ? null : Theme.of(context).colorScheme.error,
      ),
    );
  }

  Widget _body(BuildContext context, NotificationState state) {
    if (state.loading && state.items.isEmpty) {
      return const SingleChildScrollView(child: SkeletonList(rows: 5));
    }
    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: state.refresh,
        child: ListView(
          children: const <Widget>[
            SizedBox(height: 60),
            EmptyView(
              title: '还没有通知',
              hint: '有人报名你的活动、活动被取消、或活动即将开始时，这里都会提醒你',
              icon: Icons.notifications_none_rounded,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: state.refresh,
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
        itemCount: state.items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          if (i == state.items.length) {
            return LoadMoreFooter(
              loading: state.loadingMore,
              hasMore: !state.finished,
              onLoad: state.loadMore,
            );
          }
          final n = state.items[i];
          return _NotificationTile(notification: n);
        },
      ),
    );
  }
}

/// 类型 → 图标与底色。
///
/// 小程序那边这七个类型配的是 emoji（🙋🚫⏰…），Flutter 端换成 Material 圆角图标 +
/// 同色系浅底。**这是刻意的差异**：emoji 在不同系统上的字形与留白差得很远，
/// 而 Flutter 这套视觉语言（`ui.dart` 的 SoftTag / 圆角软底）本来就以图标为主，
/// 混进 emoji 会显得像两种风格拼在一起。类型集合与"能不能跳、跳到哪"两端完全一致。
class _NotificationVisual {
  const _NotificationVisual(this.icon, this.bg, this.fg);

  final IconData icon;
  final Color bg;
  final Color fg;

  static const Map<String, _NotificationVisual> _map = <String, _NotificationVisual>{
    'SIGNUP_NEW': _NotificationVisual(Icons.person_add_alt_1_rounded, AppBrand.grassSoft, Color(0xFF4E8F3C)),
    'ACTIVITY_CANCELLED': _NotificationVisual(Icons.event_busy_rounded, Color(0xFFFFF3E8), Color(0xFFC77A2A)),
    'ACTIVITY_REMINDER': _NotificationVisual(Icons.alarm_rounded, AppBrand.primarySoft, AppBrand.primaryDeep),
    'ACTIVITY_TAKEDOWN': _NotificationVisual(Icons.gpp_maybe_rounded, Color(0xFFFFEBEE), Color(0xFFC5303F)),
    'REPORT_HANDLED': _NotificationVisual(Icons.assignment_turned_in_rounded, AppBrand.primarySoft, AppBrand.primaryDeep),
    'BADGE_UNLOCKED': _NotificationVisual(Icons.military_tech_rounded, Color(0xFFFFF3E8), Color(0xFFC77A2A)),
    'USER_FOLLOWED': _NotificationVisual(Icons.group_add_rounded, AppBrand.primarySoft, AppBrand.primaryDeep),
  };

  static _NotificationVisual of(String type) =>
      _map[type] ??
      const _NotificationVisual(Icons.notifications_rounded, Color(0xFFF1F5F8), AppBrand.ink2);
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final v = _NotificationVisual.of(n.type);

    return PressableScale(
      onTap: () => _open(context, n),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppBrand.rMd),
          boxShadow: AppBrand.cardSm,
          // 未读靠左侧一道蓝条 + 右上角圆点，不再整卡换底色：
          // 整卡变色在长列表里会形成一片色块，反而看不出哪些是新的
          border: n.read ? null : const Border(left: BorderSide(color: AppBrand.primary, width: 3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: v.bg, borderRadius: BorderRadius.circular(12)),
              child: Icon(v.icon, size: 19, color: v.fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          n.title ?? '通知',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppBrand.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        ago(n.createdAt),
                        style: const TextStyle(fontSize: 11.5, color: AppBrand.muted),
                      ),
                      if (!n.read) ...<Widget>[
                        const SizedBox(width: 6),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(color: AppBrand.hot, shape: BoxShape.circle),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    n.content,
                    style: const TextStyle(fontSize: 13, height: 1.6, color: AppBrand.ink2),
                  ),
                  if (n.jumpable) ...<Widget>[
                    const SizedBox(height: 7),
                    Text(
                      n.target == NotificationTarget.user ? '查看主页 ›' : '查看活动 ›',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppBrand.primaryDeep,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 先标已读再跳转。
  ///
  /// **标记失败不拦跳转**——用户点这条的目的是看内容，不是标记；为了一个红点
  /// 把跳转按住，等于让同步问题变成用户的问题。已读态下次 [refresh] 会以服务端为准纠正。
  Future<void> _open(BuildContext context, AppNotification n) async {
    final state = context.read<NotificationState>();
    await state.markRead(n);
    if (!context.mounted) {
      return;
    }
    switch (n.target) {
      case NotificationTarget.activity:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => ActivityDetailPage(activityId: n.bizId!)),
        );
      case NotificationTarget.user:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => UserProfilePage(userId: n.bizId!)),
        );
      case NotificationTarget.none:
        break;
    }
  }

  /// 相对时间。与小程序 `fmt.ago` 同口径：分钟 → 小时 → 天。
  static String ago(DateTime? t) {
    if (t == null) {
      return '';
    }
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return '刚刚';
    if (d.inMinutes < 60) return '${d.inMinutes} 分钟前';
    if (d.inHours < 24) return '${d.inHours} 小时前';
    if (d.inDays < 30) return '${d.inDays} 天前';
    return '${t.month}月${t.day}日';
  }
}
