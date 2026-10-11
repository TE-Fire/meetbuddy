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
      appBar: AppBar(
        title: const Text('活动详情'),
        actions: <Widget>[
          if (a != null)
            IconButton(
              tooltip: a.favorited ? '取消收藏' : '收藏',
              onPressed: _acting
                  ? null
                  : () => _act(
                        () => context.read<AppScope>().activity.favorite(a.id, on: !a.favorited),
                        a.favorited ? '已取消收藏' : '已收藏',
                      ),
              icon: Icon(a.favorited ? Icons.star : Icons.star_border),
            ),
        ],
      ),
      body: _body(context),
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
    final scheme = Theme.of(context).colorScheme;
    final visual = CategoryVisual.of(a.category);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: <Widget>[
        // Hero 封面：从列表卡片无缝放大进场
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: AppBrand.card,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Hero(
              tag: 'activity-cover-${a.id}',
              child: SizedBox(
                height: 172,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(gradient: visual.gradient),
                      ),
                    ),
                    Positioned(
                      right: -34,
                      top: -34,
                      child: Blob(size: 140, color: Colors.white.withValues(alpha: 0.16)),
                    ),
                    Positioned(
                      left: -24,
                      bottom: -44,
                      child: Blob(size: 160, color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    Center(child: Icon(visual.icon, size: 64, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                a.title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.3, color: AppBrand.ink),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: visual.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(a.category, style: TextStyle(fontSize: 12.5, color: visual.color, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    a.statusLabel,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _statusColor(a.status)),
                  ),
                  if (a.creditRequired > 0) ...<Widget>[
                    const SizedBox(width: 8),
                    Text('信用分 ≥ ${a.creditRequired}', style: const TextStyle(fontSize: 12.5, color: AppBrand.muted)),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              _InfoTile(icon: Icons.schedule_rounded, label: '时间', value: '${_fmt(a.startTime)} — ${_fmt(a.endTime, withDate: false)}'),
              _InfoTile(icon: Icons.place_rounded, label: '地点', value: a.address),
              _InfoTile(
                icon: Icons.group_rounded,
                label: '名额',
                value: '${a.currentParticipants}/${a.maxParticipants}'
                    '${a.slotsLeft > 0 ? '（还剩 ${a.slotsLeft} 个）' : '（已满）'}',
              ),
              if (a.tags.isNotEmpty)
                _InfoTile(icon: Icons.local_offer_rounded, label: '标签', value: a.tags.join(' · ')),
              const SizedBox(height: 10),
              const Divider(),
              const SizedBox(height: 16),

              if ((a.description ?? '').isNotEmpty) ...<Widget>[
                const SectionHeader('活动介绍'),
                const SizedBox(height: 10),
                Text(a.description!, style: const TextStyle(fontSize: 14.5, height: 1.8, color: Color(0xFF4A5068))),
                const SizedBox(height: 20),
              ],

              const SectionHeader('组织者'),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: scheme.primary.withValues(alpha: 0.14),
                    child: Text((a.organizerNickname ?? '?').characters.first,
                        style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(a.organizerNickname ?? '匿名用户', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        if (a.organizer)
                          Text('就是你', style: TextStyle(fontSize: 12, color: scheme.outline)),
                      ],
                    ),
                  ),
                  if (a.organizer) const _OwnerBadge(),
                ],
              ),
              const SizedBox(height: 22),

              SectionHeader('已报名 ${a.participants.length} 人'),
              const SizedBox(height: 12),
              if (a.participants.isEmpty)
                Text('还没有人报名，你是第一个也说不定', style: TextStyle(fontSize: 13.5, color: scheme.outline))
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    for (final p in a.participants)
                      Chip(
                        avatar: CircleAvatar(
                          backgroundColor: scheme.primary.withValues(alpha: 0.14),
                          child: Text(p.nickname.characters.first,
                              style: TextStyle(fontSize: 12, color: scheme.primary, fontWeight: FontWeight.w700)),
                        ),
                        label: Text('${p.nickname}·${p.creditScore}'),
                        side: BorderSide(color: scheme.outlineVariant),
                        backgroundColor: Colors.white,
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
    final scheme = Theme.of(context).colorScheme;

    final List<Widget> buttons = <Widget>[];

    if (a.hasGroup) {
      buttons.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ChatRoomPage(groupId: a.groupId!, title: a.title),
              ),
            ),
            icon: const Icon(Icons.forum_outlined, size: 18),
            label: Text(a.signedUp || a.organizer ? '进入群聊' : '看看群聊'),
          ),
        ),
      );
    }

    if (a.canSignUp) {
      buttons.add(
        Expanded(
          flex: 2,
          child: PrimaryButton(
            text: '报名参加（还差 ${a.slotsLeft} 人）',
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
            style: OutlinedButton.styleFrom(foregroundColor: scheme.error, minimumSize: const Size.fromHeight(48)),
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
            style: OutlinedButton.styleFrom(foregroundColor: scheme.error, minimumSize: const Size.fromHeight(48)),
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
            onPressed: null,
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: AppBrand.card,
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

  static Color _statusColor(String status) => switch (status) {
        'OPEN' => const Color(0xFF22A45D),
        'FULL' => const Color(0xFFB26A00),
        'CANCELLED' => const Color(0xFFE5484D),
        _ => AppBrand.muted,
      };

  static String _fmt(DateTime? t, {bool withDate = true}) {
    if (t == null) {
      return '待定';
    }
    String two(int v) => v.toString().padLeft(2, '0');
    final hm = '${two(t.hour)}:${two(t.minute)}';
    return withDate ? '${t.month}月${t.day}日 $hm' : hm;
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppBrand.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: AppBrand.primary),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 36,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppBrand.muted)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w500, color: AppBrand.ink),
            ),
          ),
        ],
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
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SkeletonBox(height: 172, radius: 22),
          SizedBox(height: 18),
          SkeletonBox(width: 200, height: 22, radius: 8),
          SizedBox(height: 14),
          SkeletonBox(width: 130, height: 14, radius: 6),
          SizedBox(height: 22),
          SkeletonBox(height: 52, radius: 14),
          SizedBox(height: 10),
          SkeletonBox(height: 52, radius: 14),
          SizedBox(height: 10),
          SkeletonBox(height: 52, radius: 14),
        ],
      ),
    );
  }
}

class _OwnerBadge extends StatelessWidget {
  const _OwnerBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('我发起的', style: TextStyle(fontSize: 12, color: scheme.primary, fontWeight: FontWeight.w600)),
    );
  }
}
