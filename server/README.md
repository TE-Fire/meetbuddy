# meetbuddy-server

Spring Boot 3.2.5 + Java 21 + MyBatis-Plus 3.5.7 + Redis。

## 当前进度：M3 就近匹配

已完成：统一响应信封、全局异常处理、JWT 签发与校验、登录拦截器、账号密码与验证码双通道登录、全部 14 张表的建表脚本；活动发布/编辑/取消/详情/活动流/收藏、报名与取消报名、参与者与到场确认、信用分变动流水，以及报名并发防超员（Redis 分布式锁 + 数据库条件更新两层保障）；用户坐标上报与兴趣标签、搭子需求发布/关闭、基于 Redis GEO 的候选圈选与距离/标签/时间/信用四维加权排序、活动流按半径筛选。

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

`meetbuddy.dev.fixed-code-enabled: true` 时验证码固定为 `123456`，只写日志不下发真实短信。发布前必须关掉这个开关。

## 遗留项（进 M4 之前该处理的）

| 项 | 现状 | 打算怎么处理 |
|---|---|---|
| 固定验证码没有 profile 隔离 | `application.yml` 里写死 `true`，没有 profile 分离，任何方式启动都是固定码 | 发布或对外演示前改 `false`；正式做法是拆出 `application-dev.yml`，但那样所有启动脚本都要加 `--spring.profiles.active=dev`，留到 M4 一并做 |
| M3 的 P95 时延压测没跑 | GEO 功能验收已全过，但 M3 的验收标准里还写着「压测 P95 时延」 | 沿用 M2 那套真并发脚本（`bench.py` 的线程池 + Barrier），换成打 `/buddy/match`，出一组 P95 |
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
