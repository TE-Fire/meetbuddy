import 'dart:math';

import '../../model/activity.dart';
import '../../model/chat_group.dart';
import '../../model/chat_message.dart';
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

  /// 当前登录用户。mock 下任意手机号登录都落到这个账号上。
  int currentUserId = 0;

  final Map<int, User> users = <int, User>{};
  final Map<String, int> phoneToUserId = <String, int>{};
  final Map<int, String> passwords = <int, String>{};

  final List<MockActivityRecord> activities = <MockActivityRecord>[];
  final List<MockGroupRecord> groups = <MockGroupRecord>[];
  final List<ChatMessage> messages = <ChatMessage>[];

  bool _seeded = false;

  /// 首次访问时灌入演示数据。页面代码不调用它，由 repository 惰性触发。
  void ensureSeeded() {
    if (_seeded) {
      return;
    }
    _seeded = true;

    final me = addUser(phone: '13800000001', nickname: '阿发', password: '123456', bio: '周末不想一个人待着');
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
