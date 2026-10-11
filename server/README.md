# meetbuddy-server

Spring Boot 3.2.5 + Java 21 + MyBatis-Plus 3.5.7 + Redis。

## 当前进度：M4 即时通信

已完成：统一响应信封与错误码契约链、JWT 双令牌与登录拦截、账号密码与验证码双通道登录、全部 14 张表的建表脚本；活动发布/编辑/取消/活动流/收藏与报名、参与者与到场确认、信用分流水，以及报名并发防超员（Redis 分布式锁 + 条件更新两层保障）；用户坐标与兴趣标签、搭子需求发布/关闭、基于 Redis GEO 的四维加权匹配与半径筛选；M4 的即时通信——单聊与群聊消息落库并实时投递、`ack` 回执、断线重连补发离线消息、心跳保活与静默连接巡检、聊天历史与未读查询、投递到达率统计。

## 启动前置

1. **建库**。数据库名 `meetbuddy`，脚本在 `src/main/resources/db/schema.sql`：

   ```bash
   mysql -u root -p < src/main/resources/db/schema.sql
   ```

2. **配口令**。`application.yml` 里的 MySQL 与 Redis 口令都是**必填占位符、不带默认值**，仓库里不留任何明文：

   ```bash
   cp server/.env.local.example server/.env.local   # 填 MYSQL_PASSWORD 等三项
   ```

   `.env.local` 已被 gitignore。漏配时启动会直接报 `Could not resolve placeholder 'MYSQL_PASSWORD'`。

3. **Redis** 需要在 `127.0.0.1:6380` 可用，**且只能是 3.2 以上**（GEO 命令要求）。**不要用本机 6379 上那个 3.0.504**。用 Docker 起 7.2.3：

   ```bash
   cd server/docker && docker compose up -d
   ```

   详见 `server/docker/README.md`。容器口令来自 `server/docker/.env` 的 `REDIS_PASSWORD`，须与 `server/.env.local` 里的 `MEETBUDDY_REDIS_PASSWORD` 取同一个值。

## 启动

```bash
mvn package -DskipTests
bash server/run-local.sh                      # 默认起在 8099
```

`run-local.sh` 做的就是：`set -a; . ./.env.local; set +a` 注入两个口令，再 `java -jar ... --server.port=8099`。想手动起就照这条链路自己导出 `MYSQL_PASSWORD` 与 `MEETBUDDY_REDIS_PASSWORD`。

**端口注意事项**：本机直接 `java -jar` 启动时，若日志出现 `Port 58061 was already in use`（该端口被宿主进程占用），显式指定端口即可——`run-local.sh` 已内置 `--server.port=8099`，传别的端口用 `bash server/run-local.sh --server.port=9000`。

## M1 验收用例与实测结果

以 `--server.port=8099` 实测：

| 用例 | 请求 | 实测响应 |
|---|---|---|
| 未带令牌访问受保护接口 | `GET /api/user/me` | `code=401`，HTTP 仍为 200 ✅ |
| 发送验证码（依赖 Redis） | `POST /api/auth/sms/send` | `code=0` ✅ |
| 60 秒内重复发码 | 同上 | `code=3002` ✅ |
| 手机号格式非法 | `POST /api/auth/sms/send` 传 `123` | `code=1001` ✅ |
| 注册（依赖 MySQL） | `POST /api/auth/register` | `code=0`，返回双令牌与用户信息 ✅ |
| 重复注册同手机号 | 同上 | `code=1005` ✅ |
| 密码登录 | `POST /api/auth/login/password` | `code=0` ✅ |
| 密码错误 / 手机号未注册 | 同上 | `code=1006` ✅ |
| 带令牌访问受保护接口 | `GET /api/user/me` + Bearer | `code=0`，返回当前用户 ✅ |
| 无效令牌 | 同上，传 `abc.def.ghi` | `code=401` ✅ |
| 验证码登录 | `POST /api/auth/sms/login` | `code=0` ✅ |
| 验证码错误 | 同上，传 `000000` | `code=3001` ✅ |
| 刷新令牌换发新令牌 | `POST /api/auth/token/refresh` | `code=0` ✅ |
| 拿 access token 去刷新 | 同上，传 access token | `code=401` ✅ |

复跑方式：清掉 Redis 的 `sms:*` 键和测试手机号后重跑。注意**验证码一次性消费**——注册用掉之后，同一个码不能再用来登录，必须重新 `sms/send`。

## M2 验收用例与实测结果

功能冒烟（3 个用户，活动上限 5）：

| 用例 | 实测响应 |
|---|---|
| 组织者报名自己的活动 | `1001 组织者无需报名` ✅ |
| 报名成功 | `0`，入群、计数 +1 ✅ |
| 重复报名 | `2002` ✅ |
| 取消报名（距开始 > 2h） | `0`，计数回到 1，状态退回 `OPEN`，扣 1 分 ✅ |
| 取消后重新报名 | `0`（曾因唯一键拦截失败，已修） ✅ |
| 收藏后查详情 | `favorited: true` ✅ |
| 组织者确认到场 / 缺席 | 到场 +3（100 封顶）、缺席 −10，均写 `credit_log` ✅ |
| 非组织者确认到场 | `403` ✅ |

### 并发防超员压测

100 个用户用线程栅栏同时抢 20 个名额（`D:\_download\bench.py`）：

| 组别 | 开关 | 成功报名 | 被拒 | 库内报名行数 | 计数 | 状态 |
|---|---|---|---|---|---|---|
| A 有锁 | `meetbuddy.signup.lock-enabled=true` | **20** | 80 | 20 | 20 | FULL |
| B 无锁 | `=false` | **29** | 71 | 29 | 29 | FULL |

B 组超员 9 人，A 组恰好卡在上限——这就是论文的对照实验。

**压测必须用真并发。** 最初用 30 个 `curl &` 打，两组都是 20，看不出差别：进程启动本身有几十毫秒错峰，请求到达服务端时其实是串行的。改成线程池 + `threading.Barrier` 同步放行后才复现超卖。

**为什么超卖的是 9 人而不是更多**：无锁路径是"先查计数再写"，并发下多个请求读到同一个旧值就都放行了；真正被卡住的时刻取决于 DB 连接池与线程调度，所以每次跑出来的超员数会浮动，但一定会大于上限。

复跑方式：`bash D:/_download/m2_bench.sh true 20 100` 与 `bash D:/_download/m2_bench.sh false 20 100`。

## M3 验收用例与实测结果

脚本 `D:\_download\m3_func.sh`：u1/u2 在北京国贸附近、u3 在天津（约 107km），三个用户依次上报坐标、打标签、发搭子需求。

| 用例 | 实测响应 |
|---|---|
| 上报坐标后写入 GEO 索引 | `geo:user` 成员 `2 3` ✅ |
| 发布搭子需求后写入 GEO 索引 | `geo:buddy` 成员 `5 6` ✅ |
| 北京国贸 10km 内匹配 | 只有 u2，`score=0.9853`、`distance=0.37`、`commonTags=[硬核,剧本杀]`、`reason="距离 0.4km，都喜欢 硬核、剧本杀"` ✅ |
| 半径放到上界 500km | 两条都进来，u2 `score=0.9997` 在前、u3 `score=0.614`（107.45km、无共同标签）在后 ✅ |
| 关闭需求后再匹配 | `data: []` ✅ |
| 活动流 `radius=10` / `radius=0.5` | 都命中「国贸剧本杀」（`total=1`）✅ |
| 从天津坐标搜 10km | `total=0` ✅ |
| 取消活动后从 GEO 摘除 | `geo:activity` 为空 ✅ |
| `radius=0.4` / `radius=501` | `1001 参数校验失败`（上下界之外）✅ |

### 搜索半径的上下界（已定：0.5 ~ 500 km）

M3 初版给 `radius` 加的是 `@Min(1) @Max(100)`，验收脚本按 `0.5 ~ 1500` 写，两边对不上，且这个约束当时没进文档。已按 TE 拍板统一为 **[0.5, 500]**，并写进 `docs/03` 第四节。

两点值得记：

- **`@Min/@Max` 不能拿来管 `double`**。它们声明的是 `long`，对小数只做整数比较，`0.5` 会被当成 `0` 直接拒掉。小数边界必须用 `@DecimalMin/@DecimalMax`，这是改成 0.5 下界时才暴露出来的。
- 验收脚本也跟着改了：原先靠「上海→北京 1060km」演示远处排后，500km 上界下够不着，把 u3 挪到天津（107km），演示效果不变且更贴「同城 + 周边」的语义。

### P95 时延压测（M3 验收的最后一格）

脚本 `D:\_download\bench_match.py`，与 `bench.py` 同源：线程池 + `threading.Barrier` 造真并发。三个前提决定了数字能不能用——先灌 100 条需求当候选池（空索引上测到的是"一次空数组序列化"）；压测线程各自 keep-alive 复用连接（短连接会把 TCP 握手算进"匹配时延"）；先预热 30 次（JVM 前几百次走解释执行）。

| 组 | 接口 | 候选池 | 并发 | 日志 | avg | P50 | P95 | P99 | 吞吐 |
|---|---|---|---|---|---|---|---|---|---|
| A | `/buddy/match` | 100 | 50 | debug | 407.0 | 396.8 | 718.8 | 972.5 | 77 req/s |
| B | `/buddy/match` | 10 | 50 | debug | 294.6 | 287.2 | 508.9 | 605.4 | 90 req/s |
| C | `/buddy/match` | 100 | **1** | debug | 22.9 | 22.5 | **26.7** | 29.7 | — |
| D | `/buddy/match` | 100 | 50 | **info** | 389.4 | 355.7 | 779.9 | 980.2 | 77 req/s |
| E | `/user/me`（对照） | — | 50 | debug | 155.2 | 146.1 | 310.6 | 365.2 | 185 req/s |

单位毫秒。三组能读出三个结论：

- **匹配算法本身不慢。** C 组把并发降到 1，P95 只有 26.7ms——整条链路是 1 次 `GEOSEARCH` + 4 次批量 SQL + 100 条内存算分排序，没有 N+1（`match` 用的是 `selectBatchIds` 批量查）。**论文要引"算法时延"就引这一行**，A 组的 719ms 是排队，不是计算。
- **A 组的 719ms 是单机排队。** E 组拿最简接口（1 次 Redis `hasKey` + 1 次 DB）做对照，50 并发下也只有 185 req/s、P95 311ms——本机单实例的并发吞吐上限就在这个量级，JVM、MySQL、WSL2 里的 Redis 抢同一份 CPU，而 TE 这台机器本身 CPU 就紧。匹配接口的增量（多 1 次 Redis 往返、3 次 SQL、100 条算分）把 avg 从 155 抬到 407，占六成。
- **两个嫌疑被排除。** B 组把候选池从 100 砍到 10，avg 只降 28%——DB 查询量不是主导；D 组把日志从 debug 调到 info，日志文件从 7.1MB 掉到 35KB，时延纹丝不动——同步写日志也不是瓶颈。

复跑：`python bench_match.py`（默认 150 用户 / 100 需求 / 50 并发 / 20 轮）；换接口做对照用 `BENCH_PATH='/user/me' SKIP_SEED=1 python bench_match.py 60 0 50 20`。

> **结论：不优化，保持现在的匹配语义。** 三条候选路径都评估过——GEO 结果先按距离截断 Top-K、用户与标签挂 Redis 缓存、Tomcat 线程数与 Hikari 连接池调参。前两条会改变匹配语义（远处的潜在高分候选被截掉，与 `docs/01` 第七节「先 GEO 圈人、再算分」的约定冲突），为一个并非算法造成的数字牺牲语义不划算；第三条是纯配置，但 E 组已经证明瓶颈是本机单实例的吞吐上限——最简接口也只有 185 req/s，调参换不到量级变化。论文侧该引的是 C 组的算法时延 26.7ms，不是 A 组的 719ms。等真部署到多核机器上再谈。

## M4 验收用例与实测结果

脚本 `D:\_download\m4_func.py`，**21 项全通**。标准库没有 WebSocket 客户端，而给这台机器装包要占磁盘，所以脚本里按 RFC 6455 手写了最小实现——客户端只需做两件服务端不做的事：握手带 `Sec-WebSocket-Key`、发出的每一帧都加掩码。

| 用例 | 实测响应 |
|---|---|
| 发布活动返回 `groupId`，报名后进群且群列表可见 | `groupId=1`，群数 1 ✅ |
| 握手回签 `Sec-WebSocket-Accept` 正确 | ✅ |
| 群消息：发送者收到 `chat` + `ack`，`ack` 带 `msgId` | `msgId=1` ✅ |
| 群消息：另一成员实时收到 | `content=群消息：明晚七点国贸` ✅ |
| `heartbeat` → `pong` | ✅ |
| 单聊且对方离线：仍先落库并回 `ack` | ✅ |
| 离线方未读总数为 1 | `unread=1` ✅ |
| 离线方重连时收到 `offline` 补发 | `type=offline n=1` ✅ |
| 非群成员发群消息被拒 | `3101` ✅ |
| 单聊 / 群聊历史可查 | `total=1` ✅ |
| 取消活动后两个在线成员都收到 SYSTEM 通知 | `msgType=SYSTEM` ×2 ✅ |
| 只读群拒绝发言 | `3104` ✅ |
| `/chat/stats` 计数齐全且互相自洽 | 见下 ✅ |

### 到达率：为什么拆成两个口径

验收跑完那一刻 `/api/chat/stats` 的快照：

```json
{"accepted":3,"deliveredOnline":2,"queuedOffline":1,"replayed":1,"rejected":2,"acks":2,
 "realtimeDeliveryRate":0.6667,"eventualDeliveryRate":1.0,"offlineBacklog":0,
 "onlineConnections":3,"onlineUsers":3}
```

如果只报一个"到达率"，这个值会恒等于 100%（离线也算最终可达），没有信息量。拆成两个才有话说：**实时到达率 0.6667** 指"3 条消息里 2 条对方在线、当帧就送到了"；**最终到达率 1.0** 指"把重连补发算上，一条没丢"。前者掉、后者满，正是离线补发链路在干活的证据。数能对上账：`accepted=3`（群聊 1 + 单聊 1 + 取消通知 1）、`deliveredOnline=2`、`queuedOffline=1`（那条单聊的对方当时离线）、`replayed=1`（u3 重连补发），`offlineBacklog=0` 说明没有积压。

### 设计上的几个选择

- **未读口径分两套。** 单聊用 `message.read_status`（一条消息只有一个接收人）；群聊一条消息多人可见，一位 tinyint 记不下"谁读到哪"，改用 Redis 游标 `chat:read:{userId}:g{groupId}`，游标缺失时（刚入群）退回 `chat_group_member.joined_at` 兜底。这是 docs/02 "已读回执不逐条记录每人读到哪" 的落地方式——游标是每人每群一条，消息表不会因此膨胀。
- **投递放在 Service 层，不在 Handler 里。** "落库 + 投递 + 计数"是同一件事的三个动作，拆两层会让 Handler 变厚，而且以后 HTTP 侧要加发消息接口时没地方复用。Handler 只管协议：认证、拆帧、回执。
- **单聊也推给发送者自己。** 多端登录时手机发的消息网页端也要看到，口径与群聊广播保持一致；到达率只看对方那一侧，自己这份不计入 `deliveredOnline`。
- **心跳的判据是"任何帧"**，不只是显式 `heartbeat`——连着发消息的人没必要再补心跳。巡检每 30 秒一次，静默超 90 秒踢掉。主动踢而不是只靠 TCP 的原因：客户端断网或进程被杀时不会发 close 帧，连接会一直挂在在线表里，消息投过去石沉大海，而发送方以为对方在线。
- **一个用户挂多条连接**（手机 + 浏览器预览），发送前统一用 `ConcurrentWebSocketSessionDecorator` 包一层——群聊广播时多个线程会同时对同一个 session 调 `sendMessage`，不包会抛 `TEXT_PARTIAL_WRITING`。

## 异常处理：契约链

错误码只有一条链路，业务代码里不允许出现裸数字：

```
IErrorCode（契约接口：getCode / getMessage + 快捷抛 ex() / ex(detail)）
   ↑ implements
CommonErrorCode（通用/用户/认证 1xxx + 401/403 + 系统 5000）
ActivityErrorCode（活动 2xxx）
SmsErrorCode（通知 3xxx）
   ↓ 消费方
BizException（只认 IErrorCode）/ BizAssert（isTrue / notNull / notBlank）
   ↓
Result.fail(IErrorCode)  →  GlobalExceptionHandler
```

包结构：契约与枚举住 `common/error/`，`Result` 与 `GlobalExceptionHandler` 留在 `common/`（前者是全站响应信封，后者是 web 层 advice，都不属于错误码本身）。

这套约定是从校园市场后端（`campus-market/backend`）搬过来的，两个项目读起来一致。**唯一刻意的差异是方法名**：那边叫 `getMsg()`，这里叫 `getMessage()`——meetbuddy 的响应信封字段本就叫 `message`，枚举方法与信封字段同名，排查时少一次脑内映射。

具体怎么用：

```java
// 单点抛出，带上下文
throw ActivityErrorCode.CREDIT_LOW.ex("信用分不足，该活动要求 " + need + " 分");

// 条件断言（陈述的是"正常态"）
BizAssert.isTrue(ActivityStatus.canSignUp(a.getStatus()), ActivityErrorCode.ACTIVITY_FULL);

// 取对象顺带判空，返回非 null 的那个，可链式继续用
Activity activity = BizAssert.notNull(activityMapper.selectById(id),
        CommonErrorCode.NOT_FOUND, "活动不存在");
```

日志侧：业务异常走 `warn` 且不打堆栈（重复报名这种"正常失败"打堆栈会把日志淹掉），只有兜底的未知异常才 `error` + 全栈。日志里带的是枚举常量名（`errorCode=ACTIVITY_FULL`），不是光秃秃的 `2001`。

段位登记表在 `docs/03` 第一节。新增错误码只需在所属段位的枚举里加一项，`common` 包零改动。

## 开发期登录

固定验证码由 profile 隔离：`application.yml` 里 `meetbuddy.dev.fixed-code-enabled` 默认 `false`（生产语义），`application-dev.yml` 覆盖为 `true`。

`run-local.sh` 默认激活 `dev`，所以本地起服务验证码恒为 `123456`、不下发真实短信。反过来验证这层隔离是否真的生效，用 prod 语义起一次即可：

```bash
MEETBUDDY_PROFILE=prod bash server/run-local.sh   # 此时 123456 应该登录失败
```

## 跨域（M5 起）

Flutter Web 用浏览器预览，页面与后端不同源，**没有 CORS 映射的话请求会死在预检阶段**——前端报 `Failed to fetch`，后端日志里一条记录都没有，很容易误判成"后端挂了"。

配置在 `WebMvcConfig#addCorsMappings`：允许 `/api/**`，来源走 `meetbuddy.cors.allowed-origin-patterns`（默认 `http://localhost:*,http://127.0.0.1:*`）。用通配端口是因为 `flutter run -d edge` 每次分配的端口都不一样，写死某个端口第二天就失效。

两个配套细节：

- **预检请求必须先放行。** `AuthInterceptor` 里对 `CorsUtils.isPreFlightRequest` 直接返回 true——浏览器发 OPTIONS 时不带 `Authorization`，不放行的话所有带 JSON 体的调用都会死在预检。这段代码 M1 就写好了，但当时没有 CORS 映射，等于一直没被走到。
- **WebSocket 不走这套。** `/ws` 的握手不是普通 MVC 请求，CORS 映射管不到，来源校验在 `WebSocketConfig#setAllowedOriginPatterns` 单独配。

## 遗留项（进 M4 之前该处理的）

| 项 | 现状 | 打算怎么处理 |
|---|---|---|
| WebSocket 放开了 Origin 校验 | HTTP 侧已收口（见下节「跨域」），但 `WebSocketConfig` 仍是 `setAllowedOriginPatterns("*")` | 上线前把两边都改成前端域名白名单 |
| `/api/chat/stats` 只有登录门槛 | 单机演示的简化，任何登录用户都能读投递计数 | M6 做管理端时挪到 `/admin/**` 或加权限码 |
| `Result` 没有 traceId | 校园市场的 `Result` 带 `traceId`（MDC 取），这边没有，排查时只能靠时间戳对 | 要加得配一个写入 MDC 的 Filter，属于独立一件事，不往这次改动里塞 |

## 踩过的坑

- **JDBC URL 的 `characterEncoding` 只能填 Java 字符集名 `UTF-8`**，填 `utf8mb4` 会抛 `Unsupported character encoding`。已在配置里注释标记。
- **Git Bash 里调 `mvn` 会报 `ClassNotFoundException: plexus.classworlds.launcher.Launcher`**，这是 MSYS 路径转换的问题，不是 Maven 坏了。一律用 PowerShell 调 `mvn.cmd`。
- **本机 `java -jar` 时端口会被宿主环境顶到 58061**，显式 `--server.port=8099` 规避。
- **验证码限流键 `sms:limit:{phone}` 不会自动过期清理**（按 TTL 走，但重跑测试时可能残留），导致后续发码全返回 `3002`。重跑验收前先 `redis-cli --scan --pattern "sms:*"` 清一遍。
- **`curl` 是 Windows 原生版**（`C:\WINDOWS\system32\curl`），`-o` 只认 `D:/` 形式的路径，给 `/d/` 会静默失败——文件不生成、请求也不发。
- **脚本里裸写 `wait` 会把后台的 java 服务进程一起等进去**，永远不返回。必须收集 curl 的 PID 再 `wait $PIDS`。
- **同名 Bean 会直接让应用起不来**：分页插件已经在 `MeetbuddyApplication` 里注册过一次，再写一个 `MybatisPlusConfig` 会抛 `BeanDefinitionOverrideException`。
- **`mvn compile` 不会更新 jar**，跑 `java -jar` 前必须 `mvn package`，否则打的是上一版的包（表现为新接口 404）。
- **本机 Redis 是 3.0.504（微软 2016 的 Windows 移植版），没有 GEO 命令**。`GEOADD` 直接报 `unknown command`，所有依赖就近匹配的接口全返 `5000`。GEO 要 Redis ≥ 3.2。已改用 Docker 里的 `redis:7.2.3`（宿主端口 6380），见 `server/docker/README.md`。
- **本机 3.0 的 `redis-cli` 不认 `--no-auth-warning`**（Redis 4.0 才加的参数），且它默认连 6379。脚本里改用 `docker exec mb-redis redis-cli`，直接用容器内的 7.2.3 客户端，版本和端口都不会错。
- **GEO 命令底下就是 sorted set**，所以 `ZRANGE geo:user 0 -1` 能列出索引里的成员——验索引有没有写进去，用这个比 `GEOPOS` 方便。
