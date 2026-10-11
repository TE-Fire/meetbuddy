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

/// 品牌蓝胶囊 FAB，外面套一圈黑描边——参考稿里那颗"蓝圆 + 黑环"的按钮。
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
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            gradient: AppBrand.brand,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppBrand.black, width: 3.5),
            boxShadow: AppBrand.glow,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.add_rounded, color: Colors.white, size: 22),
              SizedBox(width: 6),
              Text(
                '发起活动',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 悬浮黑胶囊导航条：选中项转白字并带天空蓝辉光。
class _NavDock extends StatelessWidget {
  const _NavDock({required this.index, required this.unread, required this.onChanged});

  final int index;
  final int unread;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        child: Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppBrand.black.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(999),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Color(0x59171A1D), blurRadius: 28, offset: Offset(0, 12)),
            ],
          ),
          child: Row(
            children: <Widget>[
              _item(0, Icons.explore_rounded, '发现', 0),
              _item(1, Icons.forum_rounded, '消息', unread),
              _item(2, Icons.person_rounded, '我的', 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(int i, IconData icon, String label, int badge) {
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
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: selected ? Colors.white.withValues(alpha: 0.10) : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Icon(
                      icon,
                      size: 20,
                      color: selected ? Colors.white : const Color(0xFF939BA3),
                    ),
                    if (badge > 0)
                      Positioned(
                        right: -7,
                        top: -5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppBrand.hot,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: AppBrand.black, width: 1.4),
                          ),
                          child: Text(
                            bucketBadge(badge),
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? Colors.white : const Color(0xFF939BA3),
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 未读徽标超过 99 显示 99+。
String bucketBadge(int n) => n > 99 ? '99+' : '$n';
