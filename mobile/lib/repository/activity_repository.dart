import '../model/activity.dart';
import '../model/activity_draft.dart';
import '../model/page_data.dart';

/// 活动数据源。
abstract class ActivityRepository {
  /// 活动流。传 lng/lat/radius 才会走 GEO 就近筛选，三者缺一后端会静默退化成普通分页。
  ///
  /// [sortBy] 取值 `latest`（默认，发布时间倒序）/ `hot`（报名人数降序）/
  /// `distance`（由近到远）。`distance` 只在传了经纬度时才真正生效，
  /// 否则后端降级成 `latest`——非法值同理，不会报错。
  Future<PageData<Activity>> list({
    String? category,
    String? status,
    String? sortBy,
    double? lng,
    double? lat,
    double? radius,
    int page = 1,
    int size = 20,
  });

  Future<Activity> detail(int id);

  /// 发布活动，返回新活动 id 与创建时一并建好的群 id。
  Future<CreatedActivity> create(ActivityDraft draft);

  /// 编辑活动。字段要求与发布一致（后端复用 `ActivityCreateRequest`，不做部分更新）。
  ///
  /// 后端约束（`ActivityServiceImpl#update`）：只有组织者能改、状态为 OPEN/FULL
  /// 才让改（已开始或结束不再允许）、人数上限不得小于当前已报名人数。
  Future<void> update(int id, ActivityDraft draft);

  /// 报名。满员返回 2001，重复报名返回 2002。
  Future<void> signUp(int id, {String? remark});

  Future<void> cancelSignUp(int id);

  Future<void> cancelActivity(int id);

  Future<void> favorite(int id, {required bool on});

  Future<PageData<Activity>> mineOrganized({int page = 1, int size = 20});

  Future<PageData<Activity>> mineJoined({int page = 1, int size = 20});
}
