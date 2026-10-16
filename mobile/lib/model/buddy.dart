import 'json_util.dart';

/// 搭子需求（"我的需求"列表项 + 匹配结果里的需求本体）。
///
/// 字段直接对齐后端 `BuddyVO`：它没有人数上限与截止时间，这是它与活动最本质的区别，
/// 也是两者不合并成一张表的原因（见 docs/02）。
class BuddyRequest {
  const BuddyRequest({
    required this.id,
    required this.userId,
    required this.nickname,
    required this.avatar,
    required this.title,
    required this.description,
    required this.category,
    required this.timeRange,
    required this.status,
    required this.tags,
    required this.creditScore,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String nickname;
  final String? avatar;
  final String title;
  final String? description;
  final String category;
  final String? timeRange;
  final String status;
  final List<String> tags;
  final int creditScore;
  final DateTime? createdAt;

  bool get open => status == 'OPEN';

  factory BuddyRequest.fromJson(Map<String, dynamic> json) => BuddyRequest(
        id: asInt(json['id']),
        userId: asInt(json['userId']),
        nickname: asString(json['nickname'], '匿名用户'),
        avatar: asStringOrNull(json['avatar']),
        title: asString(json['title']),
        description: asStringOrNull(json['description']),
        category: asString(json['category'], '其他'),
        timeRange: asStringOrNull(json['timeRange']),
        status: asString(json['status'], 'OPEN'),
        tags: asStringList(json['tags']),
        creditScore: asInt(json['creditScore']),
        createdAt: asDateOrNull(json['createdAt']),
      );
}

/// 匹配结果项。
///
/// `reason` 是后端直接给的一句话解释（见 `BuddyMatchVO` 的注释：只返分数用户没法判断
/// 为什么联系这个人）。`score` 是 [0,1] 的小数，界面转成百分比展示。
class BuddyMatch {
  const BuddyMatch({
    required this.userId,
    required this.nickname,
    required this.avatar,
    required this.creditScore,
    required this.requestId,
    required this.title,
    required this.category,
    required this.timeRange,
    required this.score,
    required this.distance,
    required this.commonTags,
    required this.reason,
  });

  final int userId;
  final String nickname;
  final String? avatar;
  final int creditScore;
  final int requestId;
  final String title;
  final String category;
  final String? timeRange;
  final double score;
  final double distance;
  final List<String> commonTags;
  final String reason;

  factory BuddyMatch.fromJson(Map<String, dynamic> json) => BuddyMatch(
        userId: asInt(json['userId']),
        nickname: asString(json['nickname'], '匿名用户'),
        avatar: asStringOrNull(json['avatar']),
        creditScore: asInt(json['creditScore']),
        requestId: asInt(json['requestId']),
        title: asString(json['title']),
        category: asString(json['category'], '其他'),
        timeRange: asStringOrNull(json['timeRange']),
        score: (asDoubleOrNull(json['score']) ?? 0).clamp(0.0, 1.0),
        distance: asDoubleOrNull(json['distance']) ?? 0,
        commonTags: asStringList(json['commonTags']),
        reason: asString(json['reason']),
      );
}
