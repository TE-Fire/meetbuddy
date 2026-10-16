import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_scope.dart';
import '../model/activity.dart';
import '../model/api_exception.dart';
import '../state/activity_state.dart';
import '../widget/category_visual.dart';
import '../widget/state_views.dart';
import '../widget/ui.dart';
import 'chat_room_page.dart';
import 'user_profile_page.dart';
import 'activity_edit_page.dart';

class ActivityDetailPage extends StatefulWidget {
  const ActivityDetailPage({super.key, required this.activityId});

  final int activityId;

  @override
  State<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<ActivityDetailPage> {
  Activity? _activity;
  String? _error;
  bool _loading = true;
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
      final a = await context.read<AppScope>().activity.detail(widget.activityId);
      if (!mounted) return;
      setState(() {
        _activity = a;
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

  /// 统一的"改一下再刷新"流程：执行动作 → 重新拉详情 → 同步给列表页。
  /// 不让本地改状态再乐观更新，是因为名额、状态、参与者摘要都是服务端算的，
  /// 本地重算容易和真实值漂移。
  Future<void> _act(Future<void> Function() action, String okText) async {
    setState(() => _acting = true);
    try {
      await action();
      await _load();
      if (!mounted) return;
      final a = _activity;
      if (a != null) {
        context.read<ActivityState>().patch(a);
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(okText)));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Theme.of(context).colorScheme.error),
      );
    } finally {
      if (mounted) {
        setState(() => _acting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _activity;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('活动详情'),
        actions: <Widget>[
          if (a != null && a.organizer && (a.status == 'OPEN' || a.status == 'FULL'))
            // 编辑入口：与后端约束一致，只有未开始（OPEN/FULL）的组织者能改。
            // 已开始/结束的活动不进这里——进了也是被后端 400 挡回来。
            IconButton(
              tooltip: '编辑活动',
              onPressed: _acting
                  ? null
                  : () async {
                      final changed = await Navigator.of(context).push(
                        MaterialPageRoute<bool>(
                          builder: (_) => ActivityEditPage(activityId: a.id),
                        ),
                      );
                      if (changed == true && context.mounted) {
                        await _load();
                        final latest = _activity;
                        if (latest != null && context.mounted) {
                          context.read<ActivityState>().patch(latest);
                        }
                      }
                    },
              icon: const Icon(Icons.edit_outlined),
            ),
          if (a != null)
            // 收藏是"翻转状态"而不是"按住"，所以弹一下而不是缩一下：
            // 点完只换个图标形状的话，用户会怀疑到底点上没有。
            BouncyTap(
              enabled: !_acting,
              onTap: () => _act(
                () => context.read<AppScope>().activity.favorite(a.id, on: !a.favorited),
                a.favorited ? '已取消收藏' : '已收藏',
              ),
              child: IconButton(
                tooltip: a.favorited ? '取消收藏' : '收藏',
                onPressed: null,
                icon: Icon(
                  a.favorited ? Icons.star : Icons.star_border,
                  color: a.favorited ? const Color(0xFFF5A623) : null,
                ),
              ),
            ),
        ],
      ),
      body: SkyBackground(height: 300, child: _body(context)),
      bottomNavigationBar: a == null ? null : _bottomBar(context, a),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const _DetailSkeleton();
    }
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    final a = _activity!;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: <Widget>[
        // Hero 封面：从列表卡片无缝放大进场
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppBrand.rLg),
              boxShadow: AppBrand.card,
            ),
            child: Hero(
              tag: 'activity-cover-${a.id}',
              child: ActivityCover(
                category: a.category,
                coverUrl: a.coverUrl,
                height: 190,
                radius: AppBrand.rLg,
                badge: a.status == 'OPEN' ? '🔥 热门局' : a.statusLabel,
                badgeColor: a.status == 'OPEN' ? AppBrand.black : const Color(0xFFB26A00),
                pins: <MapPinSpec>[
                  MapPinSpec(
                    a.slotsLeft > 0 ? '还差 ${a.slotsLeft} 人' : '已满员',
                    0.30,
                    0.30,
                    accent: true,
                  ),
                ],
                stickerAngle: 0.16,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                a.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.32,
                  color: AppBrand.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${a.organizerNickname ?? '匿名用户'} 发起 · ${_fmt(a.startTime)}',
                style: const TextStyle(fontSize: 13, color: AppBrand.muted),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  SoftTag(a.category, tone: SoftTagTone.grass),
                  SoftTag(a.statusLabel, tone: SoftTagTone.sky),
                  if (a.creditRequired > 0) SoftTag('信用分 ≥ ${a.creditRequired}'),
                ],
              ),
              const SizedBox(height: 18),

              // 信息卡：白底大圆角，行与行之间细线分隔
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppBrand.rLg),
                  boxShadow: AppBrand.card,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  children: <Widget>[
                    _InfoRow(
                      icon: Icons.schedule_rounded,
                      title: '${_fmt(a.startTime)} — ${_fmt(a.endTime, withDate: false)}',
                      sub: _durationText(a),
                    ),
                    _InfoRow(
                      icon: Icons.place_rounded,
                      title: a.address,
                      sub: '集合点以群内通知为准',
                      tone: SoftTagTone.grass,
                    ),
                    _InfoRow(
                      icon: Icons.group_rounded,
                      title: '${a.currentParticipants}/${a.maxParticipants}'
                          '${a.slotsLeft > 0 ? ' · 还剩 ${a.slotsLeft} 个名额' : ' · 已满'}',
                      sub: '报名后自动进群，方便对时间和地点',
                      tone: SoftTagTone.warm,
                    ),
                    if (a.tags.isNotEmpty)
                      _InfoRow(
                        icon: Icons.local_offer_rounded,
                        title: a.tags.join(' · '),
                        sub: '发起人贴的标签',
                        last: true,
                      )
                    else
                      _InfoRow(
                        icon: Icons.shield_moon_outlined,
                        title: '无门槛或门槛见上方',
                        sub: '信用分不足会被拒绝报名',
                        last: true,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              if ((a.description ?? '').isNotEmpty) ...<Widget>[
                const SectionHeader('活动介绍'),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppBrand.rMd),
                    boxShadow: AppBrand.cardSm,
                  ),
                  child: Text(
                    a.description!,
                    style: const TextStyle(fontSize: 14.5, height: 1.85, color: AppBrand.ink2),
                  ),
                ),
                const SizedBox(height: 22),
              ],

              const SectionHeader('组织者'),
              const SizedBox(height: 12),
              // 整卡可点进主页（小程序同款）。organizerId 为空时不可点——
              // 那时点下去只会推出一个"用户不存在"，比不可点更糟。
              PressableScale(
                onTap: a.organizerId == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => UserProfilePage(userId: a.organizerId!),
                          ),
                        ),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppBrand.rMd),
                    boxShadow: AppBrand.cardSm,
                  ),
                  child: Row(
                    children: <Widget>[
                      UserAvatar(
                        nickname: a.organizerNickname ?? '?',
                        avatar: a.organizerAvatar,
                        size: 42,
                        shape: UserAvatarShape.circle,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              a.organizerNickname ?? '匿名用户',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                            if (a.organizer)
                              const Text(
                                '就是你',
                                style: TextStyle(fontSize: 12, color: AppBrand.muted),
                              ),
                          ],
                        ),
                      ),
                      if (a.organizer) const _OwnerBadge(),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFFC3CFD9)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              SectionHeader(
                '已报名 ${a.participants.length} 人',
                trailing: Text(
                  '上限 ${a.maxParticipants} 人',
                  style: const TextStyle(fontSize: 12, color: AppBrand.muted),
                ),
              ),
              const SizedBox(height: 14),
              if (a.participants.isEmpty)
                Text(
                  '还没有人报名，你是第一个也说不定',
                  style: TextStyle(fontSize: 13.5, color: Theme.of(context).colorScheme.outline),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    for (final p in a.participants)
                      _ParticipantPill(
                        nickname: p.nickname,
                        avatar: p.avatar,
                        credit: p.creditScore,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => UserProfilePage(userId: p.userId),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bottomBar(BuildContext context, Activity a) {
    final scope = context.read<AppScope>();

    final List<Widget> buttons = <Widget>[];

    if (a.hasGroup) {
      buttons.add(
        Expanded(
          flex: 2,
          child: GhostButton(
            text: a.signedUp || a.organizer ? '进入群聊' : '看看群聊',
            icon: Icons.forum_outlined,
            height: 50,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                // 活动已取消/结束时直接把输入框置灰（M4 的 readonly 语义），
                // 不必等用户发一条被 3104 拒回来才知道
                builder: (_) => ChatRoomPage(groupId: a.groupId!, title: a.title, readonly: a.isClosed),
              ),
            ),
          ),
        ),
      );
    }

    if (a.canSignUp) {
      buttons.add(
        Expanded(
          flex: 2,
          child: PrimaryButton(
            text: '报名参加',
            height: 50,
            onPressed: _acting ? null : () => _act(() => scope.activity.signUp(a.id), '报名成功，已加入群聊'),
            busy: _acting,
          ),
        ),
      );
    } else if (a.canCancelSignUp) {
      buttons.add(
        Expanded(
          flex: 2,
          child: OutlinedButton(
            onPressed: _acting ? null : () => _act(() => scope.activity.cancelSignUp(a.id), '已取消报名'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              backgroundColor: Colors.white,
              minimumSize: const Size(0, 50),
              side: const BorderSide(color: AppBrand.line, width: 1.5),
            ),
            child: const Text('取消报名'),
          ),
        ),
      );
    } else if (a.organizer && !a.isClosed) {
      buttons.add(
        Expanded(
          flex: 2,
          child: OutlinedButton(
            onPressed: _acting ? null : () => _confirmCancel(context, a),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              backgroundColor: Colors.white,
              minimumSize: const Size(0, 50),
              side: const BorderSide(color: AppBrand.line, width: 1.5),
            ),
            child: const Text('取消活动'),
          ),
        ),
      );
    } else {
      buttons.add(
        Expanded(
          flex: 2,
          child: PrimaryButton(
            text: a.status == 'FULL' ? '名额已满' : a.statusLabel,
            height: 50,
            onPressed: null,
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 14),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x1F1F6696), blurRadius: 30, offset: Offset(0, 14)),
          ],
        ),
        child: Row(
          children: <Widget>[
            for (int i = 0; i < buttons.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 10),
              buttons[i],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, Activity a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('取消这个活动？'),
        content: const Text('群聊不会被解散，但会转为只读，所有成员会收到通知。已经报名的信用分不会因此退还。'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('再想想')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认取消')),
        ],
      ),
    );
    if (ok != true || !mounted) {
      return;
    }
    await _act(() => context.read<AppScope>().activity.cancelActivity(a.id), '活动已取消，群聊转为只读');
  }

  static String _durationText(Activity a) {
    final s = a.startTime;
    final e = a.endTime;
    if (s == null || e == null) {
      return '时长待定';
    }
    final mins = e.difference(s).inMinutes;
    if (mins <= 0) {
      return '时长待定';
    }
    if (mins < 60) {
      return '约 $mins 分钟';
    }
    final h = mins / 60;
    return '约 ${h == h.roundToDouble() ? h.round() : h.toStringAsFixed(1)} 小时';
  }

  static String _fmt(DateTime? t, {bool withDate = true}) {
    if (t == null) {
      return '待定';
    }
    String two(int v) => v.toString().padLeft(2, '0');
    final hm = '${two(t.hour)}:${two(t.minute)}';
    return withDate ? '${t.month}月${t.day}日 $hm' : hm;
  }
}

/// 信息行：左圆角图标 + 主文案 + 副文案。
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.sub,
    this.tone = SoftTagTone.sky,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String sub;
  final SoftTagTone tone;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      SoftTagTone.sky => (AppBrand.primarySoft, AppBrand.primaryDeep),
      SoftTagTone.grass => (AppBrand.grassSoft, const Color(0xFF4E8F3C)),
      SoftTagTone.warm => (const Color(0xFFFFF3E8), const Color(0xFFC77A2A)),
      SoftTagTone.plain => (const Color(0xFFF1F5F8), AppBrand.ink2),
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AppBrand.line)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, size: 19, color: fg),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppBrand.ink),
                ),
                const SizedBox(height: 3),
                Text(sub, style: const TextStyle(fontSize: 11.5, color: AppBrand.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 详情的报名人：小药丸（首字头像 + 昵称 + 信用分）。整枚可点进对方主页。
class _ParticipantPill extends StatelessWidget {
  const _ParticipantPill({
    required this.nickname,
    required this.avatar,
    required this.credit,
    required this.onTap,
  });

  final String nickname;
  final String? avatar;
  final int credit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: AppBrand.cardSm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            UserAvatar(
              nickname: nickname,
              avatar: avatar,
              size: 26,
              shape: UserAvatarShape.circle,
            ),
            const SizedBox(width: 8),
            Text(
              nickname,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppBrand.ink),
            ),
            const SizedBox(width: 6),
            Text('$credit', style: const TextStyle(fontSize: 11, color: AppBrand.muted)),
          ],
        ),
      ),
    );
  }
}

/// 详情页加载骨架。
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SkeletonBox(height: 190, radius: 26),
          SizedBox(height: 18),
          SkeletonBox(width: 200, height: 22, radius: 8),
          SizedBox(height: 14),
          SkeletonBox(width: 130, height: 14, radius: 6),
          SizedBox(height: 22),
          SkeletonBox(height: 68, radius: 20),
          SizedBox(height: 10),
          SkeletonBox(height: 68, radius: 20),
          SizedBox(height: 10),
          SkeletonBox(height: 68, radius: 20),
        ],
      ),
    );
  }
}

class _OwnerBadge extends StatelessWidget {
  const _OwnerBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppBrand.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        '我发起的',
        style: TextStyle(fontSize: 12, color: AppBrand.primaryDeep, fontWeight: FontWeight.w700),
      ),
    );
  }
}
