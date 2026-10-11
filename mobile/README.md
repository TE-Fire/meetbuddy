# meetbuddy-mobile · 用户端 App

Flutter 用户端，对应里程碑 **M5**。技术选型见 `docs/01` 第八节。

## 技术栈与版本

| 项 | 版本 / 位置 |
|---|---|
| Flutter | 3.47.7 stable（Dart 3.13.5） |
| SDK 路径 | `D:\Flutter`，已加入用户级 `PATH` |
| 预览目标 | Edge（`flutter run -d edge`） |
| 状态管理 | Provider + ChangeNotifier |
| 网络 | `http`（统一信封 + Bearer） |
| 实时 | `web_socket_channel`（Web 上 `dart:io` 的 WebSocket 不可用） |
| 本地存储 | `shared_preferences`（令牌与用户缓存） |

**不装 Android Studio、不装安卓模拟器**——本机磁盘和内存紧张。桌面开发阶段一律用浏览器预览，只有最后需要地图 / 相机 / 推送等原生能力时，才装最小 Android SDK（cmdline-tools + 单个 platform + build-tools）并用真机 USB 调试。地图选点因此简化为"预设地标 + 手填详细地址"，经纬度是真的，GEO 链路照常跑通。

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
flutter run -d edge                    # 连真实后端（默认 127.0.0.1:8099）
```

首次运行 `flutter --version` 会触发 "Building flutter tool"，约 4~5 分钟，属正常。

### 三种数据源

切换走编译期常量，**不改代码**：

```bash
flutter run -d edge                                    # 连真实后端
flutter run -d edge --dart-define=USE_MOCK=true         # 纯前端假数据，后端可以不开
flutter run -d edge --dart-define=API_BASE=http://192.168.1.5:8099
```

`USE_MOCK` 用 `bool.fromEnvironment` 取，编译期定死，release 包里不残留 mock 分支。

mock 模式下的演示账号：**13800000001 / 123456**，验证码固定 `123456`。数据在内存里，刷新页面即重置。

> 连真实后端时后端必须已起（`bash server/run-local.sh`），且 Redis 要走 Docker 里的 7.x——
> 本机 6379 那个 3.0.504 不支持 GEO。跨域已由后端 `WebMvcConfig#addCorsMappings` 放开
> `localhost` / `127.0.0.1` 全端口，见 `server/README.md` 的「跨域」一节。

## 目录结构

```
mobile/lib/
├─ config/env.dart          编译期常量：USE_MOCK / API_BASE / WS_BASE
├─ app_scope.dart           组合根，全项目唯一读 Env.useMock 的地方
├─ app.dart                 主题、Provider 装配、登录门卫
├─ main.dart                入口
├─ repository/
│  ├─ api_client.dart       HTTP 封装：统一信封、Bearer、错误码转 ApiException
│  ├─ *_repository.dart     抽象接口
│  ├─ real/                 真实数据源
│  └─ mock/                 内存假数据（MockStore 单例，页面间共享同一份数据）
├─ model/                   与 docs/03 的响应体一一对应
├─ state/                   SessionState / ActivityState / ChatState
├─ page/                    页面
└─ widget/                  复用组件
```

`docs/01` 第三节定的规矩：mock 与真实数据源走同一个 repository 接口，切换靠编译期开关，**业务代码里不允许出现 `if (isMock)`**。落地方式就是 `app_scope.dart` 一处分支。

## 页面与 M5 验收路径

| 页面 | 作用 |
|---|---|
| `login_page` | 密码登录 / 验证码登录 / 注册，三个 Tab |
| `activity_feed_page` | 活动流：分类筛选、可选就近筛选（演示坐标：国贸）与半径、下拉刷新、加载更多 |
| `activity_create_page` | 发起活动：标题、分类、时间、地标、人数、信用分门槛、标签、介绍 |
| `activity_detail_page` | 详情、参与者、收藏、报名 / 取消报名 / 取消活动、进群聊入口 |
| `chat_list_page` | 我的群列表，带最后一条消息、未读数、实时连接状态 |
| `chat_room_page` | 群聊正文：乐观发送、ack 转正、离线补发渲染、只读置灰 |
| `profile_page` | 我的资料、信用分、我发起的 / 我报名的、退出登录 |

M5 的验收标准是「浏览器中完整走通发布→报名→进群聊」，实测过程与结果见本文件末尾。

## mock 与后端的行为对齐点

mock 不做成"随便返回点数据"，否则一切数据源就露馅。以下六条与后端逐条对齐，切过去不用改页面：

1. 满员报名返 `2001`，重复报名返 `2002`
2. `lng`/`lat`/`radius` 三个都传才做半径筛选，否则退化为按时间倒序的普通分页
3. 创建活动即建群，创建者自动是群主
4. 取消活动后群不解散，转只读并落一条 `SYSTEM` 消息，发言被 `3104` 拒
5. 群聊未读用"每人每群一个游标"，不是 per-message 已读位
6. 单聊也推给发送者自己（多端同步口径与群聊一致）

## 实测记录（2026-10-11）

`flutter analyze --no-pub`：**No issues found**。

浏览器验收（本机 Edge headless + Flutter 语义树驱动，脚本与截图在个人 workspace / `D:/_download/m5_shots/`，不入库）：**14/14 通过，浏览器控制台无 error**。

| # | 步骤 | 结果 |
|---|---|---|
| 1 | 页面加载且无渲染报错 | ✅ |
| 2 | A（13800000011）密码登录进入主页 | ✅ |
| 3 | A 发布活动「国贸羽毛球双打缺两人」并回到列表 | ✅ |
| 4 | A 打开活动详情（已报名 0 人） | ✅ |
| 5 | A 进群聊发出「集合点定在球场门口，带好水」 | ✅ |
| 6 | A 退出登录回到登录页 | ✅ |
| 7 | B（13800000002）密码登录进入主页 | ✅ |
| 8 | B 打开详情看到报名入口 | ✅ |
| 9 | B 报名成功，详情页计数变「已报名 1 人」 | ✅ |
| 10 | B 进群看到 A 的历史消息 | ✅ |
| 11 | B 回复「收到，我带两瓶水过来」 | ✅ |
| 12 | B 退出登录 | ✅ |
| 13 | A 重新登录，消息列表出现该群与 B 的回复 | ✅ |
| 14 | A 进群看到 B 的回复（服务端实时广播） | ✅ |

数据核对（跑完查库）：活动 1、报名 1、群 1、群成员 2、消息 2（发送者 4=阿探、5=林小满），全部经真实后端落库，非 mock。

过程中修掉两个问题：

1. **「我的」页运行时崩溃**——`ChatRoomPage.dispose()` 里用了 `context`，点返回键退出群聊即触发。根因与修法见「踩过的坑」最后一条。
2. **验收脚本点不到 AppBar 上的「退出登录」**——不是应用的问题：按钮语义节点中心 y≈28，脚本"低于 70 视为被 AppBar 遮住"的守卫把它当成屏外元素，无限滚动到超时。已在脚本里给 AppBar 目标放开阈值（`{ minY: 6 }`）。这条写下来是为了下次排查时先分清"应用坏了"还是"脚本点不到"。

## 视觉与动效规范（2026-10-11 重构）

UI 按"小红书/即刻"式的年轻化方向整体重构过一轮，基元全部收敛在 `lib/widget/ui.dart`，页面里不允许散落手写 `Color(0x...)` 与 `BoxShadow`：

| 基元 | 用途 |
|---|---|
| `AppBrand` | 品牌色（靛蓝 `#5B7FFF` → 紫 `#8E5CFF` 渐变）、ink/muted 文字色、卡片弥散阴影 `card`、品牌投影 `glow` |
| `PressableScale` | 按压缩放反馈（0.97），可点卡片统一包它 |
| `StaggeredIn` | 列表按 index 逐个延迟入场（淡入 + 上浮），用 Interval 曲线实现延迟，不用 Timer |
| `PrimaryButton` | 渐变主按钮，禁用整体变灰、busy 转圈且高度不跳；自带 `role=button` 语义 |
| `SkeletonBox` / `SkeletonList` | 骨架屏脉冲，替代首屏转圈 |
| `SectionHeader` | 渐变竖条 + 加粗文字的小节标题 |
| `Blob` | 渐变卡与登录页的装饰圆斑 |

动效约定：页面转场是全局的淡入 + 轻微上滑 + 缩放（`app.dart` 的 `_SlideFadeBuilder`，所有 `MaterialPageRoute` 自动生效）；新聊天气泡淡入上浮；名额徽标数字变化走 `AnimatedSwitcher`；底部导航是自绘胶囊 Dock（选中项品牌色药丸底，FAB 出入场带缩放过渡）。全部用 Flutter 内置能力，**零新增依赖**。

两条坑记录：

- 自绘可点控件（PrimaryButton、底部导航、FAB、模式切换）必须显式包 `Semantics(button: true)`，否则浏览器语义树里没有 `role=button`，自动化脚本与无障碍都定位不到。
- `ActivityCard` 的 Hero 默认开；"我的"页两个 Tab 可能同屏出现同 id 活动，会撞 Hero tag 抛异常，那里必须传 `hero: false`。
- **UI 里不要用 emoji 当图标**（2026-10-11 实测）：CanvasKit 渲染 emoji 要从 gstatic 按需下载 Noto Color Emoji，国内网络下拉不到就渲染成方框（同一页面中文正常，因为 CJK 回退走了别的通道）。分类封面、logo 这类自绘元素一律用 `CategoryVisual.icon` / Material Icons——打包自带、还会被 tree-shake，零网络依赖。用户在聊天里手打的 emoji 仍可能显示方框，属于可接受限制。

## 踩过的坑

- **Web 上 `dart:io` 的 `WebSocket` 不存在**，必须用 `web_socket_channel`；浏览器握手也带不了自定义 Header，所以令牌只能放查询串（`/ws?token=`），这是 `docs/03` 定 `/ws?token=` 而不是 Header 的原因。
- **`@Min`/`@Max` 管不了 `double`** 那条在后端，但前端同源：半径滑块取值必须落在 `[0.5, 500]`，越界会被后端 `1001` 打回。
- **`flutter build web` 默认从 gstatic 拉 CanvasKit**，国内网络下会白屏。本项目用 `flutter build web --release --no-web-resources-cdn` 构建，`canvaskit/` 从本地产物加载。
- **字体也必须自带**（2026-10-11 实测）：不声明字体时引擎按需从 gstatic 拉 Roboto / Noto 回退字体，时通时断，失败时整页文字/emoji 变方框甚至启动失败。`assets/fonts/` 里打包了 Roboto（SDK 自带，Apache 2.0）+ NotoSansSC 可变字体（OFL，17MB，jsdelivr 镜像拉的），pubspec 声明 + `ThemeData(fontFamily: 'NotoSansSC')`，运行时零外网请求。粗体走合成加粗（可变字体默认实例注册，不追求真实字重）。
- **`dispose()` 里不能用 `context`**（2026-10-11 实测踩到）。卸载顺序是 `Element.unmount()` 先、`state.dispose()` 后，前者已经把 `_widget` 和 `_inheritedElements` 置空、状态改成 `defunct`。此时 `context.read<T>()` 会走到 provider 的
  `throw ProviderNotFoundException(T, context.widget.runtimeType)`，
  而 defunct Element 的 `Element.widget` 是 `_widget!` —— release 包里没有那句"Looking up a deactivated widget's ancestor is unsafe"的 assert 提示，只留下 `Null check operator used on a null value`，堆栈指向 `main.dart.js` 里的压缩帧（帧名 `Element.widget` 的 getter），极难反查。
  正确写法：需要"离开时通知谁"就在 `initState` 里把引用拿住（`late final ChatState _chat = context.read<ChatState>()`），`dispose()` 只碰这个引用。`chat_room_page` 是唯一犯过这个错的地方。
  顺带规约：`initState` 里的 `addPostFrameCallback` 回调一律先 `if (!mounted) return;`。
