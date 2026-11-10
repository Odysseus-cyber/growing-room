#!/bin/bash
# Keep environment management independent of the runtime it installs/removes.
set -euo pipefail
PROJECT_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
NODE_VERSION=24.22.2
NODE_ARCHIVE="node-v${NODE_VERSION}-darwin-arm64.tar.gz"
RUNTIME="$PROJECT_ROOT/.dev/runtime"
CACHE="$PROJECT_ROOT/.dev/cache"
SERVER_LOCK="$PROJECT_ROOT/.dev/run/server.lock"

die() { printf '错误：%s\n' "$*" >&2; exit 1; }

assert_local_path() {
  local relative="$1" current="$PROJECT_ROOT" part
  local parts=()
  IFS=/ read -r -a parts <<< "$relative"
  for part in "${parts[@]}"; do
    current="$current/$part"
    [ ! -L "$current" ] || die "项目管理目录不能是符号链接：$current"
  done
}

assert_layout() {
  local relative
  for relative in .dev/runtime .dev/cache/downloads .dev/cache/npm .dev/cache/vite .dev/cache/tmp .dev/cache/xdg .dev/run/server.lock node_modules dist; do
    assert_local_path "$relative"
  done
}

ensure_stopped() {
  local file pid
  if [ -d "$SERVER_LOCK" ]; then
    # A concurrently starting process may not have written its PID yet.
    [ -f "$SERVER_LOCK/owner.pid" ] || die "存在未完成的启动锁：$SERVER_LOCK；确认没有开发服务后再移除此锁。"
    for file in "$SERVER_LOCK/owner.pid" "$SERVER_LOCK/child.pid"; do
      [ -f "$file" ] || continue
      read -r pid < "$file" || die "无法读取服务记录：$file"
      [[ "$pid" =~ ^[0-9]+$ ]] || die "无效的服务记录：$file"
      if kill -0 "$pid" 2>/dev/null; then
        die "开发服务仍在运行（PID ${pid}）。请先在启动终端按 Ctrl-C，再执行此操作。"
      fi
    done
    rm -rf -- "$SERVER_LOCK"
  fi
}

configure_environment() {
  mkdir -p "$CACHE/npm" "$CACHE/vite" "$CACHE/tmp" "$CACHE/xdg"
  # Separate files avoid npm's double-loading check. Never write ~/.npmrc.
  for config in "$CACHE/npm-user.npmrc" "$CACHE/npm-global.npmrc"; do
    [ ! -L "$config" ] || die "npm 隔离配置不能是符号链接：$config"
    [ -f "$config" ] || : > "$config"
  done
  export PATH="$RUNTIME/bin:$PATH"
  export npm_config_cache="$CACHE/npm"
  export npm_config_userconfig="$CACHE/npm-user.npmrc"
  export npm_config_globalconfig="$CACHE/npm-global.npmrc"
  export npm_config_prefix="$PROJECT_ROOT"
  export npm_config_logs_dir="$CACHE/npm/_logs"
  export npm_config_global=false
  # npm accepts both cases; neutralize inherited upper-case overrides too.
  export NPM_CONFIG_CACHE="$npm_config_cache"
  export NPM_CONFIG_USERCONFIG="$npm_config_userconfig"
  export NPM_CONFIG_GLOBALCONFIG="$npm_config_globalconfig"
  export NPM_CONFIG_PREFIX="$npm_config_prefix"
  export NPM_CONFIG_LOGS_DIR="$npm_config_logs_dir"
  export NPM_CONFIG_GLOBAL=false
  export npm_config_update_notifier=false
  export XDG_CACHE_HOME="$CACHE/xdg"
  export TMPDIR="$CACHE/tmp/"
}

require_runtime() {
  [ -x "$RUNTIME/bin/node" ] || die "缺少项目 Node，请运行 ./dev setup。"
  [ "$("$RUNTIME/bin/node" --version)" = "v$NODE_VERSION" ] || die "项目 Node 版本不匹配，请清理 runtime 后重新 setup。"
  [ -f "$RUNTIME/lib/node_modules/npm/bin/npm-cli.js" ] || die "项目 npm 不完整，请清理 runtime 后重新 setup。"
}

require_dependencies() {
  [ -f "$PROJECT_ROOT/node_modules/vite/bin/vite.js" ] &&
  [ -f "$PROJECT_ROOT/node_modules/typescript/bin/tsc" ] &&
  [ -f "$PROJECT_ROOT/node_modules/phaser/package.json" ] || die "缺少项目依赖，请运行 ./dev setup。"
}

project_npm() {
  "$RUNTIME/bin/node" "$RUNTIME/lib/node_modules/npm/bin/npm-cli.js" \
    --cache="$CACHE/npm" --logs-dir="$CACHE/npm/_logs" \
    --userconfig="$CACHE/npm-user.npmrc" --globalconfig="$CACHE/npm-global.npmrc" \
    --prefix="$PROJECT_ROOT" --global=false "$@"
}

install_runtime() (
  [ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ] || die "当前工具链面向 macOS Apple Silicon。"
  if [ -x "$RUNTIME/bin/node" ]; then
    require_runtime
    return
  fi
  [ ! -e "$RUNTIME" ] || die "runtime 不完整，请先执行 ./dev clean runtime。"
  mkdir -p "$CACHE/downloads"
  local archive="$CACHE/downloads/$NODE_ARCHIVE"
  local checksums="$CACHE/downloads/SHASUMS256.txt" staging=""
  trap '[ -z "$staging" ] || rm -rf -- "$staging"' EXIT
  if [ ! -f "$checksums" ]; then
    curl --fail --location --retry 2 --connect-timeout 15 --max-time 120 \
      "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt" -o "$checksums.part"
    mv -- "$checksums.part" "$checksums"
  fi
  if [ ! -f "$archive" ]; then
    curl --fail --location --retry 2 --continue-at - --connect-timeout 15 --max-time 900 \
      "https://nodejs.org/dist/v$NODE_VERSION/$NODE_ARCHIVE" -o "$archive.part"
    mv -- "$archive.part" "$archive"
  fi
  local expected actual
  expected="$(awk -v name="$NODE_ARCHIVE" '$2 == name { print $1 }' "$checksums")"
  [[ "$expected" =~ ^[a-f0-9]{64}$ ]] || die "官方校验信息缺少目标包；请清理缓存后重试。"
  actual="$(shasum -a 256 "$archive" | awk '{ print $1 }')"
  [ "$expected" = "$actual" ] || die "Node 安装包校验失败；请清理缓存后重试。"
  staging="$(mktemp -d "$CACHE/tmp/node-install.XXXXXX")"
  tar -xzf "$archive" -C "$staging" --strip-components=1
  [ "$("$staging/bin/node" --version)" = "v$NODE_VERSION" ] || die "下载的 Node 版本不匹配。"
  mv -- "$staging" "$RUNTIME"
  staging=""
)

start_server() {
  ensure_stopped
  mkdir -p "$PROJECT_ROOT/.dev/run"
  mkdir "$SERVER_LOCK" || die "另一个启动操作正在进行。"
  # $$ is the supervising shell, including under macOS Bash 3.2.
  printf '%s\n' "$$" > "$SERVER_LOCK/owner.pid"
  local child_pid=""
  cleanup_server() {
    if [ -n "$child_pid" ]; then
      kill -TERM "$child_pid" 2>/dev/null || true
      wait "$child_pid" 2>/dev/null || true
    fi
    rm -rf -- "$SERVER_LOCK"
  }
  trap cleanup_server EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  "$RUNTIME/bin/node" "$PROJECT_ROOT/node_modules/vite/bin/vite.js" &
  child_pid=$!
  printf '%s\n' "$child_pid" > "$SERVER_LOCK/child.pid"
  printf '开发地址：http://127.0.0.1:5173（Ctrl-C 停止）\n'
  local status=0
  wait "$child_pid" || status=$?
  child_pid=""
  exit "$status"
}

clean_module() {
  local module="${1:-}" paths=() relative
  case "$module" in
    cache) paths=(.dev/cache) ;;
    deps) paths=(node_modules) ;;
    build) paths=(dist) ;;
    runtime) paths=(.dev/runtime) ;;
    all) paths=(.dev/cache node_modules dist .dev/runtime) ;;
    *) die "用法：./dev clean cache|deps|build|runtime|all" ;;
  esac
  ensure_stopped
  for relative in "${paths[@]}"; do
    assert_local_path "$relative"
    rm -rf -- "$PROJECT_ROOT/$relative"
    printf '已清理 %s\n' "$relative"
  done
}

usage() {
  cat <<'EOF'
用法：./dev <命令>
  setup                       安装/恢复独立 Node、npm 和锁定依赖
  start                       启动 H5：http://127.0.0.1:5173
  check                       检查工具链、依赖及 TypeScript
  build                       类型检查并生成 dist 发布包
  clean cache|deps|build|runtime|all
                              清理可重建内容，保留源码、资产与配置
EOF
}

cd "$PROJECT_ROOT"
command="${1:-help}"
case "$command" in
  help|-h|--help) usage; exit 0 ;;
  setup|start|check|build|clean) ;;
  *) usage; die "未知命令：$command" ;;
esac
if [ "$command" = clean ]; then
  [ "$#" -eq 2 ] || die "用法：./dev clean cache|deps|build|runtime|all"
else
  [ "$#" -eq 1 ] || die "命令不接受额外参数：$command"
fi
assert_layout
if [ "$command" = clean ]; then clean_module "$2"; exit 0; fi
if [ "$command" = setup ]; then ensure_stopped; fi
configure_environment
if [ "$command" = setup ]; then
  install_runtime
  require_runtime
  [ -f package-lock.json ] || die "缺少 package-lock.json，请恢复项目锁文件后再安装。"
  project_npm ci --include=dev
  printf '项目工具链已就绪：Node %s / npm %s\n' "$(node --version)" "$(project_npm --version)"
  exit 0
fi
require_runtime
require_dependencies
case "$command" in
  start) start_server ;;
  check)
    printf 'Node: %s\nnpm: %s\n缓存: %s\n' "$(node --version)" "$(project_npm --version)" "$(project_npm config get cache)"
    project_npm ls --depth=0
    project_npm run check
    ;;
  build) project_npm run build ;;
esac
