/// 服务端业务错误。code 取自 docs/03 第一节的错误码表。
///
/// 用异常而不是返回 Result 对象：repository 的方法因此可以直接返回业务数据，
/// 页面里不必层层写 `if (r.code != 0)`；失败统一在调用处 try/catch。
class ApiException implements Exception {
  ApiException(this.code, this.message);

  final int code;
  final String message;

  /// 401 —— 未登录或令牌过期。按契约，前端见到它应清掉登录态、跳登录页。
  bool get isUnauthorized => code == 401;

  /// 网络层失败（连不上、超时、响应不是 JSON）统一用 -1，与业务错误码区分开。
  bool get isNetwork => code == -1;

  @override
  String toString() => 'ApiException($code, $message)';
}
