import 'json_util.dart';
import 'participant.dart';

/// 活动。列表项与详情共用这一个类：详情接口比列表多出的字段（描述、图片、群 id、
/// 是否已报名、是否收藏、参与者）在这里都有默认值，列表场景下它们就是空。
///
/// 不拆成 Activity / ActivityDetail 父子类，是因为两个接口的字段完全重合（后端
/// ActivityDetailVO extends ActivityVO），拆开只能得到两份重复的 fromJson。
class Activity {
  const Activity({
    required this.id,
    required this.title,
    required this.category,
    required this.address,
    required this.startTime,
    required this.endTime,
    required this.maxParticipants,
    required this.currentParticipants,
    required this.status,
    this.coverUrl,
    this.lng,
    this.lat,
    this.creditRequired = 60,
    this.tags = const [],
    this.organizerId,
    this.organizerNickname,
    this.organizerAvatar,
    this.description,
    this.images = const [],
    this.groupId,
    this.signedUp = false,
    this.favorited = false,
    this.organizer = false,
    this.participants = const [],
  });

  final int id;
  final String title;
  final String category;
  final String? coverUrl;
  final double? lng;
  final double? lat;
  final String address;
  final DateTime? startTime;
  final DateTime? endTime;
  final int maxParticipants;
  final int currentParticipants;
  final String status;
  final int creditRequired;
  final List<String> tags;
  final int? organizerId;
  final String? organizerNickname;
  final String? organizerAvatar;

  // —— 以下仅详情接口带出 ——
  final String? description;
  final List<String> images;
  final int? groupId;
  final bool signedUp;
  final bool favorited;
  final bool organizer;
  final List<Participant> participants;

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
        id: asInt(json['id']),
        title: asString(json['title'], '未命名活动'),
        category: asString(json['category'], '其他'),
        coverUrl: asStringOrNull(json['coverUrl']),
        lng: asDoubleOrNull(json['lng']),
        lat: asDoubleOrNull(json['lat']),
        address: asString(json['address']),
        startTime: asDateOrNull(json['startTime']),
        endTime: asDateOrNull(json['endTime']),
        maxParticipants: asInt(json['maxParticipants']),
        currentParticipants: asInt(json['currentParticipants']),
        status: asString(json['status'], 'OPEN'),
        creditRequired: asInt(json['creditRequired'], 60),
        tags: asStringList(json['tags']),
        organizerId: asIntOrNull(json['organizerId']),
        organizerNickname: asStringOrNull(json['organizerNickname']),
        organizerAvatar: asStringOrNull(json['organizerAvatar']),
        description: asStringOrNull(json['description']),
        images: asStringList(json['images']),
        groupId: asIntOrNull(json['groupId']),
        signedUp: asBool(json['signedUp']),
        favorited: asBool(json['favorited']),
        organizer: asBool(json['organizer']),
        participants: asMapList(json['participants']).map(Participant.fromJson).toList(),
      );

  String get statusLabel => switch (status) {
        'OPEN' => '报名中',
        'FULL' => '已满',
        'ONGOING' => '进行中',
        'FINISHED' => '已结束',
        'CANCELLED' => '已取消',
        _ => status,
      };

  int get slotsLeft => (maxParticipants - currentParticipants).clamp(0, maxParticipants);

  /// 能报名：还在报名中、名额没满、自己不是组织者、也还没报过。
  bool get canSignUp => status == 'OPEN' && slotsLeft > 0 && !organizer && !signedUp;

  bool get canCancelSignUp => signedUp && (status == 'OPEN' || status == 'FULL');

  /// 群聊入口：只要有 groupId 就能进，取消的活动群转为只读（后端会拒发言）。
  bool get hasGroup => groupId != null;

  bool get isClosed => status == 'CANCELLED' || status == 'FINISHED';
}
