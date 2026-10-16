import 'badge.dart';
import 'json_util.dart';
import 'recent_activity.dart';

/// 对应后端 `UserProfileVO`：他人个人主页。
///
/// 也用来取自己的关注/粉丝计数——后端就这一个口径，`following` 字段表达
/// "当前登录用户是否已关注 TA"，看自己时恒为 false。
/// 刻意不含手机号：后端不返回，模型层也不预留这个字段。
class UserProfile {
  const UserProfile({
    required this.userId,
    required this.nickname,
    this.avatar,
    this.bio,
    this.creditScore,
    this.banned = false,
    this.tags = const <String>[],
    this.badges = const <Badge>[],
    this.recentActivities = const <RecentActivity>[],
    this.hostedCount = 0,
    this.joinedCount = 0,
    this.followerCount = 0,
    this.followingCount = 0,
    this.following = false,
  });

  final int userId;
  final String nickname;
  final String? avatar;
  final String? bio;
  final int? creditScore;

  /// 封禁是状态不是删除：主页照常可见，只是置灰提示。
  final bool banned;

  final List<String> tags;

  /// 已解锁的徽章。这里拿不到未解锁项与进度——那要 `GET /api/badge/mine`，
  /// 徽章页（第 3 批）才需要。
  final List<Badge> badges;

  /// 最近完成的活动，组织与参加合并，后端已按开始时间倒序。
  final List<RecentActivity> recentActivities;

  /// 已完成（FINISHED）的：组织的活动数 / 有效参与的活动数
  final int hostedCount;
  final int joinedCount;

  /// 粉丝数（关注 TA 的人）/ 关注数（TA 关注了多少人）
  final int followerCount;
  final int followingCount;

  /// 当前登录用户是否已关注 TA
  final bool following;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        userId: asInt(json['userId']),
        nickname: asString(json['nickname'], '匿名用户'),
        avatar: asStringOrNull(json['avatar']),
        bio: asStringOrNull(json['bio']),
        creditScore: asIntOrNull(json['creditScore']),
        banned: asBool(json['banned']),
        tags: asStringList(json['tags']),
        badges: asMapList(json['badges']).map(Badge.fromJson).toList(),
        recentActivities:
            asMapList(json['recentActivities']).map(RecentActivity.fromJson).toList(),
        hostedCount: asInt(json['hostedCount']),
        joinedCount: asInt(json['joinedCount']),
        followerCount: asInt(json['followerCount']),
        followingCount: asInt(json['followingCount']),
        following: asBool(json['following']),
      );

  /// 只覆盖"会因为一次点击而变"的两个字段：关注态与粉丝数。
  /// 其余字段照抄——让关注按钮能乐观更新，不必为了翻转一个 bool 重新拉整页。
  UserProfile copyWith({bool? following, int? followerCount}) => UserProfile(
        userId: userId,
        nickname: nickname,
        avatar: avatar,
        bio: bio,
        creditScore: creditScore,
        banned: banned,
        tags: tags,
        badges: badges,
        recentActivities: recentActivities,
        hostedCount: hostedCount,
        joinedCount: joinedCount,
        followerCount: followerCount ?? this.followerCount,
        followingCount: followingCount,
        following: following ?? this.following,
      );
}
