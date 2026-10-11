import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/chat_group.dart';
import '../state/chat_state.dart';
import '../widget/state_views.dart';
import 'chat_room_page.dart';

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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('消息'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: <Widget>[
                _Dot(on: chat.connected),
                const SizedBox(width: 6),
                Text(
                  chat.connected ? '实时在线' : '连接中…',
                  style: TextStyle(fontSize: 12.5, color: chat.connected ? const Color(0xFF1E8E3E) : scheme.outline),
                ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => chat.loadGroups(),
        child: _body(context, chat),
      ),
    );
  }

  Widget _body(BuildContext context, ChatState chat) {
    if (chat.groups.isEmpty && chat.loadingGroups) {
      return const Center(child: CircularProgressIndicator());
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: chat.groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _GroupTile(group: chat.groups[i]),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group});

  final ChatGroup group;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(Icons.groups_outlined, color: scheme.primary),
        ),
        title: Text(
          group.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            group.lastMessage ?? '还没有消息',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            if (group.lastMessageAt != null)
              Text(_ago(group.lastMessageAt!), style: TextStyle(fontSize: 11.5, color: scheme.outline)),
            const SizedBox(height: 6),
            if (group.unread > 0)
              Badge(label: Text('${group.unread}'))
            else
              Text('${group.memberCount} 人', style: TextStyle(fontSize: 11.5, color: scheme.outline)),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ChatRoomPage(groupId: group.id, title: group.name),
          ),
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

class _Dot extends StatelessWidget {
  const _Dot({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? const Color(0xFF1E8E3E) : Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}
