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
    this.tags = const <String>[],
  });

  final int id;
  final String phone;
  final String nickname;
  final String? avatar;
  final int? gender;
  final String? bio;
  final int creditScore;

  /// 兴趣标签。`GET /user/me` 与 `PUT /user/profile` 都回传，用于"我的"页展示与编辑；
  /// 匹配算法里标签重合占 0.3 权重，所以这份不是纯展示数据。
  final List<String> tags;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: asInt(json['id']),
        phone: asString(json['phone']),
        nickname: asString(json['nickname'], '匿名用户'),
        avatar: asStringOrNull(json['avatar']),
        gender: asIntOrNull(json['gender']),
        bio: asStringOrNull(json['bio']),
        creditScore: asInt(json['creditScore'], 100),
        tags: asStringList(json['tags']),
      );

  User copyWith({
    String? nickname,
    String? avatar,
    String? bio,
    int? gender,
    List<String>? tags,
  }) =>
      User(
        id: id,
        phone: phone,
        nickname: nickname ?? this.nickname,
        avatar: avatar ?? this.avatar,
        gender: gender ?? this.gender,
        bio: bio ?? this.bio,
        creditScore: creditScore,
        tags: tags ?? this.tags,
      );
}
