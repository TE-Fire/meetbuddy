import 'json_util.dart';

/// 对应后端 ParticipantVO。status 取值 SIGNED / CANCELED / ATTENDED / ABSENT。
class Participant {
  const Participant({
    required this.userId,
    required this.nickname,
    this.avatar,
    this.creditScore = 100,
    required this.status,
    this.remark,
    this.joinedAt,
  });

  final int userId;
  final String nickname;
  final String? avatar;
  final int creditScore;
  final String status;
  final String? remark;
  final DateTime? joinedAt;

  factory Participant.fromJson(Map<String, dynamic> json) => Participant(
        userId: asInt(json['userId']),
        nickname: asString(json['nickname'], '匿名用户'),
        avatar: asStringOrNull(json['avatar']),
        creditScore: asInt(json['creditScore'], 100),
        status: asString(json['status'], 'SIGNED'),
        remark: asStringOrNull(json['remark']),
        joinedAt: asDateOrNull(json['joinedAt']),
      );

  String get statusLabel => switch (status) {
        'SIGNED' => '已报名',
        'CANCELED' => '已取消',
        'ATTENDED' => '已到场',
        'ABSENT' => '缺席',
        _ => status,
      };
}
