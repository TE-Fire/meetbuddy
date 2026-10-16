import 'json_util.dart';

/// 对应后端 `UserBriefVO`：关注 / 粉丝列表里的一行。
///
/// 只带昵称、头像、信用分与封禁态。手机号之类的隐私字段后端刻意不返回，
/// 这里也就不预留——模型里多一个字段，早晚会有人顺手把 `?? ''` 填上去。
class UserBrief {
  const UserBrief({
    required this.userId,
    required this.nickname,
    this.avatar,
    this.creditScore = 100,
    this.banned = false,
  });

  final int userId;
  final String nickname;
  final String? avatar;
  final int creditScore;

  /// 封禁是状态不是删除：列表里照常出现，只是置灰。
  final bool banned;

  factory UserBrief.fromJson(Map<String, dynamic> json) => UserBrief(
        userId: asInt(json['userId']),
        nickname: asString(json['nickname'], '匿名用户'),
        avatar: asStringOrNull(json['avatar']),
        creditScore: asInt(json['creditScore'], 100),
        banned: asBool(json['banned']),
      );
}
