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

  /// 演示用坐标：北京国贸。桌面预览拿不到真实定位（没装定位插件），
  /// 所以在界面上明说是"演示坐标"，比假装定位到某处诚实。
  static const double demoLng = 116.4610;
  static const double demoLat = 39.9088;

  final List<Activity> feed = <Activity>[];
  String? category;
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

  Future<void> loadMine() async {
    try {
      final org = await _activity.mineOrganized();
      final join = await _activity.mineJoined();
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
