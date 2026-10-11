#!/usr/bin/env bash
# 本地启动后端：把 .env.local 里的口令注入环境变量后拉起 jar。
#
# 用法：
#   bash server/run-local.sh              # 起在 8099
#   bash server/run-local.sh --server.port=9000
#
# 之所以要这个脚本：application.yml 里的 MYSQL_PASSWORD / MEETBUDDY_REDIS_PASSWORD
# 都是必填占位符（不带默认值），仓库里不留任何口令。单独 java -jar 而不先导出
# 这两个变量会直接报 "Could not resolve placeholder"。
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

# 本机直接 java -jar 时端口会被宿主环境顶掉（曾经落到 58061），显式指定更稳
exec java -jar "$JAR" --server.port="${MEETBUDDY_SERVER_PORT:-8099}" "$@"
