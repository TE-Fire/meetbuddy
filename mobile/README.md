# meetbuddy-mobile · 用户端 App

Flutter 用户端。对应里程碑 **M5**，当前尚未开工（M0~M3 都在后端）。

## 技术栈与版本

| 项 | 版本 / 位置 |
|---|---|
| Flutter | 3.47.7 stable（Dart 3.13.5） |
| SDK 路径 | `D:\Flutter`，已加入用户级 `PATH` |
| 预览目标 | Edge（`flutter run -d edge`） |
| 状态管理 | 待定，M5 开工时在 `docs/01` 补一条决策 |
| 网络层 | 按 `docs/03` 的契约；统一信封 + `Authorization: Bearer` |

**不装 Android Studio、不装安卓模拟器**——本机磁盘和内存紧张。桌面开发阶段一律用浏览器预览，只有最后需要地图 / 相机 / 推送等原生能力时，才装最小 Android SDK（cmdline-tools + 单个 platform + build-tools）并用真机 USB 调试。

## 依赖的国内镜像

已配置在用户环境变量里：

```
PUB_HOSTED_URL=https://pub.flutter-io.cn
FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

## 启动

```bash
cd mobile
flutter pub get
flutter run -d edge
```

首次运行 `flutter --version` 会触发 "Building flutter tool"，约 4~5 分钟，属正常。

## 目录规划（M5 开工时落地）

```
mobile/lib/
├─ config/       环境开关（mock / 真实数据源切换，编译期常量）
├─ repository/   数据源层：同一套接口，mock 与真实实现二选一
├─ model/        与 docs/03 的响应体一一对应
├─ page/         页面
└─ widget/       复用组件
```

`docs/01` 第三节定了：mock 与真实数据源走同一个 repository 接口，切换靠编译期开关，**不允许在业务代码里写 `if (isMock)`**。

## 为什么现在只有这份 README

`docs/01` 要求「每个模块自带 README，写清启动方式和依赖版本」。后端（`server/`）已具备，这个目录先按同样的规格立住，M5 时往里填代码，避免到时候临时决定目录分层。
