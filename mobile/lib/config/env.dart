// 编译期环境开关。
//
// 全部用 String.fromEnvironment / bool.fromEnvironment 取，值由 flutter run 时的
// --dart-define 注入，编译期就定死——release 包里不会残留 mock 代码路径。
//
// 用法：
//   flutter run -d edge                                   连真实后端（默认）
//   flutter run -d edge --dart-define=USE_MOCK=true       纯前端假数据，不用起后端
//   flutter run -d edge --dart-define=API_BASE=http://192.168.1.5:8099
class Env {
  const Env._();

  /// 是否使用内存假数据。见 docs/01 第八节：全项目只有组合根一处允许读它。
  static const bool useMock = bool.fromEnvironment('USE_MOCK');

  /// 后端 HTTP 根地址，默认端口对应 server/run-local.sh。
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://127.0.0.1:8099',
  );

  /// WebSocket 根地址。默认与 [apiBase] 同源，只把 scheme 换成 ws。
  static String get wsBase {
    const explicit = String.fromEnvironment('WS_BASE');
    if (explicit.isNotEmpty) {
      return explicit;
    }
    return apiBase.replaceFirst('http', 'ws');
  }

  /// 当前数据源的名字，登录页右上角展示，避免演示时忘了切没切 mock。
  static String get sourceLabel => useMock ? 'MOCK' : apiBase;
}
