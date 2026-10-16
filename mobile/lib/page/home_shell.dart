import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/chat_state.dart';
import '../state/notification_state.dart';
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
    // 「消息」tab 的红点 = 聊天未读 + 通知未读。两端同一口径：通知是消息域的一部分，
    // 分成两个红点会让用户在两处之间来回找"到底哪条没看"。
    final chat = context.watch<ChatState>();
    final notify = context.watch<NotificationState>();
    final unread = chat.unreadTotal + notify.unreadCount;

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
///
/// 选中指示**从一个白胶囊滑动到另一个**，不是两颗各自原地变色。滑动是"选中项换了"
/// 的因果表达——原地渐变只能说明"两个格子的颜色变了"，看不出方向，也无法回答
/// "我是从哪一页过来的"。指示器用 [Align] 的 `widthFactor` 走位置，无需测量宽度，
/// 天然跟着 Row 的等分伸缩（换机型、改标签文案都不会错位）。
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
          child: Stack(
            children: <Widget>[
              // 滑块在底层，三个 item 压在上面——反过来的话滑块会盖住图标和角标。
              // IgnorePointer 是为了让滑块不吃点击，否则它下面的 item 永远点不到。
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedAlign(
                    // 三颗等分：0 居中在 1/6 处，1 在 3/6，2 在 5/6。
                    alignment: Alignment((index - 1).toDouble(), 0),
                    duration: const Duration(milliseconds: 300),
                    // easeOutBack 的末端过冲让滑块"撞"进目标位再回弹一点，
                    // 这是整条导航有生命力的关键；换成 easeInOut 立刻变机械。
                    curve: Curves.easeOutBack,
                    child: FractionallySizedBox(
                      widthFactor: 1 / 3,
                      heightFactor: 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  _item(0, Icons.explore_rounded, '发现', 0),
                  _item(1, Icons.forum_rounded, '消息', unread),
                  _item(2, Icons.person_rounded, '我的', 0),
                ],
              ),
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
        child: PressableScale(
          // 0.90 比常规 0.94 更用力：导航键只有 20px 图标 + 9.5px 字，
          // 按常规幅度在深色底上几乎看不出，点起来会怀疑"点上没有"。
          scale: 0.90,
          onTap: () => onChanged(i),
          child: Container(
            // 滑块已经负责"选中"的视觉，这里只保留图标/文字的过渡。
            // 之前那层 10% 白底现在交给滑块，留着会变成两块叠加的深浅不一样。
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AnimatedScale(
                  // 选中项图标轻微放大 8%：文字变色在 9.5px 上不明显，
                  // 图标这一下"顶起来"才是能一眼看到的选中信号。
                  scale: selected ? 1.08 : 1,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        // 图标本体换色用 AnimatedSwitcher 而不是直接换 IconData，
                        // 是为了让"变色"这个过程也有一帧过渡而不是硬切。
                        child: Icon(
                          icon,
                          key: ValueKey<bool>(selected),
                          size: 20,
                          color: selected ? Colors.white : const Color(0xFF939BA3),
                        ),
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
