import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/chat_state.dart';
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
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(builder: (_) => const ActivityCreatePage()),
                );
                if (created == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('活动已发布，群聊也已建好')),
                  );
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('发起活动'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: <Widget>[
          const NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: '活动',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.forum_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.forum),
            ),
            label: '消息',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
