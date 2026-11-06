#!/usr/bin/env bash
# 用 DevEco Studio 自带工具链构建 HarmonyOS 工程（无需另行安装 JDK / Node）
set -euo pipefail

DEVECO_APP="${DEVECO_APP:-/Applications/DevEco-Studio.app}"
SDK_HOME="${DEVECO_SDK_HOME:-$DEVECO_APP/Contents/sdk}"
JBR_HOME="$DEVECO_APP/Contents/jbr/Contents/Home"
NODE_BIN="$DEVECO_APP/Contents/tools/node/bin"
HVIGOR="$DEVECO_APP/Contents/tools/hvigor/bin/hvigorw"

if [[ ! -x "$HVIGOR" ]]; then
  echo "找不到 hvigor: $HVIGOR" >&2
  exit 1
fi

export DEVECO_SDK_HOME="$SDK_HOME"
export JAVA_HOME="$JBR_HOME"
export PATH="$NODE_BIN:$JBR_HOME/bin:$PATH"

cd "$(dirname "$0")"
exec "$HVIGOR" assembleHap --mode module -p product=default -p buildMode="${BUILD_MODE:-debug}" "$@"
