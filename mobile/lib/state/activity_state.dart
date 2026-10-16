import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../model/activity.dart';
import '../model/api_exception.dart';
import '../repository/activity_repository.dart';
import '../repository/user_repository.dart';

/// 活动流状态：筛选条件 + 分页 + 我在组织/我报名的两个列表。
///
/// 分页用最简单的一页页追加，不做无限滚动的复杂节流——每页 20 条，
/// 本机演示根本滚不到第三页。
class ActivityState extends ChangeNotifier {
  ActivityState({required ActivityRepository activity, required UserRepository user})
      : _activity = activity,
        _user = user;

  final ActivityRepository _activity;
  final UserRepository _user;

  static const List<String> categories = <String>[
    '剧本杀',
    '运动',
    '探店',
    '桌游',
    '户外',
    '观影',
    '其他',
  ];

  /// 活动标签建议池。发布页与编辑页共用（小程序 `activity-edit.js` 的 `TAG_POOL` 同款），
  /// 放 state 层是因为两页都要用，而页面各存一份迟早漂移。
  static const List<String> tagPool = <String>[
    '新手友好', '硬核', '深夜局', 'AA制', '免费', '带装备', '轻运动', '拍照',
  ];

  /// 演示用坐标：北京国贸。桌面预览拿不到真实定位（没装定位插件），
  /// 所以在界面上明说是"演示坐标"，比假装定位到某处诚实。
  static const double demoLng = 116.4610;
  static const double demoLat = 39.9088;

  final List<Activity> feed = <Activity>[];
  String? category;

  /// 排序方式。取值与后端的 `sortBy` 同名，中间不再翻译一层，
  /// 免得出现"前端写 newest、后端认 latest"这类只在联调时才暴露的偏差。
  /// `distance` 依赖经纬度，未开就近时后端静默降级成 latest —— 界面上那一项
  /// 在未开就近时置灰，不让用户点了发现列表没动、以为坏了。
  String sortBy = 'latest';

  /// 排序选项。只有"值 + 显示名"两个字段，用 record 就够了。
  static const List<({String value, String label})> sorts = <({String value, String label})>[
    (value: 'latest', label: '最新'),
    (value: 'hot', label: '最热'),
    (value: 'distance', label: '最近'),
  ];

  bool geoEnabled = false;
  double radius = 10;

  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;

  final List<Activity> organized = <Activity>[];
  final List<Activity> joined = <Activity>[];

  bool get loading => _loading;
  bool get hasMore => _hasMore;
  String? get error => _error;

  Future<void> loadFeed({bool refresh = true}) async {
    if (refresh) {
      _page = 1;
      _hasMore = true;
      _error = null;
    }
    if (_loading || !_hasMore) {
      return;
    }
    _loading = true;
    notifyListeners();
    try {
      final data = await _activity.list(
        category: category,
        sortBy: sortBy,
        lng: geoEnabled ? demoLng : null,
        lat: geoEnabled ? demoLat : null,
        radius: geoEnabled ? radius : null,
        page: _page,
        size: 20,
      );
      if (refresh) {
        feed
          ..clear()
          ..addAll(data.list);
      } else {
        feed.addAll(data.list);
      }
      _hasMore = _page * data.size < data.total;
      _page += 1;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = '$e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() => loadFeed(refresh: false);

  Future<void> setCategory(String? value) async {
    category = value;
    await loadFeed();
  }

  Future<void> setSort(String value) async {
    if (sortBy == value) {
      return;
    }
    sortBy = value;
    await loadFeed();
  }

  /// 开启就近筛选时顺手把坐标报给后端——不报坐标就进不了 GEO 候选集，
  /// 后面搭子匹配会搜不到自己。mock 下这次调用只是记个位置。
  Future<void> setGeo(bool on) async {
    geoEnabled = on;
    notifyListeners();
    if (on) {
      try {
        await _user.updateLocation(lng: demoLng, lat: demoLat);
      } on ApiException {
        // 上报失败不影响浏览，删掉错误提示即可
      }
    }
    await loadFeed();
  }

  Future<void> setRadius(double km) async {
    radius = km;
    if (geoEnabled) {
      await loadFeed();
    } else {
      notifyListeners();
    }
  }

  /// 拉"我发起的 / 我报名的"两个列表。
  ///
  /// [size] 默认 20（"我的"页只展示计数与列表）；日程页要按日期分组铺满一屏，
  /// 传 100 一次拉全，与小程序 `pages/schedule/schedule.js` 同口径。
  Future<void> loadMine({int size = 20}) async {
    try {
      final org = await _activity.mineOrganized(size: size);
      final join = await _activity.mineJoined(size: size);
      organized
        ..clear()
        ..addAll(org.list);
      joined
        ..clear()
        ..addAll(join.list);
    } on ApiException catch (e) {
      _error = e.message;
    }
    notifyListeners();
  }

  /// 详情页报名/取消后，把列表里的那条同步掉，返回列表时不必整页重拉。
  void patch(Activity updated) {
    for (int i = 0; i < feed.length; i++) {
      if (feed[i].id == updated.id) {
        feed[i] = updated;
      }
    }
    for (int i = 0; i < organized.length; i++) {
      if (organized[i].id == updated.id) {
        organized[i] = updated;
      }
    }
    for (int i = 0; i < joined.length; i++) {
      if (joined[i].id == updated.id) {
        joined[i] = updated;
      }
    }
    notifyListeners();
  }

  /// 与后端的 Haversine 一致。真实模式下排序由后端定，这里只负责把距离显示出来。
  double? distanceFrom(Activity a) {
    if (!geoEnabled || a.lng == null || a.lat == null) {
      return null;
    }
    const earth = 6371.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(a.lat! - demoLat);
    final dLng = rad(a.lng! - demoLng);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(demoLat)) * math.cos(rad(a.lat!)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return earth * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }
}
