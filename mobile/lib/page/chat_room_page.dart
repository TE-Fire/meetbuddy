import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/chat_state.dart';
import '../state/session_state.dart';
import '../widget/chat_bubble.dart';
import '../widget/state_views.dart';
import '../widget/ui.dart';

/// 群聊页。
///
/// 消息来自 [ChatState]，本页只负责渲染与输入——WebSocket 的分发逻辑全在 state 层，
/// 这样"在详情页收到一条新消息"和"在聊天页收到一条新消息"走的是同一条路径。
class ChatRoomPage extends StatefulWidget {
  const ChatRoomPage({
    super.key,
    required this.groupId,
    required this.title,
    this.readonly = false,
  });

  final int groupId;
  final String title;

  /// 活动已取消 / 已结束时进来，输入框直接置灰，不用等发一条被拒回来才变灰。
  final bool readonly;

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  int _lastCount = 0;

  /// 在 initState 里就把 ChatState 的引用拿住，别在 dispose() 里用 context。
  ///
  /// 卸载顺序是 `super.unmount()`（把 `_widget` 和 `_inheritedElements` 置空、
  /// 状态改成 defunct）**先**、`state.dispose()` **后**。此时用 context 做祖先查找
  /// 会一路走到 provider 的 `throw ProviderNotFoundException(T, context.widget...)`，
  /// 而 defunct Element 的 `_widget!` 已经是 null——release 包里没有那句好心的
  /// assert 提示，只留下 `Null check operator used on a null value`。
  late final ChatState _chat;
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    _chat = context.read<ChatState>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _opened = true;
      _chat.openGroup(widget.groupId);
    });
  }

  @override
  void dispose() {
    // 页面没活过第一帧就不必关，否则会把后到的 openGroup 一起吃掉
    if (_opened) {
      _chat.closeGroup(widget.groupId);
    }
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) {
      return;
    }
    _chat.sendToGroup(widget.groupId, text);
    _input.clear();
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scroll.hasClients) {
      return;
    }
    final target = _scroll.position.maxScrollExtent;
    if (animate) {
      _scroll.animateTo(target, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    } else {
      _scroll.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatState>();
    final myId = context.select<SessionState, int?>((s) => s.me?.id);
    final entries = chat.thread(widget.groupId);
    // 服务端明确回了"只读"就立刻置灰，不必等用户再试一次
    final readonly = widget.readonly || chat.lastErrorCode == 3104;

    if (entries.length != _lastCount) {
      _lastCount = entries.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(widget.title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
            Text(
              chat.connected ? '实时连接中' : '正在重连…',
              style: TextStyle(fontSize: 11.5, color: chat.connected ? const Color(0xFF1E8E3E) : Colors.orange),
            ),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          if (readonly) _readonlyBanner(context),
          Expanded(
            child: !chat.loaded(widget.groupId)
                ? const Center(child: CircularProgressIndicator())
                : entries.isEmpty
                    ? const EmptyView(title: '群里还很安静', hint: '说点什么打破沉默', icon: Icons.chat_bubble_outline)
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: entries.length,
                        itemBuilder: (context, i) {
                          final e = entries[i];
                          final prev = i == 0 ? null : entries[i - 1];
                          // 连续同一个人发言时不重复显示昵称
                          final showSender = prev == null ||
                              prev.message.senderId != e.message.senderId ||
                              prev.message.isSystem;
                          return ChatBubble(
                            message: e.message,
                            mine: e.message.senderId == myId,
                            pending: e.pending,
                            showSender: showSender,
                          );
                        },
                      ),
          ),
          _inputBar(context, readonly),
        ],
      ),
    );
  }

  Widget _readonlyBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.lock_outline_rounded, size: 16, color: scheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '活动已取消，群聊转为只读',
              style: TextStyle(fontSize: 12.5, color: scheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputBar(BuildContext context, bool readonly) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: AppBrand.card,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _input,
                enabled: !readonly,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => readonly ? null : _send(),
                decoration: InputDecoration(
                  hintText: readonly ? '群聊已只读' : '说点什么…',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
            Semantics(
              button: true,
              child: GestureDetector(
                onTap: readonly ? null : _send,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: readonly ? null : AppBrand.brand,
                    color: readonly ? const Color(0xFFC7CBDB) : null,
                    shape: BoxShape.circle,
                    boxShadow: readonly ? null : AppBrand.glow,
                  ),
                  child: const Icon(Icons.send_rounded, size: 19, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
