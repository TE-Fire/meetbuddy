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
├─ docs/      文档：技术决策、数据库设计、接口契约 —— 唯一依据
├─ server/    Spring Boot 后端（含 docker/ 本地中间件）
├─ mobile/    Flutter 用户端（M5）
└─ admin/     Vue3 管理端（M6）
```

`server/` 和 `mobile/`、`admin/` 各自独立，前端不放进后端工程里。`mobile/` 已在 M5 落地（Flutter 用户端，含 mock / 真实双数据源）；`admin/` 目前只有 README（写明技术栈与启动方式），代码在 M6 落地。

## 文档索引

开发前请先看 `docs/`，代码以文档为准，文档没写的流程先补文档再写代码。

1. [`docs/01-技术决策与业务规则.md`](docs/01-技术决策与业务规则.md) — 仓库结构、登录方式、信用分规则、活动状态机、建群时机
2. [`docs/02-数据库设计.md`](docs/02-数据库设计.md) — 全量表结构与索引、Redis 键规划
3. [`docs/03-接口契约.md`](docs/03-接口契约.md) — 前后端接口约定、错误码、WebSocket 帧格式

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

`flutter doctor` 中 Android toolchain 报红叉属预期——本项目不装 Android Studio 和安卓模拟器，桌面开发阶段统一用浏览器预览：

```bash
flutter run -d edge
```

需要地图、相机、推送等原生能力时，最后阶段再装最小 Android SDK（cmdline-tools + 单个 platform + build-tools）并用真机 USB 调试。

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
| M6 | 管理端 | 审核、封禁、看板可用 |
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
