import 'json_util.dart';

/// 对应后端 `CreditLogVO`。规则见 `docs/06-成就勋章与个人主页.md`。
class CreditLog {
  const CreditLog({
    required this.id,
    required this.changeValue,
    this.reason = '',
    this.relatedId,
    this.operatorId,
    this.balanceAfter,
    this.createdAt,
  });

  final int id;

  /// 正数为加，负数为减。
  final int changeValue;

  /// 扣分原因，直接展示给用户——被扣分要看得见原因。
  final String reason;

  /// 关联活动或举报，可按 type 跳转。
  final int? relatedId;

  /// 管理端调整时非空。
  final int? operatorId;

  /// 本次变动后的分数。
  final int? balanceAfter;

  final DateTime? createdAt;

  bool get plus => changeValue > 0;

  /// 带符号的变动值文案：`+10` / `-10`。零值不画符号（后端目前不会产生 0 变更）。
  String get valueText => plus ? '+$changeValue' : '$changeValue';

  factory CreditLog.fromJson(Map<String, dynamic> json) => CreditLog(
        id: asInt(json['id']),
        changeValue: asInt(json['changeValue']),
        reason: asString(json['reason']),
        relatedId: asIntOrNull(json['relatedId']),
        operatorId: asIntOrNull(json['operatorId']),
        balanceAfter: asIntOrNull(json['balanceAfter']),
        createdAt: asDateOrNull(json['createdAt']),
      );
}
