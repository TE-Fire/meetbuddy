import 'json_util.dart';

/// 他人主页的「最近完成」条目，对应后端 `UserProfileVO.RecentActivity`。
///
/// 刻意不直接复用 [Activity]：这个 VO 只有 6 个字段，用 Activity 接会产出一批
/// "除标题外全是默认值"的对象——页面哪天多读一个字段（比如 `address`），拿到的是
/// 空串而不是报错，属于最难查的那种静默错误。窄接口在这里比复用值钱。
class RecentActivity {
  const RecentActivity({
    required this.id,
    required this.title,
    this.coverUrl,
    this.status = '',
    this.startTime,
    this.role = 'PARTICIPANT',
  });

  final int id;
  final String title;
  final String? coverUrl;
  final String status;
  final DateTime? startTime;

  /// ORGANIZER 组织的 / PARTICIPANT 参加的
  final String role;

  bool get isOrganizer => role == 'ORGANIZER';

  String get roleLabel => isOrganizer ? '组织' : '参与';

  String get statusLabel => switch (status) {
        'OPEN' => '报名中',
        'FULL' => '已满',
        'ONGOING' => '进行中',
        'FINISHED' => '已结束',
        'CANCELLED' => '已取消',
        _ => status,
      };

  factory RecentActivity.fromJson(Map<String, dynamic> json) => RecentActivity(
        id: asInt(json['id']),
        title: asString(json['title']),
        coverUrl: asStringOrNull(json['coverUrl']),
        status: asString(json['status']),
        startTime: asDateOrNull(json['startTime']),
        role: asString(json['role'], 'PARTICIPANT'),
      );
}
