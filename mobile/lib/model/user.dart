import 'json_util.dart';

/// 对应后端 UserVO。刻意不含 passwordHash —— 后端用 VO 隔离实体，这里保持一致。
class User {
  const User({
    required this.id,
    required this.phone,
    required this.nickname,
    this.avatar,
    this.gender,
    this.bio,
    this.creditScore = 100,
  });

  final int id;
  final String phone;
  final String nickname;
  final String? avatar;
  final int? gender;
  final String? bio;
  final int creditScore;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: asInt(json['id']),
        phone: asString(json['phone']),
        nickname: asString(json['nickname'], '匿名用户'),
        avatar: asStringOrNull(json['avatar']),
        gender: asIntOrNull(json['gender']),
        bio: asStringOrNull(json['bio']),
        creditScore: asInt(json['creditScore'], 100),
      );

  User copyWith({String? nickname, String? avatar, String? bio, int? gender}) => User(
        id: id,
        phone: phone,
        nickname: nickname ?? this.nickname,
        avatar: avatar ?? this.avatar,
        gender: gender ?? this.gender,
        bio: bio ?? this.bio,
        creditScore: creditScore,
      );
}
