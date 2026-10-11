import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/chat_state.dart';
import '../widget/ui.dart';
import 'activity_create_page.dart';
import 'activity_feed_page.dart';
import 'chat_list_page.dart';
import 'profile_page.dart';

/// 底部导航壳。三个 Tab 各自保留自己的滚动位置，不重建。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const ActivityCreatePage()),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('活动已发布，群聊也已建好')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<ChatState>().unreadTotal;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const <Widget>[
          ActivityFeedPage(),
          ChatListPage(),
          ProfilePage(),
        ],
      ),
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, anim) => ScaleTransition(
          scale: Tween(begin: 0.8, end: 1.0).animate(anim),
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: _index == 0
            ? _GradientFab(
                key: const ValueKey<bool>(true),
                onTap: _openCreate,
              )
            : const SizedBox.shrink(key: ValueKey<bool>(false)),
      ),
      bottomNavigationBar: _NavDock(
        index: _index,
        unread: unread,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}

/// 渐变 FAB。手写胶囊替代默认圆形，配品牌投影。
class _GradientFab extends StatelessWidget {
  const _GradientFab({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: PressableScale(
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            gradient: AppBrand.brand,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppBrand.glow,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.add_rounded, color: Colors.white, size: 22),
              SizedBox(width: 6),
              Text(
                '发起活动',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 悬浮胶囊导航条：选中项有品牌色药丸底，文字与图标颜色随动。
class _NavDock extends StatelessWidget {
  const _NavDock({required this.index, required this.unread, required this.onChanged});

  final int index;
  final int unread;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppBrand.card,
        ),
        child: Row(
          children: <Widget>[
            _item(0, Icons.explore_rounded, Icons.explore_outlined, '活动', 0),
            _item(1, Icons.forum_rounded, Icons.forum_outlined, '消息', unread),
            _item(2, Icons.person_rounded, Icons.person_outline, '我的', 0),
          ],
        ),
      ),
    );
  }

  Widget _item(int i, IconData activeIcon, IconData icon, String label, int badge) {
    final selected = index == i;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppBrand.primary.withValues(alpha: 0.10) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(selected ? activeIcon : icon, size: 22,
                    color: selected ? AppBrand.primary : AppBrand.muted),
                const SizedBox(width: 5),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? AppBrand.primary : AppBrand.muted,
                  ),
                  child: Text(label),
                ),
                if (badge > 0) ...<Widget>[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppBrand.hot,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
