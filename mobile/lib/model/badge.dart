import 'json_util.dart';

/// 对应后端 `BadgeVO`。
///
/// 两个接口共用它，但回的份量不同：`GET /api/badge/mine` 返回**全部**徽章（含未解锁
/// 与进度，给徽章墙画灰态用），他人主页只嵌**已解锁**的，所以那边 [unlocked] 恒为 true、
/// [progress] 对 [group] 为 `NONE` 的一次性徽章恒为 0。
class Badge {
  const Badge({
    required this.code,
    required this.name,
    this.desc,
    this.icon,
    this.group = 'NONE',
    this.unlocked = false,
    this.unlockedAt,
    this.progress = 0,
    this.target = 0,
  });

  final String code;
  final String name;
  final String? desc;

  /// 徽章自带的 emoji 字形，由后端 `BadgeEnum` 给出——两端展示同一个字形，
  /// 不各写一份映射表，否则改徽章要改三处。
  final String? icon;

  /// 进度所属统计组：NONE / JOINED / HOSTED / ATTENDED / FULL。
  /// `NONE` 是一次性徽章，不展示进度条。
  final String group;

  final bool unlocked;
  final DateTime? unlockedAt;

  /// 当前进度 / 目标值。未解锁且未达标时页面显示 `progress/target`。
  final int progress;
  final int target;

  factory Badge.fromJson(Map<String, dynamic> json) => Badge(
        code: asString(json['code']),
        name: asString(json['name']),
        desc: asStringOrNull(json['desc']),
        icon: asStringOrNull(json['icon']),
        group: asString(json['group'], 'NONE'),
        unlocked: asBool(json['unlocked']),
        unlockedAt: asDateOrNull(json['unlockedAt']),
        progress: asInt(json['progress']),
        target: asInt(json['target']),
      );
}
