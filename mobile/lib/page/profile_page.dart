import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_scope.dart';
import '../model/activity.dart';
import '../model/api_exception.dart';
import '../model/user.dart';
import '../model/user_profile.dart';
import '../state/activity_state.dart';
import '../state/session_state.dart';
import '../widget/activity_card.dart';
import '../widget/state_views.dart';
import '../widget/ui.dart';
import 'activity_detail_page.dart';
import 'badge_page.dart';
import 'buddy_page.dart';
import 'credit_log_page.dart';
import 'follow_list_page.dart';
import 'schedule_page.dart';

/// 兴趣标签建议池。
///
/// 与小程序侧 `pages/profile/profile.js` 的 `TAG_SUGGESTIONS` **必须一致**——
/// 两端是同一个用户的两副皮，标签口径不一致会出现"手机上删掉、小程序里还在"的错觉。
const List<String> kTagSuggestions = <String>[
  '剧本杀', '桌游', '飞盘', '篮球', '跑步', '健身', '探店', '美食', '咖啡',
  '露营', '徒步', '户外', '观影', '演唱会', '读书', '考研自习', '摄影', '绘画',
  '音乐', '旅行', '宠物', '汉服', '动漫', '电竞', 'K歌', '麻将',
];

/// 标签数量上限，与后端 `UserServiceImpl.MAX_TAGS` 对齐；自定义标签的字数上限同小程序。
const int kTagMax = 20;
const int kTagTextMax = 10;

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  /// 关注/粉丝计数的来源。
  ///
  /// 拿不到时保持 null 让界面回落成 0，而不是整页报错——计数是锦上添花，
  /// 不该因为它拉垮"我的"页；网络抖动时也保留上一次的值，不把已有数字打回 0。
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<ActivityState>().loadMine();
      _loadProfile();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final me = context.read<SessionState>().me;
    if (me == null) {
      return;
    }
    try {
      final p = await context.read<AppScope>().userProfile.profile(me.id);
      if (mounted) {
        setState(() => _profile = p);
      }
    } on ApiException {
      // 静默降级，见 _profile 的注释
    }
  }

  /// 打开关注 / 粉丝列表。回来后重拉计数——在那边可能关注/取关了谁。
  ///
  /// 数字还没拿到（`_profile == null`）时也让它进：列表页自己会拉，
  /// 而计数为 0 就禁止点击，会把"网络抖了一下"变成"这个入口是坏的"。
  Future<void> _openFollowList(BuildContext context, FollowTab tab) async {
    final me = context.read<SessionState>().me;
    if (me == null) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => FollowListPage(userId: me.id, initialTab: tab)),
    );
    if (mounted) {
      await _loadProfile();
    }
  }

  Future<void> _refresh() async {
    await Future.wait(<Future<void>>[
      context.read<ActivityState>().loadMine(),
      _loadProfile(),
    ]);
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

    return Scaffold(
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
        height: 420,
        child: NestedScrollView(
          headerSliverBuilder: (_, _) => <Widget>[
            SliverToBoxAdapter(child: _header(context, me, scope.usingMock, activities)),
          ],
          body: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
                child: TabBar(
                  controller: _tabs,
                  tabs: const <Widget>[
                    Tab(text: '我发起的'),
                    Tab(text: '我报名的'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  // 点击 tab 时 TabBarView 会跳转（不是滚），默认给的是硬切。
                  // physics 关掉横滑：这两页都是长列表，横滑手势会和列表的纵滑打架，
                  // 斜着滑的时候经常误触切 tab，用户想拉列表却翻了一页。
                  physics: const NeverScrollableScrollPhysics(),
                  children: <Widget>[
                    _TabFade(
                      controller: _tabs,
                      index: 0,
                      child: _list(context, activities.organized, '还没发起过活动', '去活动页点右下角，做第一个组局的人'),
                    ),
                    _TabFade(
                      controller: _tabs,
                      index: 1,
                      child: _list(context, activities.joined, '还没报名过活动', '看看活动流里有什么合适的'),
                    ),
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
  Widget _header(BuildContext context, User me, bool usingMock, ActivityState activities) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: Column(
        children: <Widget>[
          UserAvatar(nickname: me.nickname, avatar: me.avatar, size: 86, glow: true),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Flexible(
                child: Text(
                  me.nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppBrand.ink),
                ),
              ),
              const SizedBox(width: 8),
              SoftTag('信用分 ${me.creditScore}', tone: SoftTagTone.sky),
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
          TextButton.icon(
            onPressed: () => _openEditProfile(context, me),
            icon: const Icon(Icons.edit_outlined, size: 15),
            label: const Text('编辑资料'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(height: 8),

          // 数据卡：四格都可点。前两格进关注/粉丝列表（第 2 批接上），
          // 后两格切 Tab，省掉一次"看数字→滚下去找列表"的手指位移。
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppBrand.rMd),
              boxShadow: AppBrand.card,
            ),
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              children: <Widget>[
                _Stat(
                  value: '${_profile?.followingCount ?? 0}',
                  label: '关注',
                  onTap: () => _openFollowList(context, FollowTab.following),
                ),
                _Stat(
                  value: '${_profile?.followerCount ?? 0}',
                  label: '粉丝',
                  onTap: () => _openFollowList(context, FollowTab.followers),
                ),
                _Stat(
                  value: '${activities.organized.length}',
                  label: '我发起的',
                  onTap: () => _tabs.animateTo(0),
                ),
                _Stat(
                  value: '${activities.joined.length}',
                  label: '我报名的',
                  onTap: () => _tabs.animateTo(1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _tagCard(context, me),
          const SizedBox(height: 12),
          _entryGrid(context),
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

  Widget _tagCard(BuildContext context, User me) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppBrand.rMd),
        boxShadow: AppBrand.card,
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.local_offer_outlined, size: 15, color: AppBrand.primaryDeep),
              const SizedBox(width: 6),
              const Text(
                '兴趣标签',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppBrand.ink),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _openTagEditor(context, me),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  me.tags.isEmpty ? '去添加' : '编辑',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (me.tags.isEmpty)
            const Text(
              '还没有标签。填上兴趣，搭子匹配里有三成权重看它。',
              style: TextStyle(fontSize: 12.5, color: AppBrand.muted, height: 1.5),
            )
          else
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: me.tags.map((t) => SoftTag(t, tone: SoftTagTone.sky)).toList(),
            ),
        ],
      ),
    );
  }

  /// 高频入口四宫格。与小程序 `pages/profile/profile.wxml` 的 `.grid` 同口径：
  /// 日程 / 找搭子 / 勋章 / 信用明细。前三项在搬迁批次内，逐批接通；
  /// 未接通的给一句明确反馈，不做成点了没反应的死入口。
  Widget _entryGrid(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppBrand.rMd),
        boxShadow: AppBrand.card,
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: <Widget>[
          _EntryCell(
            icon: '🗓️',
            tint: AppBrand.primarySoft,
            label: '我的日程',
            onTap: () => _openSchedule(context),
          ),
          _EntryCell(
            icon: '🧭',
            tint: AppBrand.grassSoft,
            label: '找搭子',
            onTap: () => _openBuddy(context),
          ),
          _EntryCell(
            icon: '🎖️',
            tint: const Color(0xFFF3EAFE),
            label: '我的勋章',
            onTap: () => _openBadges(context),
          ),
          _EntryCell(
            icon: '🏆',
            tint: const Color(0xFFFFF3E0),
            label: '信用明细',
            onTap: () => _openCreditLog(context),
          ),
        ],
      ),
    );
  }

  void _openSchedule(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SchedulePage()),
    );
  }

  void _openBuddy(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BuddyPage()),
    );
  }

  void _openBadges(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BadgePage()),
    );
  }

  void _openCreditLog(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CreditLogPage()),
    );
  }

  Widget _list(BuildContext context, List<Activity> items, String emptyTitle, String emptyHint) {
    if (items.isEmpty) {
      return EmptyView(title: emptyTitle, hint: emptyHint, icon: Icons.event_note_outlined);
    }
    return RefreshIndicator(
      onRefresh: _refresh,
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
              await _refresh();
            }
          },
        ),
      ),
    );
  }

  Future<void> _openEditProfile(BuildContext context, User me) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(me: me),
    );
  }

  Future<void> _openTagEditor(BuildContext context, User me) async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TagEditorSheet(initial: me.tags),
    );
    if (result == null || !context.mounted) {
      return;
    }
    try {
      await context.read<SessionState>().updateTags(result);
      if (context.mounted) {
        _toast(context, '标签已更新');
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        _toast(context, e.message);
      }
    }
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

class _Stat extends StatefulWidget {
  const _Stat({required this.value, required this.label, this.onTap});

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  State<_Stat> createState() => _StatState();
}

class _StatState extends State<_Stat> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    // 数字"点数一下"：按下时整格轻微上浮 + 底色变浅。
    // 这格尺寸小、又紧挨着别的格，用缩放会跟邻居挤在一起，用位移更稳。
    final column = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: _down ? AppBrand.primarySoft.withValues(alpha: 0.55) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: <Widget>[
          Text(
            widget.value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppBrand.ink),
          ),
          const SizedBox(height: 3),
          Text(widget.label, style: const TextStyle(fontSize: 11.5, color: AppBrand.muted)),
        ],
      ),
    );
    if (widget.onTap == null) {
      return Expanded(child: column);
    }
    return Expanded(
      child: GestureDetector(
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

/// 四宫格的一格：emoji 图标 + 文案。与小程序 `pages/profile/profile.wxml` 的
/// `.gitem` 同口径（图标用柔色圆底，不用 Icon——小程序侧就是 emoji）。
class _EntryCell extends StatelessWidget {
  const _EntryCell({
    required this.icon,
    required this.tint,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final Color tint;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PressableScale(
        onTap: onTap,
        scale: 0.94,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(icon, style: const TextStyle(fontSize: 21)),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppBrand.ink2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 资料编辑面板。头像上传刻意没做——Flutter 侧选图要引原生插件，
/// 与"只引纯 Dart 包"的项目约束冲突，留到装机阶段单独定（见 docs/14 未做项）。
class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.me});

  final User me;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nick = TextEditingController(text: widget.me.nickname);
  late final TextEditingController _bio = TextEditingController(text: widget.me.bio ?? '');
  late int _gender = widget.me.gender ?? 0;
  bool _saving = false;

  static const List<String> _genderLabels = <String>['保密', '男', '女'];

  @override
  void dispose() {
    _nick.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nickname = _nick.text.trim();
    if (nickname.isEmpty) {
      _toast(context, '昵称不能为空');
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<SessionState>().updateProfile(
            nickname: nickname,
            bio: _bio.text.trim(),
            gender: _gender,
          );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _toast(context, e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: '编辑资料',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _FieldLabel('昵称'),
          AppField(
            controller: _nick,
            maxLength: 20,
            hintText: '想让别人怎么叫你',
          ),
          const SizedBox(height: 14),
          const _FieldLabel('简介'),
          AppField(
            controller: _bio,
            maxLines: 3,
            maxLength: 60,
            hintText: '一句话介绍自己，比如常出没的区域',
          ),
          const SizedBox(height: 14),
          const _FieldLabel('性别'),
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (int i = 0; i < _genderLabels.length; i++)
                ChoiceChip(
                  label: Text(_genderLabels[i]),
                  selected: _gender == i,
                  onSelected: (_) => setState(() => _gender = i),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: <Widget>[
              Expanded(
                child: GhostButton(
                  text: '取消',
                  height: 48,
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(text: '保存', height: 48, busy: _saving, onPressed: _save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 标签编辑面板。关闭时把结果回传给调用方，由它去落库——
/// 面板自己不碰 repository，保持"弹层只负责收集输入"。
class _TagEditorSheet extends StatefulWidget {
  const _TagEditorSheet({required this.initial});

  final List<String> initial;

  @override
  State<_TagEditorSheet> createState() => _TagEditorSheetState();
}

class _TagEditorSheetState extends State<_TagEditorSheet> {
  late final List<String> _tags = widget.initial.toList();
  final TextEditingController _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _toggle(String tag) {
    setState(() {
      if (_tags.contains(tag)) {
        _tags.remove(tag);
      } else if (_tags.length >= kTagMax) {
        _toast(context, '最多 $kTagMax 个');
      } else {
        _tags.add(tag);
      }
    });
  }

  void _addCustom() {
    final raw = _input.text.trim();
    if (raw.isEmpty) {
      return;
    }
    if (raw.length > kTagTextMax) {
      _toast(context, '标签最多 $kTagTextMax 字');
      return;
    }
    if (_tags.contains(raw)) {
      _input.clear();
      setState(() {});
      return;
    }
    if (_tags.length >= kTagMax) {
      _toast(context, '最多 $kTagMax 个');
      return;
    }
    setState(() {
      _tags.add(raw);
      _input.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: '兴趣标签',
      subtitle: '最多 $kTagMax 个，自定义标签不超过 $kTagTextMax 字',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _FieldLabel('已选'),
          if (_tags.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                '还没选任何标签，从下面挑几个或自己写。',
                style: TextStyle(fontSize: 12.5, color: AppBrand.muted),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final t in _tags)
                  InputChip(
                    label: Text(t),
                    onDeleted: () => _toggle(t),
                    deleteIcon: const Icon(Icons.close_rounded, size: 15),
                    backgroundColor: AppBrand.primarySoft,
                    side: BorderSide.none,
                    labelStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppBrand.primaryDeep,
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          const _FieldLabel('加一个自己的'),
          Row(
            children: <Widget>[
              Expanded(
                child: AppField(
                  controller: _input,
                  maxLength: kTagTextMax,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addCustom(),
                  hintText: '例如：夜跑',
                ),
              ),
              const SizedBox(width: 10),
              GhostButton(text: '添加', height: 46, onPressed: _addCustom),
            ],
          ),
          const SizedBox(height: 16),
          const _FieldLabel('猜你喜欢'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final t in kTagSuggestions)
                FilterChip(
                  label: Text(t),
                  selected: _tags.contains(t),
                  onSelected: (_) => _toggle(t),
                ),
            ],
          ),
          const SizedBox(height: 22),
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
                  text: '保存',
                  height: 48,
                  onPressed: () => Navigator.of(context).pop(_tags),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 弹层外壳：顶部把手 + 标题 + 可滚动内容，键盘弹出时整体上推。
class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        // 高度上限压在 88%：面板本身内容再多也要留出一点背景，
        // 否则"这是个弹层"的层级感就没了。
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppBrand.line,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppBrand.ink,
                          ),
                        ),
                        if (subtitle != null) ...<Widget>[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            style: const TextStyle(fontSize: 12, color: AppBrand.muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: '关闭',
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: child,
              ),
            ),
          ],
        ),
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
      child: Text(
        text,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppBrand.ink2),
      ),
    );
  }
}

/// Tab 内容切换时给一点"进场"，而不是硬切。
///
/// 挂 [TabController.animation] 而不是自己维护一个 AnimationController：`_tabs.animation`
/// 在点击和滑动两种触发下都会走 0 → 1 的完整过程，自己写就要分别接 onTap 与 onChanged，
/// 两处状态不同步时会出现"指示器到位了、内容还没动"。
///
/// 只在**自己这一页**成为选中项的那一刻淡入 + 轻微上浮，且位移只有 6px：
/// tab 切换是高频动作，位移一大就会像每次都在"翻页"，越用越烦。
class _TabFade extends StatelessWidget {
  const _TabFade({required this.controller, required this.index, required this.child});

  final TabController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller.animation!,
      builder: (context, c) {
        // 距离本 tab 越近，越接近 1。
        final d = (controller.animation!.value - index).abs().clamp(0.0, 1.0);
        final t = 1 - d;
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 6 * d), child: c),
        );
      },
      child: child,
    );
  }
}
