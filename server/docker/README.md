# 本地中间件操作手册（meetbuddy）

面向本机 Docker Desktop + Windows。所有命令都在本目录（`server/docker/`）下执行，Compose 会读取同目录的 `.env`。

## 一、为什么非要用 Docker 里的 Redis

本机原本跑着 `Redis` Windows 服务（3.0.504，微软 2016 年的移植版），端口 6379。但 M3 的近就匹配依赖 **GEO 系列命令**（`GEOADD` / `GEOSEARCH` / `GEORADIUS`），这批命令是 **Redis 3.2** 才引入的，3.0 上直接报 `unknown command`。

所以：**不升级本机那个 3.0 服务，改用 Docker 起一个 7.2.3，宿主端口 6380**。两个 Redis 各跑各的，互不影响。

## 二、前置检查（只需做一次）

0. **先建 `.env`**。`.env` 已被 gitignore（本机端口、数据目录、各人的路径不同），仓库里只有模板：
   ```bash
   cp .env.example .env
   ```
   compose 里的 `${DATA_ROOT}` / `${REDIS_PORT}` 都取自它，缺了会报"变量未设置"、挂载路径错乱。口令不需要配——本机开发两侧都不设密码。
1. **Docker Desktop 允许挂载 D 盘**：Settings → Resources → File sharing，勾选 `D:\`。改完要 Apply & Restart。
2. **端口没被占**：本机 6379 已被 Redis 3.0 占着，所以宿主端口用 **6380**。
3. **本机剩下的服务不动**：6379 上原有的 Redis 3.0 照常运行。

## 三、数据落在 D 盘的哪里

根目录由 `.env` 里的 `DATA_ROOT` 决定。模板里默认是相对路径 `./data`，**本机这份改成了 `D:/docker/meetbuddy`**，与既有 `D:\docker\<中间件>` 的习惯一致。

| 服务  | 宿主机路径（D 盘）                | 容器内路径 | 存的是什么     |
| ----- | --------------------------------- | ---------- | -------------- |
| redis | `D:\docker\meetbuddy\redis\data`  | `/data`    | AOF 持久化文件 |

**注意：** 用的是 bind mount，**不是命名卷**。所以 `docker compose down -v` 删不掉数据，只会删容器；要彻底重来必须手动删上表里的目录。反过来也有好处：备份就是复制文件夹。

> 开发期的 Redis 里只有验证码、分布式锁、GEO 索引这几类易失数据，`FLUSHALL` 一下就能重来，一般不需要动数据目录。

## 四、镜像清单

| 服务  | image         | 本机已有 | 需要拉取 |
| ----- | ------------- | -------- | -------- |
| redis | `redis:7.2.3` | ✅       | —        |

本机已有该镜像，`up` 时不会联网。刻意不用 `7-alpine`——alpine 版要重新拉，且 musl 下 `redis-cli` 行为略有差异。

## 五、启动

```bash
docker compose up -d
docker compose ps                  # STATUS 出现 (healthy) 才算就绪
```

Redis 秒起，不需要像 MySQL 那样等初始化。

**应用侧的连接地址**（`server/src/main/resources/application.yml` 已改好）：宿主 `127.0.0.1:6380`，**无口令**——容器不设 `requirepass`，应用侧也不配 `password`，两端同口径。

下面的验证命令都不带 `-a`，也不需要先把 `.env` 载入 shell。

## 六、如何验证运行状态

```bash
# 基本连通（返回 PONG）
docker compose exec redis redis-cli ping

# 关键：确认 GEO 命令可用（本机 3.0 挂掉的就是这个）
docker compose exec redis redis-cli GEOADD geo:smoke 116.4610 39.9088 probe
docker compose exec redis redis-cli GEOPOS geo:smoke probe
docker compose exec redis redis-cli del geo:smoke

# 版本
docker compose exec redis redis-cli info server | grep redis_version

# 内存占用
docker stats --no-stream
```

`GEOADD` 返回 `1`、`GEOPOS` 返回坐标数组即说明版本对得上。

> 补充：GEO 命令底层就是 sorted set，所以 `ZRANGE geo:user 0 -1` 也能列成员——M3 验收脚本正是这么检查索引写入的。

## 七、应用怎么连上来

`application.yml` 里读环境变量，端口带默认值：

```yaml
spring:
  data:
    redis:
      host: 127.0.0.1
      port: ${MEETBUDDY_REDIS_PORT:6380}
      # 无 password 键
```

**"无密码"必须把整个 `password` 键删掉，不能留空值或空串。** Lettuce 拿到空串仍会发一次 `AUTH ""`，服务端按"客户端发了认证但自己没配密码"拒绝，报错和密码写错一模一样（`RedisConnectionFailureException: Unable to connect to Redis`）——这条是踩过的，记录在此。

变量名刻意带 `MEETBUDDY_` 前缀：沙箱曾自动往 java 进程注入 `SERVER_PORT`，端口类变量名被外部覆盖会静默连错实例（连回 6379 那个 3.0，GEO 又报错），加前缀防一手。

想临时连别处，`docker compose up` 之前先 `export MEETBUDDY_REDIS_PORT=6379` 即可，不用改文件。

## 八、常见操作

```bash
docker compose stop          # 停服，数据都在
docker compose start         # 再拉起来，秒起
docker compose down          # 删容器，D 盘数据保留
docker compose logs -f redis # 看日志

# 清库重来（开发期最常用）
docker compose exec redis redis-cli FLUSHALL

# 只想清业务键，不动别的
docker compose exec redis redis-cli --scan --pattern "sms:*" | \
  xargs -r docker compose exec -T redis redis-cli del
```

## 九、已知事项

- **Docker Desktop 不是开机自启时**，重启电脑后要先手动打开 Docker Desktop，再 `docker compose up -d`。忘了这一步的症状是应用启动即报连接不上 `127.0.0.1:6380`。
- **不要给容器加 restart 策略**：本机内存紧张，Redis 跟 Docker Desktop 一起常驻即可，用 `docker compose start` 按需拉起更可控。
- **本机的 Redis 3.0 服务（6379）建议保持开启但不用**：其他老项目可能在用；meetbuddy 只认 6380。
