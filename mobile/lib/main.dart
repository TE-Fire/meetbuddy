import 'package:flutter/material.dart';

import 'app.dart';
import 'app_scope.dart';

/// 入口。
///
/// 组合根在 runApp 之前建好，保证 Provider 树里的每个 state 拿到的是同一批
/// repository / socket 实例——尤其是 mock 模式下的 [MockStore]，
/// 建两份就会出现"发布页新建的活动在列表页看不到"。
void main() {
  final scope = AppScope.build();
  runApp(MeetbuddyApp(scope: scope));
}
