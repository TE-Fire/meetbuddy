import 'package:flutter/foundation.dart';

import '../model/buddy.dart';
import '../model/api_exception.dart';
import '../repository/buddy_repository.dart';
import '../state/activity_state.dart';

/// 找搭子页面状态。
///
/// 演示坐标沿用活动流（北京国贸）——小程序整体未接真实定位，匹配页得用同一坐标，
/// 两边的"附近"才一致。半径选项与小程序 `buddy.js` 对齐。
class BuddyState extends ChangeNotifier {
  BuddyState({required BuddyRepository repo}) : _repo = repo;

  final BuddyRepository _repo;

  static const List<double> radiusOptions = <double>[5, 10, 25, 50];

  List<BuddyMatch> matches = const <BuddyMatch>[];
  List<BuddyRequest> mine = const <BuddyRequest>[];
  double radius = 10;
  bool matchLoading = false;
  bool mineLoading = false;
  String? matchError;
  String? mineError;

  Future<void> loadMatches() async {
    if (matchLoading) {
      return;
    }
    matchLoading = true;
    matchError = null;
    notifyListeners();
    try {
      matches = await _repo.match(
        lng: ActivityState.demoLng,
        lat: ActivityState.demoLat,
        radius: radius,
      );
    } on ApiException catch (e) {
      matchError = e.message;
    } finally {
      matchLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMine() async {
    if (mineLoading) {
      return;
    }
    mineLoading = true;
    mineError = null;
    notifyListeners();
    try {
      mine = await _repo.mine();
    } on ApiException catch (e) {
      mineError = e.message;
    } finally {
      mineLoading = false;
      notifyListeners();
    }
  }

  Future<void> changeRadius(double next) async {
    if (next == radius) {
      return;
    }
    radius = next;
    notifyListeners();
    await loadMatches();
  }

  Future<int> create({
    required String title,
    String? description,
    required String category,
    String? timeRange,
    required List<String> tags,
  }) async {
    final id = await _repo.create(
      title: title,
      description: description,
      category: category,
      lng: ActivityState.demoLng,
      lat: ActivityState.demoLat,
      timeRange: timeRange,
      tags: tags,
    );
    await loadMine();
    return id;
  }

  Future<void> close(int id) async {
    await _repo.close(id);
    await loadMine();
  }
}
