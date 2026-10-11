import 'json_util.dart';

/// 发布活动的入参，字段与后端 ActivityCreateRequest 一一对应。
class ActivityDraft {
  const ActivityDraft({
    required this.title,
    required this.category,
    required this.address,
    required this.lng,
    required this.lat,
    required this.startTime,
    required this.endTime,
    required this.maxParticipants,
    this.description,
    this.coverUrl,
    this.creditRequired = 60,
    this.tags = const <String>[],
    this.images = const <String>[],
  });

  final String title;
  final String category;
  final String address;
  final double lng;
  final double lat;
  final DateTime startTime;
  final DateTime endTime;
  final int maxParticipants;
  final String? description;
  final String? coverUrl;
  final int creditRequired;
  final List<String> tags;
  final List<String> images;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'category': category,
        'description': description,
        'coverUrl': coverUrl,
        'lng': lng,
        'lat': lat,
        'address': address,
        'startTime': _localIso(startTime),
        'endTime': _localIso(endTime),
        'maxParticipants': maxParticipants,
        'creditRequired': creditRequired,
        'tags': tags,
        'images': images,
      };
}

/// 后端字段是 Java LocalDateTime，Jackson 认 `2026-10-11T19:00:00` 这种不带时区的写法。
/// 不能用 `toIso8601String()`：它带毫秒，UTC 时间还会补一个 `Z`，LocalDateTime 解析不了。
String _localIso(DateTime dt) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)}'
      'T${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
}

/// 发布活动的出参。建群与建活动同时完成，后端直接把 groupId 带回来了。
class CreatedActivity {
  const CreatedActivity({required this.id, this.groupId});

  final int id;
  final int? groupId;

  factory CreatedActivity.fromJson(Map<String, dynamic> json) => CreatedActivity(
        id: asInt(json['id']),
        groupId: asIntOrNull(json['groupId']),
      );
}
