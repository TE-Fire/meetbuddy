# meetbuddy · 同城活动组局与搭子匹配平台

面向同城用户的「活动组局 + 兴趣搭子匹配」应用。用户发布剧本杀、运动、探店、拼车等活动，他人报名；也可直接发布"找搭子"需求，系统按地理位置、兴趣标签、时间与信用分推荐匹配对象，并提供即时群聊。

本项目为毕业设计，论文侧重点在三个可量化的实验：LBS 就近加权匹配的准确率与时延、热门活动报名并发防超员、WebSocket 消息可靠投递。

## 技术栈

| 层 | 选型 |
|---|---|
| 移动端 | Flutter 3.47.7（Dart 3.13.5） |
| 后端 | Spring Boot 3 + Java 21 |
| 数据库 | MySQL 8 |
| 缓存 | Redis 7（GEO 索引、分布式锁、验证码、令牌黑名单） |
| 实时通信 | WebSocket |
| 管理端 | Vue3 + Element Plus + ECharts |

## 目录结构

```
meetbuddy/
├─ docs/         文档：技术决策、数据库设计、接口契约 —— 唯一依据
├─ server/       Spring Boot 后端（含 docker/ 本地中间件）
├─ mobile/       Flutter 用户端（M5）
├─ miniprogram/  微信小程序用户端（与 mobile/ 共用同一套后端接口）
└─ admin/        Vue3 管理端（M6）
```

`server/` 和各端独立工程。`mobile/` 已在 M5 落地（Flutter 用户端，含 mock / 真实双数据源）；`miniprogram/` 已落地（覆盖登录→发现→详情/报名→发布→群聊→我的主链路，见 `miniprogram/README.md`）；`admin/` 目前只有 README（写明技术栈与启动方式），代码在 M6 落地。

## 文档索引

开发前请先看 `docs/`，代码以文档为准，文档没写的流程先补文档再写代码。

1. [`docs/01-技术决策与业务规则.md`](docs/01-技术决策与业务规则.md) — 仓库结构、登录方式、信用分规则、活动状态机、建群时机
2. [`docs/02-数据库设计.md`](docs/02-数据库设计.md) — 全量表结构与索引、Redis 键规划
3. [`docs/03-接口契约.md`](docs/03-接口契约.md) — 前后端接口约定、错误码、WebSocket 帧格式
4. [`docs/04-管理端设计.md`](docs/04-管理端设计.md) — M6 管理端：三个前置缺口的处置、接口清单、看板口径、验收标准
5. [`docs/05-通知与提醒.md`](docs/05-通知与提醒.md) — 站内通知 + 活动开始前提醒的规则（互评已砍）
6. [`docs/06-成就勋章与个人主页.md`](docs/06-成就勋章与个人主页.md) — 徽章清单与触发架构、他人主页口径
7. [`docs/07-分享海报.md`](docs/07-分享海报.md) — 活动分享海报的版式、绘制约束与小程序码降级/升级路径
8. [`docs/08-用户头像.md`](docs/08-用户头像.md) — 上传图片方案、存储校验、7 处展示口径、iOS http 图绕行
9. [`docs/09-兴趣标签引导.md`](docs/09-兴趣标签引导.md) — 兴趣标签编辑/建议池/他人主页展示；聊天发图片已砍
10. [`docs/10-活动列表排序.md`](docs/10-活动列表排序.md) — 活动流 `sortBy`（最新/最热/最近）、降级规则、与筛选叠加
11. [`docs/11-我的日程.md`](docs/11-我的日程.md) — 「我发起+我报名」按日期分组时间轴、筛选与过去态判定
12. [`docs/12-活动编辑改期.md`](docs/12-活动编辑改期.md) — 组织者自助改时间地点、可编辑状态、人数下限保护
13. [`docs/13-关注关系.md`](docs/13-关注关系.md) — 关注/取关、关注与粉丝列表、通知与幂等口径
14. [`docs/14-Flutter端功能对齐.md`](docs/14-Flutter端功能对齐.md) — 把小程序功能补到 Flutter 端（4 批 + 手感返工），含 Android SDK 装机前置与环境坑

## 本地环境（已配置）

Flutter SDK 装在 `D:\Flutter`，已加入用户级 `PATH`，并配置国内镜像：

```
PUB_HOSTED_URL=https://pub.flutter-io.cn
FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

验证安装：

```bash
flutter --version
flutter doctor
```

`flutter doctor` 现在四项全绿中 Android 段已是 `[√] Android toolchain (Android SDK version 36.0.0)`——Android SDK 已装在 `D:\Android\Sdk` 并经 `flutter config --android-sdk` 接入，为真机装机准备。桌面开发阶段仍统一用浏览器预览：

```bash
flutter run -d edge
```

若 `-d edge` / `-d chrome` 起不来（本机安全策略把 `reg.exe` 列入黑名单，Flutter 探测浏览器版本时要读注册表），改用静态产物 + 任意静态服务器：

```bash
flutter build web --release --no-web-resources-cdn
cd build/web && python -m http.server 5180 --bind 127.0.0.1
```

真机装机的前置与两个必踩的坑（明文 HTTP 放行、`API_BASE` 指向局域网 IP）见 `docs/14`。

后端需要 JDK 21（已装，Temurin 21.0.8）与 Maven 3.9.11。

Redis 走 Docker（本机 6379 上那个 3.0.504 不支持 GEO），启动方式见 `server/docker/README.md`：

```bash
cd server/docker && docker compose up -d   # mb-redis，宿主端口 6380
```

## 里程碑与验收

每个里程碑都有硬验收标准，上一个没验收不动下一个。

| | 里程碑 | 验收标准 |
|---|---|---|
| ~~M0~~ ✅ | 仓库结构与文档 | `.gitignore` 覆盖三端；本 README 能指导启动 |
| ~~M1~~ ✅ | 后端骨架 | 14 张表落地；注册/密码/验证码三通道登录拿 token；未带 token 访问受保护接口返回 401。实测 13 条用例全通，见 `server/README.md` |
| ~~M2~~ ✅ | 活动与报名 | 发活动→报名→满员截止；100 并发抢 20 个名额实测恰好 20 人，无锁对照组超员 9 人。详见 `server/README.md` |
| ~~M3~~ ✅ | LBS 匹配 | Redis GEO 就近筛选 ✅；加权评分返回 Top N ✅；P95 时延压测 ✅（无竞争 P95 26.7ms，50 并发 719ms，五组对照见 `server/README.md`） |
| ~~M4~~ ✅ | 即时通信 | 单聊+群聊 ✅；断线重连补发离线消息 ✅；到达率可统计 ✅（实时 0.667 / 最终 1.0）。21 项验收见 `server/README.md` |
| ~~M5~~ ✅ | Flutter 前端 | 浏览器中完整走通「发布→报名→进群聊」✅（双账号三段式 14/14，控制台无 error，实测见 `mobile/README.md`） |
| ~~M6~~ ✅ | 管理端 | 下架/恢复、举报处理、封禁/解封、信用分调整、看板聚合 ✅（规则见 `docs/04`，管理端 `admin/` 已落地） |
| ~~通知与提醒~~ ✅ | 站内通知 + 定时提醒 | 五类事件通知 + 开始前提醒 + 管理侧下架/举报回执 ✅（规则见 `docs/05`） |
| ~~成就勋章~~ ✅ | 勋章 + 个人主页 | 8 枚徽章（即时 3 + 扫描 5）+ 结活动 Job + 他人主页 ✅（规则见 `docs/06`） |
| ~~分享海报~~ ✅ | 活动分享海报 | 详情页生成海报存相册（封面/标题/时间地点名额/组织者/品牌区）✅（规则见 `docs/07`） |
| ~~用户头像~~ ✅ | 上传图片头像 | 个人页选图上传 + 全局归一化回退首字母，7 处展示点接真图 ✅（规则见 `docs/08`） |
| ~~兴趣标签引导~~ ✅ | 兴趣标签 | 编辑面板建议池 + 自定义、无标签引导卡、他人主页展示；匹配标签重合权重 0.3 落地 ✅（规则见 `docs/09`） |
| ~~活动列表排序~~ ✅ | 活动流排序 | `sortBy`=latest/hot/distance，可与分类/状态/关键字/就近叠加；distance 依赖经纬度、非 geo 降级 latest ✅（规则见 `docs/10`） |
| ~~我的日程~~ ✅ | 时间轴视图 | 合并「我发起+我报名」按日期分组时间轴，今天/明天/周X/M月D日；顶部筛选全部/我发起/我报名；后端零改动复用 mine 双接口 ✅（规则见 `docs/11`） |
| ~~活动编辑/改期~~ ✅ | 组织者自助改时间地点 | 详情页「编辑」入口 → 编辑页回填详情 → `PUT /api/activity/{id}`；仅 OPEN/FULL 可改，人数下限抬到已报名数，GEO 同步刷新 ✅（规则见 `docs/12`） |
| ~~关注关系~~ ✅ | 关注感兴趣的人 | 主页关注/取关 + 关注/粉丝列表 + 计数；关注给对方落 `USER_FOLLOWED` 通知并跳主页；幂等、禁自关注 ✅（规则见 `docs/13`） |
| ~~Flutter 端对齐（第 1 批）~~ ✅ | 移动端补齐小程序功能 | 「我的」页兴趣标签/关注粉丝计数/资料编辑、活动流排序、详情页组织者与报名人接真图；纯 Flutter 侧、后端零改动 ✅（规则见 `docs/14`） |
| ~~Flutter 端对齐（第 2 批）~~ ✅ | 他人主页 / 关注粉丝列表 / 通知中心 | 三页 + 支撑层（关注关系、通知仓储、`notify` 帧接入）；底部消息 tab 红点 = 聊天未读 + 通知未读 ✅（规则见 `docs/14`） |
| ~~Flutter 交互手感返工（第 2.5 批）~~ ✅ | 按压反馈 / 骨架 / 入场动效 | `PressableScale` 重写 + `BouncyTap`、骨架改扫光、`StaggeredIn` 收紧；口径定稿到 `docs/01` 第九节 ✅ |
| ~~Flutter 交互返工（续）~~ ✅ | 按钮反馈 / tab 动画 / 封面日期标签 | 主次按钮共用 `_BouncyButtonBody`、底部导航与 TabBar 滑块、验证码三态、封面日期徽标补画 ✅（规则见 `docs/14`） |
| ~~Flutter 表单与按钮质感~~ ✅ | 输入框四态 / 按钮渐变受光 | 新增 `AppField` 替换 11 处输入、`_ButtonFace` 渐变 + 顶部受光线、光标选区统一品牌蓝；口径定稿到 `docs/01` 第十节 ✅ |
| ~~Flutter 端对齐（第 3 批）~~ ✅ | 活动编辑 / 勋章墙 / 我的日程 / 信用明细 | 四页 + 编辑页全量回传与自绘区间时间面板；日程复用 organized/joined 不新增仓储；配图只删不加（无选图插件）✅（规则见 `docs/14`） |
| ~~Flutter 端对齐（第 4 批）~~ ✅ | 分享海报 / 找搭子 | `poster` 用 `CustomPainter` 复刻版式 + `RepaintBoundary` 导出（web 触发下载、非 web 弹预览）；`buddy` 双页签 + 匹配/我的需求，组合根 real/mock 双注册；详情页底部操作条最左加「分享」入口 ✅（规则见 `docs/14`） |
| M7 | 实验与论文 | 三组实验出数据，落到论文章节 |

## 常用命令

```bash
# 后端（口令走 server/.env.local，由脚本注入；默认激活 dev profile）
mvn -f server/pom.xml package -DskipTests
bash server/run-local.sh                      # 默认 8099

# 本地 Redis（GEO 需要 3.2+，本机 3.0 不行）
cd server/docker && docker compose up -d      # mb-redis，宿主端口 6380

# 移动端（浏览器预览）
cd mobile && flutter run -d edge

# 管理端
cd admin && npm install && npm run dev
```
