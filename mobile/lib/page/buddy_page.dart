import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/buddy.dart';
import '../model/api_exception.dart';
import '../state/activity_state.dart';
import '../state/buddy_state.dart';
import '../widget/state_views.dart';
import '../widget/ui.dart';

/// 找搭子。
///
/// 与小程序 `pages/buddy/buddy` 同口径：双页签（匹配结果 / 我的需求）、演示坐标用北京国贸、
/// 半径可切换、发布需求面板。匹配分算法不在前端——后端按"标签重合 + 距离 + 信用分"加权排序，
/// 前端只负责展示 `score`（转百分比）与后端给的 `reason`。
///
/// 与小程序的一处差异：小程序匹配卡上的"私聊 TA"走 `chat-room?peerId=`，Flutter 侧
/// `ChatRoomPage` 目前只认 `groupId`（DM 页尚未落地），所以这枚按钮先给明确反馈，等 DM 页接通。
class BuddyPage extends StatefulWidget {
  const BuddyPage({super.key});

  @override
  State<BuddyPage> createState() => _BuddyPageState();
}

class _BuddyPageState extends State<BuddyPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final state = context.read<BuddyState>();
      state.loadMatches();
      state.loadMine();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('找个搭子')),
      body: SkyBackground(
        height: 260,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: AppBrand.card,
                ),
                padding: const EdgeInsets.all(5),
                child: Row(
                  children: <Widget>[
                    _TabPill(index: 0, controller: _tabs, label: '找搭子'),
                    _TabPill(index: 1, controller: _tabs, label: '我的需求'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                physics: const NeverScrollableScrollPhysics(),
                children: const <Widget>[
                  _MatchTab(),
                  _MineTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 两个页签的胶囊滑块。与全局 TabBar 同一节奏，但这两个页签文字长度一致、数量固定，
/// 自己画更轻，不必挂全局 TabBar 主题。
class _TabPill extends StatelessWidget {
  const _TabPill({required this.index, required this.controller, required this.label});

  final int index;
  final TabController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (controller.index != index) {
            controller.animateTo(index);
          }
        },
        child: AnimatedBuilder(
          animation: controller.animation!,
          builder: (ctx, _) {
            final selected = (controller.animation!.value - index).abs() < 0.5;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: selected ? AppBrand.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppBrand.ink2,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 找搭子：匹配结果。
class _MatchTab extends StatelessWidget {
  const _MatchTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BuddyState>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
      children: <Widget>[
        _GeoBar(),
        const SizedBox(height: 12),
        if (state.matchLoading)
          const _CenterCard(title: '正在算匹配分…')
        else if (state.matchError != null)
          ErrorView(message: state.matchError!, onRetry: state.loadMatches)
        else if (state.matches.isEmpty)
          const _CenterCard(
            icon: Icons.explore_off_outlined,
            title: '这个半径内还没有找搭子的人',
            hint: '把半径调大一点，或者去「我的需求」发布一个',
          )
        else
          for (final m in state.matches) _MatchCard(match: m),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _GeoBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<BuddyState>();
    final radiusLabel = state.radius >= 1
        ? '${state.radius.toInt()} km'
        : '${(state.radius * 1000).toInt()} m';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppBrand.rMd),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: <Widget>[
          const Icon(Icons.location_on_outlined, size: 16, color: AppBrand.primaryDeep),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '演示坐标·北京国贸 · 半径 $radiusLabel',
              style: const TextStyle(fontSize: 12.5, color: AppBrand.ink2),
            ),
          ),
          GestureDetector(
            onTap: () => _changeRadius(context),
            child: Text(
              '改半径 ›',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppBrand.primaryDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeRadius(BuildContext context) async {
    final state = context.read<BuddyState>();
    final picked = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _RadiusSheet(current: state.radius),
    );
    if (picked != null && context.mounted) {
      await state.changeRadius(picked);
    }
  }
}

class _RadiusSheet extends StatelessWidget {
  const _RadiusSheet({required this.current});

  final double current;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 6),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: AppBrand.line, borderRadius: BorderRadius.circular(99)),
          ),
          const SizedBox(height: 14),
          const Text('匹配半径', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppBrand.ink)),
          const SizedBox(height: 14),
          for (final r in BuddyState.radiusOptions)
            ListTile(
              title: Text(r >= 1 ? '$r 公里' : '${(r * 1000).toInt()} 米'),
              trailing: r == current ? const Icon(Icons.check_rounded, color: AppBrand.primary) : null,
              onTap: () => Navigator.of(context).pop(r),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match});

  final BuddyMatch match;

  @override
  Widget build(BuildContext context) {
    final scorePct = '${match.score.round()}%';
    final distanceText = match.distance < 1
        ? (match.distance < 0.1 ? '不到 100 m' : '${(match.distance * 1000).toInt()} m')
        : '${match.distance.toStringAsFixed(1)} km';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppBrand.rLg),
        boxShadow: AppBrand.card,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              UserAvatar(nickname: match.nickname, avatar: match.avatar, size: 44, shape: UserAvatarShape.circle),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(match.nickname, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppBrand.ink)),
                    const SizedBox(height: 3),
                    Text('信用分 ${match.creditScore} · $distanceText', style: const TextStyle(fontSize: 12, color: AppBrand.muted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(scorePct, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppBrand.primaryDeep)),
                  const Text('匹配度', style: TextStyle(fontSize: 11, color: AppBrand.muted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(match.title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppBrand.ink)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              SoftTag(match.category, tone: SoftTagTone.grass),
              if (match.timeRange != null) SoftTag(match.timeRange!, tone: SoftTagTone.plain),
              for (final t in match.commonTags) SoftTag(t, tone: SoftTagTone.sky),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Icon(Icons.lightbulb_outline_rounded, size: 15, color: AppBrand.grassDeep),
              const SizedBox(width: 6),
              Expanded(
                child: Text(match.reason, style: const TextStyle(fontSize: 12.5, color: AppBrand.ink2)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _dm(context, match),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
              label: const Text('私聊 TA'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppBrand.primaryDeep,
                side: const BorderSide(color: AppBrand.primary, width: 1.5),
                minimumSize: const Size(0, 44),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _dm(BuildContext context, BuddyMatch m) {
    // DM 页 Flutter 侧尚未落地（ChatRoomPage 只认 groupId），先给明确反馈，
    // 不做成点了没反应的死入口。接通后改成 push ChatRoomPage(peerId: m.userId)。
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('私聊 ${m.nickname} 即将上线')),
    );
  }
}

/// 我的需求。
class _MineTab extends StatelessWidget {
  const _MineTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BuddyState>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
      children: <Widget>[
        if (state.mineLoading)
          const _CenterCard(title: '正在加载…')
        else if (state.mineError != null)
          ErrorView(message: state.mineError!, onRetry: state.loadMine)
        else if (state.mine.isEmpty)
          const _CenterCard(
            icon: Icons.note_add_outlined,
            title: '还没有发布过搭子需求',
            hint: '发布后，附近标签相投的人就能匹配到你',
          )
        else
          for (final b in state.mine) _MineCard(request: b),
        const SizedBox(height: 14),
        PrimaryButton(
          text: '发布搭子需求',
          height: 50,
          onPressed: () => showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const _PublishSheet(),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _MineCard extends StatelessWidget {
  const _MineCard({required this.request});

  final BuddyRequest request;

  @override
  Widget build(BuildContext context) {
    final open = request.open;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppBrand.rLg),
        boxShadow: AppBrand.card,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(request.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppBrand.ink)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: open ? AppBrand.primarySoft : const Color(0xFFEDEFF1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  open ? '开放中' : '已关闭',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: open ? AppBrand.primaryDeep : AppBrand.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              SoftTag(request.category, tone: SoftTagTone.grass),
              if (request.timeRange != null) SoftTag(request.timeRange!, tone: SoftTagTone.plain),
              for (final t in request.tags) SoftTag(t, tone: SoftTagTone.sky),
            ],
          ),
          if (request.description != null && request.description!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(request.description!, style: const TextStyle(fontSize: 13, height: 1.6, color: AppBrand.ink2)),
          ],
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  request.createdAt == null ? '' : '发布于 ${_fmt(request.createdAt!)}',
                  style: const TextStyle(fontSize: 11.5, color: AppBrand.muted),
                ),
              ),
              if (open)
                GestureDetector(
                  onTap: () => _confirmClose(context, request.id),
                  child: Text(
                    '关闭需求',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClose(BuildContext context, int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关闭需求'),
        content: const Text('关闭后不再参与匹配，确定吗？'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('再想想')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<BuddyState>().close(id);
    }
  }

  static String _fmt(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.month}月${t.day}日 ${two(t.hour)}:${two(t.minute)}';
  }
}

/// 发布需求面板。与活动发布页同款 sheet 外壳与输入框，但字段更简单——
/// 搭子需求没有人数上限和截止时间（见 docs/02），所以没有人数步进和日期面板。
class _PublishSheet extends StatefulWidget {
  const _PublishSheet();

  @override
  State<_PublishSheet> createState() => _PublishSheetState();
}

class _PublishSheetState extends State<_PublishSheet> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _time = TextEditingController();
  final TextEditingController _desc = TextEditingController();
  String _category = ActivityState.categories.first;
  final List<String> _tags = <String>[];
  bool _publishing = false;

  @override
  void dispose() {
    _title.dispose();
    _time.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_tags.contains(tag)) {
        _tags.remove(tag);
      } else {
        _tags.add(tag);
      }
    });
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('至少写两个字')));
      return;
    }
    setState(() => _publishing = true);
    try {
      await context.read<BuddyState>().create(
            title: title,
            description: _desc.text.trim(),
            category: _category,
            timeRange: _time.text.trim(),
            tags: List<String>.from(_tags),
          );
      if (context.mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        setState(() => _publishing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: AppBrand.line, borderRadius: BorderRadius.circular(99)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: Text('发布搭子需求', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppBrand.ink)),
                ),
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, size: 20)),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _FieldLabel('想找什么样的搭子'),
                  AppField(
                    controller: _title,
                    maxLength: 30,
                    hintText: '例：周末剧本杀差两人',
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel('分类'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final c in ActivityState.categories)
                        ChoiceChip(
                          label: Text(c),
                          selected: _category == c,
                          onSelected: (_) => setState(() => _category = c),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel('大概什么时候（选填）'),
                  AppField(
                    controller: _time,
                    maxLength: 20,
                    hintText: '例：周末下午 / 工作日晚间',
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel('标签（可多选）'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final t in ActivityState.tagPool)
                        FilterChip(
                          label: Text(t),
                          selected: _tags.contains(t),
                          onSelected: (_) => _toggleTag(t),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel('补充说明（选填）'),
                  AppField(
                    controller: _desc,
                    maxLines: 3,
                    maxLength: 200,
                    hintText: '想玩什么本、什么水平，写清楚匹配更准',
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: GhostButton(
                          text: '取消',
                          height: 48,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PrimaryButton(
                          text: '发布',
                          height: 48,
                          busy: _publishing,
                          onPressed: _submit,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppBrand.ink2)),
    );
  }
}

/// 列表中间的空态 / 加载态卡片。
class _CenterCard extends StatelessWidget {
  const _CenterCard({this.icon = Icons.hourglass_empty_rounded, required this.title, this.hint});

  final IconData icon;
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 30),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppBrand.rLg),
        boxShadow: AppBrand.cardSm,
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 40, color: AppBrand.muted),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppBrand.ink)),
          if (hint != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(hint!, style: const TextStyle(fontSize: 12, color: AppBrand.muted), textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
