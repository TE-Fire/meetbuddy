import 'dart:math';

import '../../model/activity.dart';
import '../../model/activity_draft.dart';
import '../../model/api_exception.dart';
import '../../model/page_data.dart';
import '../activity_repository.dart';
import 'mock_data.dart';
import 'mock_user_repository.dart';

/// 内存活动数据源。
///
/// 刻意的行为对齐（与后端一致，页面才不用为 mock 写特例）：
/// - 满员报名 → 2001；重复报名 → 2002
/// - 传 lng/lat/radius 才做半径筛选，否则退化为按时间倒序的普通分页
/// - 取消活动 → 群仍在，但转为只读并落一条 SYSTEM 消息
class MockActivityRepository implements ActivityRepository {
  MockActivityRepository(this._store, this._userRepo);

  final MockStore _store;
  final MockUserRepository _userRepo;

  static Future<void> _latency([int ms = 260]) => Future<void>.delayed(Duration(milliseconds: ms));

  @override
  Future<PageData<Activity>> list({
    String? category,
    String? status,
    String? sortBy,
    double? lng,
    double? lat,
    double? radius,
    int page = 1,
    int size = 20,
  }) async {
    await _latency();
    _store.ensureSeeded();

    var rows = _store.activities.where((a) => a.status != 'DRAFT').toList();

    if (category != null && category.isNotEmpty) {
      rows = rows.where((a) => a.category == category).toList();
    }
    if (status != null && status.isNotEmpty) {
      rows = rows.where((a) => a.status == status).toList();
    }

    final useGeo = lng != null && lat != null && radius != null;
    if (useGeo) {
      rows = rows.where((a) => MockStore.distanceKm(lng, lat, a.lng, a.lat) <= radius).toList();
    }

    // 与真实后端同一套规则：distance 只在地理模式下才有意义，其余情况一律降级 latest。
    if (sortBy == 'hot') {
      rows.sort((a, b) => b.currentParticipants.compareTo(a.currentParticipants));
    } else if (sortBy == 'distance' && useGeo) {
      rows.sort((a, b) => MockStore.distanceKm(lng, lat, a.lng, a.lat)
          .compareTo(MockStore.distanceKm(lng, lat, b.lng, b.lat)));
    } else {
      rows.sort((a, b) => b.startTime.compareTo(a.startTime));
    }

    return _paginate(rows, page, size, (r) => _store.toListItem(r));
  }

  @override
  Future<Activity> detail(int id) async {
    await _latency(180);
    _store.ensureSeeded();
    final r = _store.activity(id);
    if (r == null) {
      throw ApiException(1004, '活动不存在');
    }
    return _store.toDetail(r, _store.currentUserId);
  }

  @override
  Future<CreatedActivity> create(ActivityDraft draft) async {
    await _latency(420);
    _store.ensureSeeded();

    if (draft.title.trim().isEmpty) {
      throw ApiException(1001, '标题不能为空');
    }
    if (!draft.endTime.isAfter(draft.startTime)) {
      throw ApiException(1001, '结束时间必须晚于开始时间');
    }

    final record = _store.addActivity(
      title: draft.title.trim(),
      category: draft.category,
      description: draft.description ?? '',
      address: draft.address,
      lng: draft.lng,
      lat: draft.lat,
      startTime: draft.startTime,
      endTime: draft.endTime,
      maxParticipants: draft.maxParticipants,
      organizerId: _store.currentUserId,
      tags: draft.tags,
      coverUrl: draft.coverUrl,
      images: draft.images,
    );
    // 后端是"创建即建群、本人即群主"，mock 必须一样，否则进群聊那步对不上。
    final group = _store.attachGroup(record, name: '${record.title} 群');
    _store.addGroupMessage(group.id, 0, '${_store.me.nickname} 创建了群聊「${record.title}」', msgType: 'SYSTEM');
    return CreatedActivity(id: record.id, groupId: group.id);
  }

  @override
  Future<void> update(int id, ActivityDraft draft) async {
    await _latency(420);
    _store.ensureSeeded();

    final r = _store.activity(id);
    if (r == null) {
      throw ApiException(1004, '活动不存在');
    }
    if (r.organizerId != _store.currentUserId) {
      // 403 与 cancelActivity 同口径：mock 里"越权"一律用 HTTP 语义的 403
      throw ApiException(403, '只有组织者可以编辑');
    }
    // 与后端同口径：OPEN/FULL 才让改，已开始或结束不再允许（避免改期影响已到场的人）
    if (r.status != 'OPEN' && r.status != 'FULL') {
      throw ApiException(1001, '活动已开始或已结束，无法编辑');
    }
    if (!draft.endTime.isAfter(draft.startTime)) {
      throw ApiException(1001, '结束时间必须晚于开始时间');
    }
    if (draft.maxParticipants < r.currentParticipants) {
      throw ApiException(1001, '人数上限不能小于当前已报名人数 ${r.currentParticipants}');
    }

    r
      ..title = draft.title.trim()
      ..category = draft.category
      ..description = draft.description ?? ''
      ..address = draft.address
      ..lng = draft.lng
      ..lat = draft.lat
      ..startTime = draft.startTime
      ..endTime = draft.endTime
      ..maxParticipants = draft.maxParticipants
      ..creditRequired = draft.creditRequired
      ..tags = draft.tags.toList()
      ..images = draft.images.toList()
      ..coverUrl = draft.coverUrl;
  }

  @override
  Future<void> signUp(int id, {String? remark}) async {
    await _latency(380);
    final r = _store.activity(id);
    if (r == null) {
      throw ApiException(1004, '活动不存在');
    }
    final me = _store.currentUserId;
    if (r.organizerId == me) {
      throw ApiException(2002, '你是组织者，无需报名');
    }
    if (r.signedUp.contains(me)) {
      throw ApiException(2002, '你已报名该活动');
    }
    if (r.currentParticipants >= r.maxParticipants) {
      throw ApiException(2001, '活动已满员');
    }
    if (r.status != 'OPEN') {
      throw ApiException(1004, '活动已不接受报名');
    }
    r.signedUp.add(me);
    if (r.currentParticipants >= r.maxParticipants) {
      r.status = 'FULL';
    }
    // 报名即入群
    final g = r.groupId == null ? null : _store.group(r.groupId!);
    if (g != null && !g.members.contains(me)) {
      g.members.add(me);
      g.roleOf[me] = 'MEMBER';
      _store.addGroupMessage(g.id, 0, '${_store.me.nickname} 加入了群聊', msgType: 'SYSTEM');
    }
  }

  @override
  Future<void> cancelSignUp(int id) async {
    await _latency(300);
    final r = _store.activity(id);
    if (r == null) {
      throw ApiException(1004, '活动不存在');
    }
    final me = _store.currentUserId;
    if (!r.signedUp.remove(me)) {
      throw ApiException(1004, '尚未报名该活动');
    }
    if (r.status == 'FULL') {
      r.status = 'OPEN';
    }
  }

  @override
  Future<void> cancelActivity(int id) async {
    await _latency(360);
    final r = _store.activity(id);
    if (r == null) {
      throw ApiException(1004, '活动不存在');
    }
    if (r.organizerId != _store.currentUserId) {
      throw ApiException(403, '只有组织者可以取消活动');
    }
    r.status = 'CANCELLED';
    final g = r.groupId == null ? null : _store.group(r.groupId!);
    if (g != null) {
      g.readonly = true;
      _store.addGroupMessage(g.id, 0, '活动已被组织者取消，群聊转为只读', msgType: 'SYSTEM');
    }
  }

  @override
  Future<void> favorite(int id, {required bool on}) async {
    await _latency(200);
    final r = _store.activity(id);
    if (r == null) {
      throw ApiException(1004, '活动不存在');
    }
    if (on) {
      r.favoritedBy.add(_store.currentUserId);
    } else {
      r.favoritedBy.remove(_store.currentUserId);
    }
  }

  @override
  Future<PageData<Activity>> mineOrganized({int page = 1, int size = 20}) async {
    await _latency();
    _store.ensureSeeded();
    final rows = _store.activities.where((a) => a.organizerId == _store.currentUserId).toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    return _paginate(rows, page, size, (r) => _store.toListItem(r));
  }

  @override
  Future<PageData<Activity>> mineJoined({int page = 1, int size = 20}) async {
    await _latency();
    _store.ensureSeeded();
    final rows = _store.activities
        .where((a) => a.signedUp.contains(_store.currentUserId))
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    return _paginate(rows, page, size, (r) => _store.toListItem(r));
  }

  PageData<Activity> _paginate(
    List<MockActivityRecord> rows,
    int page,
    int size,
    Activity Function(MockActivityRecord) map,
  ) {
    final from = (page - 1) * size;
    final to = min(from + size, rows.length);
    final slice = from >= rows.length ? <MockActivityRecord>[] : rows.sublist(from, to);
    return PageData<Activity>(
      list: slice.map(map).toList(),
      total: rows.length,
      page: page,
      size: size,
    );
  }

  /// 上报坐标时同步更新（组合根在启动时调一次），供列表页算距离。
  Future<void> primeLocation() async {
    if (_userRepo.lastLat == null) {
      await _userRepo.updateLocation(lng: 116.4610, lat: 39.9088);
    }
  }
}
