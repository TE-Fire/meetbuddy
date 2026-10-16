import 'dart:math';

import '../../model/activity.dart';
import '../../model/app_notification.dart';
import '../../model/badge.dart';
import '../../model/chat_group.dart';
import '../../model/chat_message.dart';
import '../../model/credit_log.dart';
import '../../model/participant.dart';
import '../../model/user.dart';

/// 内存假数据仓库。
///
/// 所有 mock repository 共用这一个实例（由组合根注入），这样"在发布页新建的活动"
/// 会立刻出现在活动流里。单例不是偷懒，是 mock 场景下唯一能保证数据一致的做法——
/// 四个 repository 各存一份的话，页面之间就对不上了。
///
/// 只在 `--dart-define=USE_MOCK=true` 时被构造，release 包里不会引用到。
class MockStore {
  MockStore._();

  static final MockStore instance = MockStore._();

  int _userIdSeq = 0;
  int _activityIdSeq = 0;
  int _groupIdSeq = 0;
  int _messageIdSeq = 0;
  int _creditLogIdSeq = 0;

  /// 当前登录用户。mock 下任意手机号登录都落到这个账号上。
  int currentUserId = 0;

  final Map<int, User> users = <int, User>{};
  final Map<String, int> phoneToUserId = <String, int>{};
  final Map<int, String> passwords = <int, String>{};

  final List<MockActivityRecord> activities = <MockActivityRecord>[];
  final List<MockGroupRecord> groups = <MockGroupRecord>[];
  final List<ChatMessage> messages = <ChatMessage>[];

  /// 关注关系：`followerId -> 他关注的人的 id 集合`。
  /// 用 Set 而不是 List，是因为"关注"天然幂等——重复关注不该让粉丝数涨两次，
  /// 真实后端靠 `uk_follow` 唯一索引保证的也是这一条。
  final Map<int, Set<int>> follows = <int, Set<int>>{};

  /// 已解锁徽章：`userId -> 徽章`。他人主页只展示这个，不展示未解锁的。
  final Map<int, List<Badge>> badges = <int, List<Badge>>{};

  /// 信用分流水：`userId -> 流水`，按时间**倒序**存（与后端列表顺序一致）。
  final Map<int, List<CreditLog>> creditLogs = <int, List<CreditLog>>{};

  /// 站内通知，按时间**倒序**存（新的在前），与后端列表顺序一致。
  final List<AppNotification> notifications = <AppNotification>[];

  int _notificationIdSeq = 0;

  bool _seeded = false;

  /// 首次访问时灌入演示数据。页面代码不调用它，由 repository 惰性触发。
  void ensureSeeded() {
    if (_seeded) {
      return;
    }
    _seeded = true;

    // 90 而不是默认 100：下面灌的流水最后一步是"报名后未到场 -10"，
    // 账号分数要和流水对得上，否则明细页顶部数字与最后一条记录自相矛盾。
    final me = addUser(
      phone: '13800000001',
      nickname: '阿发',
      password: '123456',
      bio: '周末不想一个人待着',
      creditScore: 90,
    );
    currentUserId = me.id;
    final manman = addUser(phone: '13800000002', nickname: '林小满', password: '123456', bio: '剧本杀十级选手');
    final chenmo = addUser(phone: '13800000003', nickname: '陈默', password: '123456', bio: '只玩硬核本');
    final suxiao = addUser(phone: '13800000004', nickname: '苏晓', password: '123456', bio: '羽毛球 / 飞盘');

    final base = DateTime.now().add(const Duration(days: 1));
    DateTime at(int days, int hour) => DateTime(base.year, base.month, base.day + days, hour);

    // 我组织的
    final a1 = addActivity(
      title: '国贸剧本杀·硬核本',
      category: '剧本杀',
      description: '周日下午两点，国贸这边新开的店，硬核推理本《雾锁》，6 人局，玩得动的来。'
          '新手勿扰不是嫌人，是硬核本真的会坐牢四小时。',
      address: '朝阳区建国门外大街 1 号 国贸商城 4F',
      lng: 116.4610,
      lat: 39.9088,
      startTime: at(1, 14),
      endTime: at(1, 19),
      maxParticipants: 6,
      organizerId: me.id,
      tags: <String>['硬核', '剧本杀'],
    );
    a1.signedUp.addAll(<int>[manman.id, chenmo.id, suxiao.id]);
    attachGroup(a1, name: '国贸剧本杀·硬核本 群');

    // 别人组织的
    final a2 = addActivity(
      title: '奥森公园夜跑 5 公里',
      category: '运动',
      description: '慢跑配速 6 分半，跑完一起喝东西。不用带装备，来就行。',
      address: '朝阳区科荟路 33 号 奥林匹克森林公园南园',
      lng: 116.3920,
      lat: 40.0200,
      startTime: at(1, 19),
      endTime: at(1, 21),
      maxParticipants: 12,
      organizerId: manman.id,
      tags: <String>['跑步', '夜跑'],
      status: 'FULL',
    );
    a2.signedUp.addAll(<int>[
      for (int i = 0; i < 12; i++) 100 + i,
    ]);

    addActivity(
      title: '胡同里的老北京早餐散步',
      category: '探店',
      description: '从鼓楼走到南锣，一路吃三家早点摊。人多的话分开排队，汇合了再走。',
      address: '东城区鼓楼东大街',
      lng: 116.4040,
      lat: 39.9420,
      startTime: at(2, 8),
      endTime: at(2, 11),
      maxParticipants: 8,
      organizerId: suxiao.id,
      tags: <String>['美食', '散步'],
    );

    final a4 = addActivity(
      title: '羽毛球双打缺两个人',
      category: '运动',
      description: '常营这边球馆，场地已经订好了，AA 场地费。业余水平就行。',
      address: '朝阳区常营北路 6 号 动因体育馆',
      lng: 116.5900,
      lat: 39.9250,
      startTime: at(3, 20),
      endTime: at(3, 22),
      maxParticipants: 4,
      organizerId: chenmo.id,
      tags: <String>['羽毛球'],
    );
    a4.signedUp.add(manman.id);
    attachGroup(a4, name: '羽毛球双打缺两个人 群');
    groups.last.members.add(me.id);
    groups.last.roleOf[me.id] = 'MEMBER';
    for (int i = 0; i < 3; i++) {
      addGroupMessage(a4.groupId!, manman.id, '周日场地确认了吗？');
    }
    addGroupMessage(a4.groupId!, chenmo.id, '确认了，19 号场，晚上 8 点。');

    // 关注关系：我关注两个人，陈默关注我。灌这些是为了让「关注 / 粉丝」两个
    // 计数与列表页一开始就有内容——全 0 的空态看不出分页和 tab 切换对不对。
    setFollow(me.id, manman.id, on: true);
    setFollow(me.id, suxiao.id, on: true);
    setFollow(chenmo.id, me.id, on: true);

    // 徽章：这里灌**全部 8 枚**（含未解锁与进度），给徽章墙画灰态用。
    // code/name/icon/group/target 必须与后端 `BadgeEnum` 逐字一致——那是徽章的
    // 唯一定义处（代码内枚举，不建定义表）。之前只灌了已解锁的 2 枚，徽章墙会
    // 误以为"系统里总共就 2 枚"。icon 也按后端校正过（FIRST_HOST 是 📣 不是 🎪）。
    //
    // 解锁的两枚是 INSTANT 类（首次报名/首次组局），当场就能判定；
    // 其余是 SCAN 类，等活动 FINISHED 后由 BadgeScanJob 评，所以这里是未解锁 + 进度。
    badges[me.id] = <Badge>[
      const Badge(
        code: 'FIRST_SIGNUP', name: '初出茅庐', desc: '首次报名活动', icon: '🌱',
        group: 'NONE', unlocked: true, unlockedAt: null, progress: 1, target: 1,
      ),
      const Badge(
        code: 'FIRST_HOST', name: '初次组局', desc: '首次发布活动', icon: '📣',
        group: 'NONE', unlocked: true, unlockedAt: null, progress: 1, target: 1,
      ),
      // ATTENDED_3：到场 1/3 次
      const Badge(
        code: 'ATTENDED_3', name: '靠谱伙伴', desc: '被组织者确认到场累计 3 次', icon: '🤝',
        group: 'ATTENDED', progress: 1, target: 3,
      ),
      // JOIN 组共享"完成活动次数"：当前 1 次，所以 JOIN_3 是 1/3、JOIN_10 是 1/10
      const Badge(
        code: 'JOIN_3', name: '渐入佳境', desc: '完成 3 次活动', icon: '🚶',
        group: 'JOINED', progress: 1, target: 3,
      ),
      const Badge(
        code: 'JOIN_10', name: '组局常客', desc: '完成 10 次活动', icon: '🏃',
        group: 'JOINED', progress: 1, target: 10,
      ),
      // HOST 组同理：当前 1 次
      const Badge(
        code: 'HOST_3', name: '小有名气', desc: '完成 3 次自己组织的活动', icon: '🎪',
        group: 'HOSTED', progress: 1, target: 3,
      ),
      const Badge(
        code: 'HOST_10', name: '金牌组局人', desc: '完成 10 次自己组织的活动', icon: '👑',
        group: 'HOSTED', progress: 1, target: 10,
      ),
      const Badge(
        code: 'FULL_HOUSE', name: '座无虚席', desc: '组织的活动满员结束至少 1 次', icon: '🎉',
        group: 'FULL', progress: 0, target: 1,
      ),
    ];
    // 他人主页只嵌已解锁的那些，所以 manman / chenmo 的列表可以只有 1 条。
    // 但 code/icon 仍与 BadgeEnum 对齐。
    badges[manman.id] = <Badge>[
      const Badge(
        code: 'FULL_HOUSE', name: '座无虚席', desc: '组织的活动满员结束至少 1 次', icon: '🎉',
        group: 'FULL', unlocked: true, progress: 1, target: 1,
      ),
    ];
    badges[chenmo.id] = <Badge>[
      const Badge(
        code: 'JOIN_10', name: '组局常客', desc: '完成 10 次活动', icon: '🏃',
        group: 'JOINED', unlocked: true, progress: 10, target: 10,
      ),
    ];

    // 信用流水：把后端 `CreditServiceImpl.change` 的真实规则演一遍——
    // 初始 100 → 取消报名 -1 → 确认到场 +3（ clamp 回 100）→ 报名后未到场 -10。
    // 顺序即时间正序，倒序存进列表；最后一条的 balanceAfter 必须等于 me.creditScore。
    addCreditLog(
      userId: me.id,
      changeValue: 100,
      reason: '新用户初始 100 分',
      balanceAfter: 100,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    );
    addCreditLog(
      userId: me.id,
      changeValue: -1,
      reason: '取消报名',
      balanceAfter: 99,
      relatedId: a1.id,
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
    );
    addCreditLog(
      userId: me.id,
      changeValue: 3,
      reason: '被组织者确认到场',
      balanceAfter: 100,
      relatedId: a1.id,
      createdAt: DateTime.now().subtract(const Duration(days: 12)),
    );
    addCreditLog(
      userId: me.id,
      changeValue: -10,
      reason: '报名后未到场',
      balanceAfter: 90,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    );

    // 通知：覆盖"可跳活动""可跳人""不可跳"三种，以及已读/未读两态。
    addNotification(
      type: 'SIGNUP_NEW',
      title: '新的报名',
      content: '林小满 报名了「国贸剧本杀·硬核本」',
      bizId: a1.id,
    );
    addNotification(
      type: 'USER_FOLLOWED',
      title: '新的关注',
      content: '陈默 关注了你',
      bizId: chenmo.id,
    );
    addNotification(
      type: 'BADGE_UNLOCKED',
      title: '解锁新勋章',
      content: '恭喜获得「初次组局」',
      bizId: null,
    );
    addNotification(
      type: 'ACTIVITY_REMINDER',
      title: '活动即将开始',
      content: '「奥森公园夜跑 5 公里」明天 19:00 开始',
      bizId: a2.id,
      read: true,
    );
  }

  // ——— 用户 ———

  User addUser({
    required String phone,
    required String nickname,
    required String password,
    String? bio,
    int creditScore = 100,
  }) {
    final id = ++_userIdSeq;
    final user = User(id: id, phone: phone, nickname: nickname, bio: bio, creditScore: creditScore);
    users[id] = user;
    phoneToUserId[phone] = id;
    passwords[id] = password;
    return user;
  }

  User? byPhone(String phone) {
    final id = phoneToUserId[phone];
    return id == null ? null : users[id];
  }

  bool checkPassword(String phone, String password) {
    final id = phoneToUserId[phone];
    return id != null && passwords[id] == password;
  }

  User get me => users[currentUserId]!;

  // ——— 活动 ———

  MockActivityRecord addActivity({
    required String title,
    required String category,
    required String description,
    required String address,
    required double lng,
    required double lat,
    required DateTime startTime,
    required DateTime endTime,
    required int maxParticipants,
    required int organizerId,
    List<String> tags = const <String>[],
    String status = 'OPEN',
    String? coverUrl,
    List<String> images = const <String>[],
    int creditRequired = 60,
  }) {
    final record = MockActivityRecord(
      id: ++_activityIdSeq,
      title: title,
      category: category,
      description: description,
      address: address,
      lng: lng,
      lat: lat,
      startTime: startTime,
      endTime: endTime,
      maxParticipants: maxParticipants,
      organizerId: organizerId,
      tags: tags,
      status: status,
      coverUrl: coverUrl,
      images: images,
      creditRequired: creditRequired,
    );
    activities.add(record);
    return record;
  }

  MockActivityRecord? activity(int id) {
    for (final a in activities) {
      if (a.id == id) {
        return a;
      }
    }
    return null;
  }

  /// 列表项：详情字段留空，只有标题页要用的那几个。
  Activity toListItem(MockActivityRecord r) => Activity(
        id: r.id,
        title: r.title,
        category: r.category,
        coverUrl: r.coverUrl,
        lng: r.lng,
        lat: r.lat,
        address: r.address,
        startTime: r.startTime,
        endTime: r.endTime,
        maxParticipants: r.maxParticipants,
        currentParticipants: r.currentParticipants,
        status: r.status,
        creditRequired: r.creditRequired,
        tags: r.tags,
        organizerId: r.organizerId,
        organizerNickname: users[r.organizerId]?.nickname,
        organizerAvatar: users[r.organizerId]?.avatar,
      );

  /// 详情：把 signedUp/favorited/organizer/参与者摘要都算出来。
  Activity toDetail(MockActivityRecord r, int viewerId) => Activity(
        id: r.id,
        title: r.title,
        category: r.category,
        coverUrl: r.coverUrl,
        lng: r.lng,
        lat: r.lat,
        address: r.address,
        startTime: r.startTime,
        endTime: r.endTime,
        maxParticipants: r.maxParticipants,
        currentParticipants: r.currentParticipants,
        status: r.status,
        creditRequired: r.creditRequired,
        tags: r.tags,
        images: r.images,
        organizerId: r.organizerId,
        organizerNickname: users[r.organizerId]?.nickname,
        organizerAvatar: users[r.organizerId]?.avatar,
        description: r.description,
        groupId: r.groupId,
        signedUp: r.signedUp.contains(viewerId),
        favorited: r.favoritedBy.contains(viewerId),
        organizer: r.organizerId == viewerId,
        participants: r.signedUp
            .map((id) => users[id])
            .whereType<User>()
            .map((u) => Participant(
                  userId: u.id,
                  nickname: u.nickname,
                  avatar: u.avatar,
                  creditScore: u.creditScore,
                  status: 'SIGNED',
                  joinedAt: r.createdAt,
                ))
            .toList(),
      );

  // ——— 群与消息 ———

  MockGroupRecord attachGroup(MockActivityRecord activity, {required String name}) {
    final group = MockGroupRecord(
      id: ++_groupIdSeq,
      activityId: activity.id,
      name: name,
      ownerId: activity.organizerId,
    );
    group.members.add(activity.organizerId);
    group.roleOf[activity.organizerId] = 'OWNER';
    for (final uid in activity.signedUp) {
      group.members.add(uid);
      group.roleOf[uid] = 'MEMBER';
    }
    groups.add(group);
    activity.groupId = group.id;
    return group;
  }

  MockGroupRecord? group(int id) {
    for (final g in groups) {
      if (g.id == id) {
        return g;
      }
    }
    return null;
  }

  ChatMessage addGroupMessage(int groupId, int senderId, String content, {String msgType = 'TEXT'}) {
    final msg = ChatMessage(
      id: ++_messageIdSeq,
      groupId: groupId,
      senderId: senderId,
      senderNickname: users[senderId]?.nickname ?? '系统',
      msgType: msgType,
      content: content,
      createdAt: DateTime.now(),
    );
    messages.add(msg);
    return msg;
  }

  List<ChatMessage> groupMessages(int groupId) =>
      messages.where((m) => m.groupId == groupId).toList();

  ChatMessage? lastGroupMessage(int groupId) {
    ChatMessage? last;
    for (final m in messages) {
      if (m.groupId == groupId) {
        last = m;
      }
    }
    return last;
  }

  int unreadInGroup(int groupId, int viewerId) {
    final cursor = readCursor[viewerId]?[groupId] ?? 0;
    return messages
        .where((m) => m.groupId == groupId && m.id > cursor && m.senderId != viewerId)
        .length;
  }

  /// 群读游标：`viewerId -> groupId -> 已读到的最大消息 id`。
  /// 单聊用不上——一位 tinytest 表达不了"群消息谁读到哪"，这点与后端一致。
  final Map<int, Map<int, int>> readCursor = <int, Map<int, int>>{};

  void markGroupRead(int groupId, int viewerId) {
    final last = lastGroupMessage(groupId);
    if (last == null) {
      return;
    }
    (readCursor[viewerId] ??= <int, int>{})[groupId] = last.id;
  }

  ChatGroup toChatGroup(MockGroupRecord g, int viewerId) {
    final last = lastGroupMessage(g.id);
    return ChatGroup(
      id: g.id,
      activityId: g.activityId,
      name: g.name,
      memberCount: g.members.length,
      role: g.roleOf[viewerId] ?? 'MEMBER',
      lastMessage: last == null ? null : (last.isSystem ? last.content : '${last.senderNickname}：${last.content}'),
      lastMessageAt: last?.createdAt,
      unread: unreadInGroup(g.id, viewerId),
    );
  }

  // ——— 关注关系 ———

  bool isFollowing(int followerId, int followeeId) =>
      follows[followerId]?.contains(followeeId) ?? false;

  void setFollow(int followerId, int followeeId, {required bool on}) {
    final set = follows[followerId] ??= <int>{};
    if (on) {
      set.add(followeeId);
    } else {
      set.remove(followeeId);
    }
  }

  /// 关注数：这个人关注了多少人。
  int followingCountOf(int userId) => follows[userId]?.length ?? 0;

  /// 粉丝数：多少人关注了这个人。只能扫全表——真实后端有 `idx_followee` 索引兜着。
  int followerCountOf(int userId) =>
      follows.values.where((set) => set.contains(userId)).length;

  List<int> followingIdsOf(int userId) => (follows[userId] ?? const <int>{}).toList();

  List<int> followerIdsOf(int userId) => <int>[
        for (final entry in follows.entries)
          if (entry.value.contains(userId)) entry.key,
      ];

  // ——— 徽章 ———

  List<Badge> badgesOf(int userId) => badges[userId] ?? const <Badge>[];

  // ——— 信用流水 ———

  List<CreditLog> creditLogsOf(int userId) =>
      creditLogs[userId] ?? const <CreditLog>[];

  /// 灌一条流水并插到列表头部（新的在前，与后端 `order by created_at desc` 一致）。
  CreditLog addCreditLog({
    required int userId,
    required int changeValue,
    required String reason,
    int? balanceAfter,
    int? relatedId,
    int? operatorId,
    DateTime? createdAt,
  }) {
    final log = CreditLog(
      id: ++_creditLogIdSeq,
      changeValue: changeValue,
      reason: reason,
      balanceAfter: balanceAfter,
      relatedId: relatedId,
      operatorId: operatorId,
      createdAt: createdAt ?? DateTime.now(),
    );
    creditLogs.putIfAbsent(userId, () => <CreditLog>[]).insert(0, log);
    return log;
  }

  // ——— 通知 ———

  AppNotification addNotification({
    required String type,
    String? title,
    required String content,
    int? bizId,
    bool read = false,
  }) {
    final n = AppNotification(
      id: ++_notificationIdSeq,
      type: type,
      title: title,
      content: content,
      bizId: bizId,
      read: read,
      createdAt: DateTime.now().subtract(Duration(minutes: _notificationIdSeq * 17)),
    );
    notifications.insert(0, n);
    return n;
  }

  int unreadNotifications() => notifications.where((n) => !n.read).length;

  /// 标已读：按 id 替换成 [AppNotification.asRead] 的副本。
  /// 列表里存的是不可变对象，就地改字段做不到——这也是模型的 [AppNotification.read]
  /// 用 bool 而不用 `int readStatus` 的附带好处：改状态只有一条路径。
  bool markNotificationRead(int id) {
    final i = notifications.indexWhere((n) => n.id == id);
    if (i < 0 || notifications[i].read) {
      return false;
    }
    notifications[i] = notifications[i].asRead();
    return true;
  }

  int markAllNotificationsRead() {
    int changed = 0;
    for (int i = 0; i < notifications.length; i++) {
      if (!notifications[i].read) {
        notifications[i] = notifications[i].asRead();
        changed++;
      }
    }
    return changed;
  }

  /// 某人"最近相关"的活动：组织的 + 参加的合并，按开始时间倒序。
  ///
  /// 真实后端只回 **FINISHED** 的活动（`hostedCount`/`joinedCount` 也是同一口径）。
  /// mock 里没有已完成的活动，所以这里退化成"最近相关"，**不假装已完成**——
  /// 状态文字照实显示"报名中"，页面标题仍是"最近完成"是这份数据的局限，不是页面的错。
  List<MockActivityRecord> recentFor(int userId, {int limit = 5}) {
    final hit = activities
        .where((a) => a.organizerId == userId || a.signedUp.contains(userId))
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    return hit.take(limit).toList();
  }

  /// 两点间距离，公里。活动卡片上展示"距你 x km"用。
  static double distanceKm(double lng1, double lat1, double lng2, double lat2) {
    const earth = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return earth * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _rad(double deg) => deg * pi / 180;
}

/// mock 用的活动可变记录。真实实现里这些可变性都在数据库里。
class MockActivityRecord {
  MockActivityRecord({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.address,
    required this.lng,
    required this.lat,
    required this.startTime,
    required this.endTime,
    required this.maxParticipants,
    required this.organizerId,
    this.tags = const <String>[],
    this.status = 'OPEN',
    this.coverUrl,
    this.images = const <String>[],
    this.creditRequired = 60,
  }) : createdAt = DateTime.now();

  final int id;
  String title;
  String category;
  String description;
  String address;
  double lng;
  double lat;
  DateTime startTime;
  DateTime endTime;
  int maxParticipants;
  final int organizerId;
  List<String> tags;
  String status;
  String? coverUrl;
  List<String> images;
  int creditRequired;
  int? groupId;
  final DateTime createdAt;

  final Set<int> signedUp = <int>{};
  final Set<int> favoritedBy = <int>{};

  int get currentParticipants => signedUp.length;
}

/// mock 用的群可变记录。
class MockGroupRecord {
  MockGroupRecord({
    required this.id,
    required this.activityId,
    required this.name,
    required this.ownerId,
  });

  final int id;
  final int? activityId;
  String name;
  final int ownerId;
  final List<int> members = <int>[];
  final Map<int, String> roleOf = <int, String>{};
  bool readonly = false;
}
