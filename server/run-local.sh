#!/usr/bin/env bash
# 本地启动后端：把 .env.local 里的口令注入环境变量后拉起 jar。
#
# 用法：
#   bash server/run-local.sh              # 起在 8099
#   bash server/run-local.sh --server.port=9000
#
# 之所以要这个脚本：application.yml 里的 MYSQL_PASSWORD 不带默认值，仓库里不留任何口令，
# 只能由环境变量注入（Redis 本地无密码，不再需要变量）。
# 注意漏配时**不会**报“占位符无法解析”——未解析的占位符会被原样当口令发出去，
# 报的是 MySQL 的 Access denied ... (using password: YES)，容易误判。
set -euo pipefail

cd "$(dirname "$0")"

JAR="target/meetbuddy-server-0.0.1-SNAPSHOT.jar"
if [ ! -f "$JAR" ]; then
  echo "找不到 $JAR，先执行：mvn package -DskipTests" >&2
  exit 1
fi

if [ -f .env.local ]; then
  set -a
  . ./.env.local
  set +a
else
  echo "缺少 server/.env.local，请先 cp .env.local.example .env.local 并填写口令" >&2
  exit 1
fi

# 本机直接 java -jar 时端口会被宿主环境顶掉（曾经落到 58061），显式指定更稳。
# profile 默认 dev：固定验证码这类开发期开关都放在 application-dev.yml，
# 不带 profile 启动就是生产语义（真发短信、真随机码）。
exec java -jar "$JAR" \
  --server.port="${MEETBUDDY_SERVER_PORT:-8099}" \
  --spring.profiles.active="${MEETBUDDY_PROFILE:-dev}" \
  "$@"
