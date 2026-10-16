import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_scope.dart';
import '../model/api_exception.dart';
import '../model/badge.dart' as model;
import '../model/recent_activity.dart';
import '../model/user_profile.dart';
import '../state/session_state.dart';
import '../widget/state_views.dart';
import '../widget/ui.dart';
import 'activity_detail_page.dart';
import 'follow_list_page.dart';

/// 他人个人主页。规则见 `docs/06-成就勋章与个人主页.md` 第四节。
///
/// 入口有三处：活动详情的组织者卡、活动详情的报名人药丸、聊天列表的私聊头像。
/// 自己点自己也进得来——那时不显示关注按钮，只多一枚「这是你」标记。
class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key, required this.userId});

  final int userId;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  UserProfile? _profile;
  String? _error;
  bool _loading = true;

  /// 关注请求在飞。用它禁用按钮，防止连点把"关注/取关"翻成一串交错请求——
  /// 乐观更新下连点两次的最终态是看运气，而不是看用户想干什么。
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await context.read<AppScope>().userProfile.profile(widget.userId);
      if (!mounted) return;
      setState(() {
        _profile = p;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  /// 关注 / 取关：先翻转界面再发请求，失败回滚。
  ///
  /// 粉丝数跟着翻，但**用 max(0, …) 兜一道**——并发下别人的关注/取关可能让服务端
  /// 的真实值已经变了，乐观值减到负数比数字短暂偏一位更难解释。
  Future<void> _toggleFollow() async {
    final p = _profile;
    if (p == null || _acting) {
      return;
    }
    // 自己的主页不画关注按钮，这里再兜一道：以后有人给"自己"补入口时，
    // 不至于变成一个后端会回 1001「不能关注自己」的按钮
    if (p.userId == _meId) {
      return;
    }
    final on = !p.following;
    final prevCount = p.followerCount;
    setState(() {
      _acting = true;
      _profile = p.copyWith(
        following: on,
        followerCount: on ? prevCount + 1 : (prevCount > 0 ? prevCount - 1 : 0),
      );
    });
    try {
      await context.read<AppScope>().userProfile.follow(p.userId, on: on);
      if (!mounted) return;
      _toast(on ? '已关注' : '已取消关注');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _profile = p.copyWith(following: !on, followerCount: prevCount));
      _toast(e.message, error: true);
    } finally {
      if (mounted) {
        setState(() => _acting = false);
      }
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  int? get _meId => context.read<SessionState>().me?.id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('个人主页')),
      body: SkyBackground(height: 320, child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            SkeletonBox(height: 100, radius: 22),
            SizedBox(height: 12),
            SkeletonBox(height: 64, radius: 18),
            SizedBox(height: 12),
            SkeletonBox(height: 120, radius: 22),
          ],
        ),
      );
    }
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    final p = _profile;
    if (p == null) {
      return const EmptyView(
        title: '用户不存在',
        hint: '可能已被注销，返回上一页吧',
        icon: Icons.person_off_outlined,
      );
    }

    final self = p.userId == _meId;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
        children: <Widget>[
          _head(context, p, self),
          const SizedBox(height: 12),
          _followStats(context, p),
          if ((p.bio ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _flatCard(child: Text(p.bio!, style: const TextStyle(fontSize: 13.5, height: 1.7, color: AppBrand.ink2))),
          ],
          if (p.tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _flatCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    '兴趣标签',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppBrand.muted),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final t in p.tags) SoftTag(t, tone: SoftTagTone.plain),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _counts(p),
          const SizedBox(height: 22),
          const SectionHeader('勋章墙'),
          const SizedBox(height: 12),
          if (p.badges.isEmpty)
            const Text('还没有获得勋章', style: TextStyle(fontSize: 13.5, color: AppBrand.muted))
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                for (final b in p.badges) _BadgeChip(badge: b),
              ],
            ),
          const SizedBox(height: 24),
          const SectionHeader('最近完成'),
          const SizedBox(height: 12),
          if (p.recentActivities.isEmpty)
            const Text('还没有完成的活动', style: TextStyle(fontSize: 13.5, color: AppBrand.muted))
          else
            for (final a in p.recentActivities) ...<Widget>[
              _RecentTile(activity: a),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget _head(BuildContext context, UserProfile p, bool self) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppBrand.rLg),
        boxShadow: AppBrand.card,
      ),
      child: Row(
        children: <Widget>[
          UserAvatar(nickname: p.nickname, avatar: p.avatar, size: 62),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  p.nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppBrand.ink),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: <Widget>[
                    SoftTag('信用分 ${p.creditScore ?? 0}', tone: SoftTagTone.plain),
                    if (self)
                      SoftTag('这是你', tone: SoftTagTone.grass)
                    else if (p.banned)
                      SoftTag('已封禁', tone: SoftTagTone.warm),
                  ],
                ),
              ],
            ),
          ),
          if (!self) ...<Widget>[
            const SizedBox(width: 10),
            _FollowButton(on: p.following, busy: _acting, onTap: _toggleFollow),
          ],
        ],
      ),
    );
  }

  Widget _followStats(BuildContext context, UserProfile p) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppBrand.rMd),
        boxShadow: AppBrand.cardSm,
      ),
      child: Row(
        children: <Widget>[
          _CountCell(
            value: '${p.followingCount}',
            label: '关注',
            onTap: () => _openFollowList(context, FollowTab.following),
          ),
          const _CellDivider(),
          _CountCell(
            value: '${p.followerCount}',
            label: '粉丝',
            onTap: () => _openFollowList(context, FollowTab.followers),
          ),
          const _CellDivider(),
          // 信用分不再可点：明细页只对"我"有意义，看别人的扣分原因属于隐私
          _CountCell(value: '${p.creditScore ?? 0}', label: '信用分'),
        ],
      ),
    );
  }

  void _openFollowList(BuildContext context, FollowTab tab) {
    final p = _profile;
    if (p == null) {
      return;
    }
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => FollowListPage(userId: p.userId, initialTab: tab),
          ),
        )
        // 从列表回来要刷新计数：可能刚在那边关注/取关了谁
        .then((_) {
      if (mounted) {
        _load();
      }
    });
  }

  Widget _counts(UserProfile p) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppBrand.rMd),
        boxShadow: AppBrand.cardSm,
      ),
      child: Row(
        children: <Widget>[
          _CountCell(value: '${p.hostedCount}', label: '完成组局'),
          const _CellDivider(),
          _CountCell(value: '${p.joinedCount}', label: '完成参与'),
          const _CellDivider(),
          _CountCell(value: '${p.badges.length}', label: '勋章'),
        ],
      ),
    );
  }

  static Widget _flatCard({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppBrand.rMd),
          boxShadow: AppBrand.cardSm,
        ),
        child: child,
      );
}

/// 关注按钮：未关注是黑底实心，已关注是浅底描边。
class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.on, required this.busy, required this.onTap});

  final bool on;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: on ? AppBrand.primarySoft : AppBrand.black,
            borderRadius: BorderRadius.circular(999),
          ),
          child: busy
              ? SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: on ? AppBrand.primaryDeep : Colors.white,
                  ),
                )
              : Text(
                  on ? '已关注' : '+ 关注',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: on ? AppBrand.primaryDeep : Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

class _CountCell extends StatefulWidget {
  const _CountCell({required this.value, required this.label, this.onTap});

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  State<_CountCell> createState() => _CountCellState();
}

class _CountCellState extends State<_CountCell> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final column = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: _down ? AppBrand.primarySoft.withValues(alpha: 0.55) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            widget.value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppBrand.ink),
          ),
          const SizedBox(height: 2),
          Text(widget.label, style: const TextStyle(fontSize: 11.5, color: AppBrand.muted)),
        ],
      ),
    );
    return Expanded(
      child: widget.onTap == null
          ? column
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => setState(() => _down = true),
              onTapUp: (_) => setState(() => _down = false),
              onTapCancel: () => setState(() => _down = false),
              onTap: widget.onTap,
              child: column,
            ),
    );
  }
}

class _CellDivider extends StatelessWidget {
  const _CellDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 26, color: AppBrand.line);
}

/// 徽章小胶囊。
///
/// 字段类型写成 `model.Badge` 而不是 `Badge`：Flutter 的 material 里也有一个
/// `Badge`（那个画红点角标的小组件），不加前缀就得靠 `hide` 或别名硬扛。
class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.badge});

  final model.Badge badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: AppBrand.cardSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(badge.icon ?? '🎖️', style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 7),
          Text(
            badge.name,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppBrand.ink),
          ),
        ],
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.activity});

  final RecentActivity activity;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ActivityDetailPage(activityId: activity.id),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppBrand.rMd),
          boxShadow: AppBrand.cardSm,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: AppBrand.brand,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.local_activity_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    activity.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppBrand.ink),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${activity.roleLabel} · ${_day(activity.startTime)} · ${activity.statusLabel}',
                    style: const TextStyle(fontSize: 12, color: AppBrand.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFC3CFD9)),
          ],
        ),
      ),
    );
  }

  static String _day(DateTime? t) =>
      t == null ? '时间待定' : '${t.month}月${t.day}日';
}
