import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_scope.dart';
import '../model/api_exception.dart';
import '../model/page_data.dart';
import '../model/user_brief.dart';
import '../widget/state_views.dart';
import '../widget/ui.dart';
import 'user_profile_page.dart';

/// 关注 / 粉丝两个 tab。规则见 `docs/13-关注关系.md`。
enum FollowTab { following, followers }

/// 关注 / 粉丝列表。
///
/// 入口：他人主页（以及"我的"页）的「关注 / 粉丝」计数。两个 tab 各是一个独立列表，
/// 各自维护分页游标——共用一个游标的话，切 tab 会把另一个的位置也带走，
/// 切回来看到的是"第一页中途接上第二页"。
class FollowListPage extends StatelessWidget {
  const FollowListPage({super.key, required this.userId, this.initialTab = FollowTab.following});

  final int userId;
  final FollowTab initialTab;

  @override
  Widget build(BuildContext context) {
    return _FollowListScope(
      userId: userId,
      child: DefaultTabController(
        length: 2,
        initialIndex: initialTab.index,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('关注与粉丝'),
            bottom: const TabBar(
              tabs: <Widget>[
                Tab(text: '关注'),
                Tab(text: '粉丝'),
              ],
            ),
          ),
          body: const SkyBackground(
            // 两个 tab 都是可滚动列表。横滑手势和纵滑抢事件，斜着滑一下列表就翻页了，
            // 所以关掉手势切页，只留点 tab 这一条路径（点 tab 的内容过渡见 _TabFade）。
            child: TabBarView(
              physics: NeverScrollableScrollPhysics(),
              children: <Widget>[
                _FollowListBody(tab: FollowTab.following),
                _FollowListBody(tab: FollowTab.followers),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 一个 tab 的列表本体。两个 tab 各建一份，各持自己的分页游标与滚动位置。
class _FollowListBody extends StatefulWidget {
  const _FollowListBody({required this.tab});

  final FollowTab tab;

  @override
  State<_FollowListBody> createState() => _FollowListBodyState();
}

class _FollowListBodyState extends State<_FollowListBody> with AutomaticKeepAliveClientMixin {
  final List<UserBrief> _rows = <UserBrief>[];
  final ScrollController _scroll = ScrollController();

  bool _loading = true;
  bool _loadingMore = false;
  bool _finished = false;
  int _page = 1;
  String? _error;

  static const int _size = 20;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
      _load(reset: false);
    }
  }

  Future<void> _load({required bool reset}) async {
    if (!reset && (_loadingMore || _finished || _loading)) {
      return;
    }
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    final repo = context.read<AppScope>().userProfile;
    final page = reset ? 1 : _page + 1;
    final userId = _FollowListScope.of(context);
    try {
      final PageData<UserBrief> res = widget.tab == FollowTab.following
          ? await repo.following(userId, page: page, size: _size)
          : await repo.followers(userId, page: page, size: _size);
      if (!mounted) return;
      setState(() {
        if (reset) {
          _rows
            ..clear()
            ..addAll(res.list);
        } else {
          _rows.addAll(res.list);
        }
        _page = page;
        _finished = res.list.length < _size;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 要求

    // 骨架 → 真数据这一下做淡入，否则是硬切：灰色方块消失的同一帧里整行内容突然出现，
    // 眼睛会把它读成"闪了一下"。包在最外层（覆盖空态、错误态、列表三种），
    // key 绑在状态上，切状态时重播、切 tab 时不重播（列表被 KeepAlive 保住了）。
    final inner = _body();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      // 旧内容先淡出 140ms，新内容不用等——叠着走比排队走快，且不会有空白帧。
      reverseDuration: const Duration(milliseconds: 140),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: Transform.translate(offset: Offset(0, 6 * (1 - anim.value)), child: child),
      ),
      child: KeyedSubtree(
        key: ValueKey<String>(_loading ? 'loading' : (_rows.isEmpty ? 'empty' : 'rows')),
        child: inner,
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const SingleChildScrollView(child: SkeletonList(rows: 4));
    }
    if (_error != null && _rows.isEmpty) {
      return ErrorView(message: _error!, onRetry: () => _load(reset: true));
    }
    if (_rows.isEmpty) {
      final following = widget.tab == FollowTab.following;
      return RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          children: <Widget>[
            const SizedBox(height: 70),
            EmptyView(
              title: following ? '还没有关注任何人' : '还没有粉丝',
              hint: following ? '去活动里认识几个搭子吧' : '多发起活动，会有人来关注你',
              icon: following ? Icons.person_add_alt_outlined : Icons.groups_outlined,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        itemCount: _rows.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          if (i == _rows.length) {
            return LoadMoreFooter(
              loading: _loadingMore,
              hasMore: !_finished,
              onLoad: () => _load(reset: false),
            );
          }
          return _UserRow(user: _rows[i]);
        },
      ),
    );
  }
}

/// 把 userId 递给两个 tab 的列表。
///
/// 用 InheritedWidget 而不是给 `_FollowListBody` 加构造参数：`TabBarView` 的 children
/// 是 const 列表，加了参数就得在这里 `const` 掉——而 InheritedWidget 天然支持
/// 祖先变化时子树重建，将来从"看一眼别人"扩成"在列表里直接关注"时不用改结构。
class _FollowListScope extends InheritedWidget {
  const _FollowListScope({required this.userId, required super.child});

  final int userId;

  static int of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_FollowListScope>();
    assert(scope != null, 'FollowListPage 必须包一层 _FollowListScope');
    return scope!.userId;
  }

  @override
  bool updateShouldNotify(_FollowListScope old) => old.userId != userId;
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user});

  final UserBrief user;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => UserProfilePage(userId: user.userId)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppBrand.rMd),
          boxShadow: AppBrand.cardSm,
        ),
        child: Row(
          children: <Widget>[
            UserAvatar(nickname: user.nickname, avatar: user.avatar, size: 44, shape: UserAvatarShape.circle),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    user.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      // 封禁是状态不是消失：仍然列出来，只是压暗
                      color: user.banned ? AppBrand.muted : AppBrand.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '信用分 ${user.creditScore}${user.banned ? ' · 已封禁' : ''}',
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
}
