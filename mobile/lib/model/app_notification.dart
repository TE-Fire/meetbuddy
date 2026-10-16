import 'json_util.dart';

/// 通知点击后的去向。
///
/// 后端只给了 `bizId`，跳哪儿完全由 `type` 决定——同一个 bizId 字段，在活动类通知里
/// 是活动 id，在 `USER_FOLLOWED` 里是**关注者的用户 id**。这个语义差异必须收在一处，
/// 散在页面里就会出现"点关注通知跳到一个不存在的活动"。
enum NotificationTarget { none, activity, user }

/// 站内通知，对应后端 `NotificationVO`。规则见 `docs/05-通知与提醒.md`。
///
/// 不叫 `Notification`：Flutter 的 material 里已有同名类（Widget 的祖先通知气泡），
/// 页面里两个都要用，撞名之后只能靠 `hide` 或前缀硬扛。
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    this.title,
    this.content = '',
    this.bizId,
    this.read = false,
    this.createdAt,
  });

  final int id;

  /// SIGNUP_NEW / ACTIVITY_CANCELLED / ACTIVITY_REMINDER / ACTIVITY_TAKEDOWN
  /// / REPORT_HANDLED / BADGE_UNLOCKED / USER_FOLLOWED
  final String type;

  final String? title;
  final String content;

  /// 跳转目标 id，语义随 [type] 变（见 [target]）。可为空，为空时不可跳。
  final int? bizId;

  /// 后端给的是 0/1，这里转成 bool——`readStatus == 0` 这种判断在页面里
  /// 早晚会被写成 `if (!n.readStatus)`，那在 Dart 里是编译错误而不是静默 bug，不如现在就统一。
  final bool read;

  final DateTime? createdAt;

  NotificationTarget get target => switch (type) {
        'SIGNUP_NEW' ||
        'ACTIVITY_CANCELLED' ||
        'ACTIVITY_REMINDER' ||
        'ACTIVITY_TAKEDOWN' =>
          bizId == null ? NotificationTarget.none : NotificationTarget.activity,
        'USER_FOLLOWED' =>
          bizId == null ? NotificationTarget.none : NotificationTarget.user,
        _ => NotificationTarget.none,
      };

  bool get jumpable => target != NotificationTarget.none;

  AppNotification asRead() => AppNotification(
        id: id,
        type: type,
        title: title,
        content: content,
        bizId: bizId,
        read: true,
        createdAt: createdAt,
      );

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: asInt(json['id']),
        type: asString(json['type']),
        title: asStringOrNull(json['title']),
        content: asString(json['content']),
        bizId: asIntOrNull(json['bizId']),
        read: asInt(json['readStatus']) != 0,
        createdAt: asDateOrNull(json['createdAt']),
      );
}
