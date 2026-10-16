import 'dart:async';

import 'package:flutter/foundation.dart';

import '../model/api_exception.dart';
import '../model/app_notification.dart';
import '../model/chat_event.dart';
import '../repository/chat_socket.dart';
import '../repository/notification_repository.dart';

/// 通知状态。
///
/// 放在 state 层而不是页面里，只有一个理由：**"消息"tab 的红点 = 聊天未读 + 通知未读**，
/// 而这个红点画在 [HomeShell] 上。计数若留在通知页内部，从通知页返回后外面的红点
/// 就跟里面已经取消掉的那几个对不上了。
class NotificationState extends ChangeNotifier {
  NotificationState({required NotificationRepository repo, required ChatSocket socket})
      : _repo = repo,
        _socket = socket;

  final NotificationRepository _repo;
  final ChatSocket _socket;

  static const int _size = 20;

  StreamSubscription<ChatEvent>? _sub;

  final List<AppNotification> items = <AppNotification>[];

  int unreadCount = 0;
  bool loading = false;
  bool loadingMore = false;
  bool finished = false;
  String? lastError;

  int _page = 1;

  /// 挂在 WebSocket 上，只关心 notify 帧。
  ///
  /// 不去动 [ChatState] 的那份订阅：两者听的是同一个广播流，各管各的域，
  /// 合成一个"总事件总线"反而会让聊天页和通知页互相牵制。
  void attach() {
    _sub ??= _socket.events.listen((event) {
      if (!event.isNotify) {
        return;
      }
      final n = event.notification;
      if (n == null) {
        // 帧里没带本体（理论上不会），至少把计数刷新一下，别让红点停在旧值
        unawaited(loadUnread());
        return;
      }
      // 同一条可能因为断线补发被推两遍，按 id 去重
      if (items.any((x) => x.id == n.id)) {
        return;
      }
      items.insert(0, n);
      unreadCount += 1;
      notifyListeners();
    });
  }

  /// 只拉未读数。登录后、以及回到前台时用——比拉整页便宜得多。
  Future<void> loadUnread() async {
    try {
      unreadCount = await _repo.unread();
      notifyListeners();
    } on ApiException catch (e) {
      lastError = e.message;
    }
  }

  /// 拉第一页，覆盖现有列表。
  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    try {
      final page = await _repo.list(page: 1, size: _size);
      items
        ..clear()
        ..addAll(page.list);
      _page = 1;
      finished = items.length >= page.total;
      unreadCount = await _repo.unread();
      lastError = null;
    } on ApiException catch (e) {
      lastError = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// 翻下一页，结果追加在尾部。
  Future<void> loadMore() async {
    if (loadingMore || finished) {
      return;
    }
    loadingMore = true;
    notifyListeners();
    try {
      final page = await _repo.list(page: _page + 1, size: _size);
      items.addAll(page.list);
      _page += 1;
      // 用"这一页拿回来的条数"判断到底，不用 total——翻页途中若有新通知插入，
      // total 会变，而 page*size 的推算会让列表提前收尾，漏掉最后几条。
      finished = page.list.length < _size;
      lastError = null;
    } on ApiException catch (e) {
      lastError = e.message;
    } finally {
      loadingMore = false;
      notifyListeners();
    }
  }

  /// 点开一条：先本地翻成已读，再回报服务端。
  ///
  /// **失败不回滚**——已读是"我看过了"的本地事实，回滚会让红点重新冒出来、
  /// 用户再点一次还是失败，体验比允许一次不同步差得多。下次 [refresh] 会以
  /// 服务端为准把它纠正回来（后端标已读是幂等的，重试无副作用）。
  Future<void> markRead(AppNotification n) async {
    if (!n.read) {
      _flipLocal(n.id);
      notifyListeners();
      try {
        await _repo.markRead(n.id);
      } on ApiException catch (e) {
        lastError = e.message;
      }
    }
  }

  Future<bool> readAll() async {
    try {
      await _repo.readAll();
      for (int i = 0; i < items.length; i++) {
        if (!items[i].read) {
          items[i] = items[i].asRead();
        }
      }
      unreadCount = 0;
      lastError = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      lastError = e.message;
      notifyListeners();
      return false;
    }
  }

  void _flipLocal(int id) {
    final i = items.indexWhere((x) => x.id == id);
    if (i < 0) {
      return;
    }
    items[i] = items[i].asRead();
    if (unreadCount > 0) {
      unreadCount -= 1;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
