import '../model/activity.dart';
import '../model/activity_draft.dart';
import '../model/page_data.dart';

/// 活动数据源。
abstract class ActivityRepository {
  /// 活动流。传 lng/lat/radius 才会走 GEO 就近筛选，三者缺一后端会静默退化成普通分页。
  Future<PageData<Activity>> list({
    String? category,
    String? status,
    double? lng,
    double? lat,
    double? radius,
    int page = 1,
    int size = 20,
  });

  Future<Activity> detail(int id);

  /// 发布活动，返回新活动 id 与创建时一并建好的群 id。
  Future<CreatedActivity> create(ActivityDraft draft);

  /// 报名。满员返回 2001，重复报名返回 2002。
  Future<void> signUp(int id, {String? remark});

  Future<void> cancelSignUp(int id);

  Future<void> cancelActivity(int id);

  Future<void> favorite(int id, {required bool on});

  Future<PageData<Activity>> mineOrganized({int page = 1, int size = 20});

  Future<PageData<Activity>> mineJoined({int page = 1, int size = 20});
}
