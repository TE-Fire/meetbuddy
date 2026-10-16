import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/chat_group.dart';
import '../state/chat_state.dart';
import '../state/notification_state.dart';
import '../widget/state_views.dart';
import '../widget/ui.dart';
import 'chat_room_page.dart';
import 'notification_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final chat = context.read<ChatState>();
      if (chat.groups.isEmpty) {
        chat.loadGroups();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatState>();
    final notify = context.watch<NotificationState>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('消息'),
        actions: <Widget>[
          _BellButton(
            unread: notify.unreadCount,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const NotificationPage()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: _ConnPill(on: chat.connected),
          ),
        ],
      ),
      body: SkyBackground(
        child: RefreshIndicator(
          onRefresh: () => chat.loadGroups(),
          child: _body(context, chat),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ChatState chat) {
    if (chat.groups.isEmpty && chat.loadingGroups) {
      return const SingleChildScrollView(child: SkeletonList(rows: 3));
    }
    if (chat.groups.isEmpty) {
      return ListView(
        children: const <Widget>[
          SizedBox(height: 80),
          EmptyView(
            title: '还没有群聊',
            hint: '报名一个活动就会自动进群；自己发起的活动发布时群就建好了',
            icon: Icons.forum_outlined,
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 110),
      itemCount: chat.groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) => StaggeredIn(
        index: i,
        child: _GroupTile(group: chat.groups[i]),
      ),
    );
  }
}

/// 通知入口铃铛，带未读数角标。
class _BellButton extends StatelessWidget {
  const _BellButton({required this.unread, required this.onTap});

  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '通知',
      onPressed: onTap,
      icon: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          const Icon(Icons.notifications_none_rounded),
          if (unread > 0)
            Positioned(
              right: -6,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppBrand.hot,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 1.4),
                ),
                child: Text(
                  bucketBadge(unread),
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 连接状态胶囊：在线是草绿，掉线是灰。
class _ConnPill extends StatelessWidget {
  const _ConnPill({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: on ? AppBrand.grassSoft : const Color(0xFFF1F5F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? AppBrand.grassDeep : AppBrand.muted,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            on ? '实时在线' : '连接中…',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: on ? const Color(0xFF4E8F3C) : AppBrand.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group});

  final ChatGroup group;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatRoomPage(groupId: group.id, title: group.name),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppBrand.rMd),
          boxShadow: AppBrand.cardSm,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                gradient: AppBrand.brand,
                borderRadius: BorderRadius.all(Radius.circular(17)),
                boxShadow: AppBrand.glow,
              ),
              child: const Icon(Icons.forum_rounded, color: Colors.white, size: 23),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppBrand.ink),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    group.lastMessage ?? '还没有消息',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppBrand.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                if (group.lastMessageAt != null)
                  Text(
                    _ago(group.lastMessageAt!),
                    style: const TextStyle(fontSize: 11.5, color: AppBrand.muted),
                  ),
                const SizedBox(height: 7),
                if (group.unread > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppBrand.hot,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      group.unread > 99 ? '99+' : '${group.unread}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  )
                else
                  Text(
                    '${group.memberCount} 人',
                    style: const TextStyle(fontSize: 11.5, color: AppBrand.muted),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return '刚刚';
    if (d.inMinutes < 60) return '${d.inMinutes} 分钟前';
    if (d.inHours < 24) return '${d.inHours} 小时前';
    return '${d.inDays} 天前';
  }
}
