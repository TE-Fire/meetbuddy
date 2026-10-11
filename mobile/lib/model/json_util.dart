// JSON 取值的转换小工具。
//
// jsonDecode 出来的值都是 dynamic，每个 fromJson 里都写一遍 `as num` 会又长又容易漏判空。
// 集中放这里，语义是"后端字段类型基本可信，但类型不对时给一个安全的兜底值"。

int asInt(dynamic v, [int fallback = 0]) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

int? asIntOrNull(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? asDoubleOrNull(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

String asString(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  return v.toString();
}

String? asStringOrNull(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

bool asBool(dynamic v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v == 'true';
  return fallback;
}

/// 后端时间字段是 Java LocalDateTime，Jackson 序列化成 ISO 字符串（2026-10-11T19:00:00）。
DateTime? asDateOrNull(dynamic v) {
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  return null;
}

List<String> asStringList(dynamic v) {
  if (v is List) return v.map((e) => e.toString()).toList();
  return const <String>[];
}

/// 把信封里的 `data` 当对象取。后端返回 `data: null` 时给个空 map，让 fromJson 走兜底值。
Map<String, dynamic> asMap(dynamic v) =>
    v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

List<Map<String, dynamic>> asMapList(dynamic v) {
  if (v is List) {
    return v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }
  return const <Map<String, dynamic>>[];
}
