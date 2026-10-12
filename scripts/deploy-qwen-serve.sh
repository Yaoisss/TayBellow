#!/usr/bin/env bash

# 一键部署并管理本仓库的 qwen serve 守护进程：从本地源码构建安装 CLI、生成 token，
# 写 systemd 用户服务（没有 systemd 时回退 nohup），并管理其生命周期。
#
# 用法：scripts/deploy-qwen-serve.sh <命令> [选项]，详见 --help。

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ---- 默认配置（环境变量优先，其次安装时写的 conf 文件）--------------------
QWEN_SERVE_HOME="${QWEN_SERVE_HOME:-$HOME}"
QWEN_SERVE_UNIT_DIR="${QWEN_SERVE_UNIT_DIR:-$HOME/.config/systemd/user}"
QWEN_SERVE_SERVICE_NAME="${QWEN_SERVE_SERVICE_NAME:-qwen-serve.service}"
QWEN_SERVE_BACKEND="${QWEN_SERVE_BACKEND:-auto}"      # auto | systemd | nohup
QWEN_SERVE_HOST="${QWEN_SERVE_HOST:-0.0.0.0}"
QWEN_SERVE_PORT="${QWEN_SERVE_PORT:-4170}"
QWEN_SERVE_DIRS="${QWEN_SERVE_DIRS:-}"                # 工作区（空格分隔）
QWEN_SERVE_ARGS="${QWEN_SERVE_ARGS:-}"                # 额外的 `qwen serve` 参数
QWEN_NODE_VERSION="${QWEN_NODE_VERSION:-22.23.2}"     # 系统无 Node ≥22 时下载的版本
QWEN_INSTALL_ROOT="${QWEN_INSTALL_ROOT:-$HOME/.local}" # CLI standalone 安装位置

CONF_FILE="$QWEN_SERVE_HOME/.qwen-serve.conf"
TOKEN_FILE="$QWEN_SERVE_HOME/.qwen-serve-token"
ENV_FILE="$QWEN_SERVE_HOME/.qwen-serve-token-env"
PID_FILE="$QWEN_SERVE_HOME/.qwen-serve.pid"
LOG_FILE="$QWEN_SERVE_HOME/.qwen-serve.log"
UNIT_FILE="$QWEN_SERVE_UNIT_DIR/$QWEN_SERVE_SERVICE_NAME"
BUILD_CACHE="$QWEN_SERVE_HOME/.cache/qwen-build"

if [ -f "$CONF_FILE" ]; then
  # shellcheck source=/dev/null
  . "$CONF_FILE"
fi

# ---- 镜像（默认官方源；网络受限时用 QWEN_MIRROR=cn）------------------------
if [ "${QWEN_MIRROR:-}" = "cn" ]; then
  QWEN_NODE_MIRROR="${QWEN_NODE_MIRROR:-https://npmmirror.com/mirrors/node}"
  QWEN_NPM_REGISTRY="${QWEN_NPM_REGISTRY:-https://registry.npmmirror.com}"
fi
QWEN_NODE_MIRROR="${QWEN_NODE_MIRROR:-https://nodejs.org/dist}"
if [ -n "${QWEN_NPM_REGISTRY:-}" ]; then
  # 环境变量优先于仓库 .npmrc，corepack/pnpm/npm 都读得到
  export COREPACK_NPM_REGISTRY="$QWEN_NPM_REGISTRY"
  export npm_config_registry="$QWEN_NPM_REGISTRY"
  export NPM_CONFIG_REGISTRY="$QWEN_NPM_REGISTRY"
fi

# ---- 输出 ----------------------------------------------------------------
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
log_info() { printf '%b[INFO]%b %s\n' "$BLUE" "$NC" "$1"; }
log_ok() { printf '%b[OK]%b %s\n' "$GREEN" "$NC" "$1"; }
log_warn() { printf '%b[WARN]%b %s\n' "$YELLOW" "$NC" "$1"; }
log_err() { printf '%b[ERROR]%b %s\n' "$RED" "$NC" "$1" >&2; }
die() { log_err "$1"; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---- 环境与工具链 --------------------------------------------------------
ensure_base_tools() {
  local missing=() cmd
  for cmd in git curl tar openssl; do have "$cmd" || missing+=("$cmd"); done
  if [ "${#missing[@]}" -gt 0 ] && have apt-get; then
    log_info "安装基础工具：${missing[*]}"
    local sudo_cmd=""
    [ "$(id -u)" -ne 0 ] && have sudo && sudo_cmd="sudo"
    $sudo_cmd apt-get update -qq || true
    $sudo_cmd apt-get install -y git curl tar xz-utils openssl ca-certificates >/dev/null 2>&1 || true
  fi
  for cmd in git curl tar openssl; do have "$cmd" || die "缺少必要命令：$cmd"; done
}

check_base_tools() {
  local cmd
  for cmd in git curl tar openssl; do have "$cmd" || die "缺少必要命令：$cmd"; done
}

setup_locale_and_fonts() {
  have apt-get || return 0
  local sudo_cmd=""
  [ "$(id -u)" -ne 0 ] && have sudo && sudo_cmd="sudo"
  if ! locale -a 2>/dev/null | grep -qE 'zh_CN\.(utf8|UTF-8)'; then
    log_info "配置 zh_CN.UTF-8 locale"
    $sudo_cmd apt-get install -y locales >/dev/null 2>&1 || true
    $sudo_cmd sed -i '/zh_CN.UTF-8/s/^# //g' /etc/locale.gen 2>/dev/null || true
    $sudo_cmd locale-gen zh_CN.UTF-8 >/dev/null 2>&1 || true
  fi
  if have fc-list && ! fc-list :lang=zh >/dev/null 2>&1; then
    log_info "安装中文字体"
    $sudo_cmd apt-get install -y fonts-noto-cjk fonts-wqy-zenhei fonts-wqy-microhei >/dev/null 2>&1 || true
  fi
}

host_arch() {
  case "$(uname -m)" in
    x86_64 | amd64) echo x64 ;;
    aarch64 | arm64) echo arm64 ;;
    *) die "不支持的架构：$(uname -m)" ;;
  esac
}

package_target() {
  case "$(host_arch)" in
    x64) echo linux-x64 ;;
    arm64) echo linux-arm64 ;;
  esac
}

node_archive_name() { echo "node-v${QWEN_NODE_VERSION}-linux-$(host_arch).tar.xz"; }
node_runtime_dir() { echo "$BUILD_CACHE/node-v${QWEN_NODE_VERSION}-linux-$(host_arch)"; }

node_ok() {
  have node || return 1
  local major
  major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
  [ "$major" -ge 22 ] 2>/dev/null
}

corepack_ok() { have corepack && corepack pnpm --version >/dev/null 2>&1; }

# 仓库自己的构建脚本内部也调用 corepack，所以两者都必须来自完整 Node 发行包。
ensure_toolchain() {
  if node_ok && corepack_ok; then
    log_ok "使用系统 Node $(node --version)"
    return 0
  fi
  local dir archive
  dir="$(node_runtime_dir)"
  archive="$BUILD_CACHE/$(node_archive_name)"
  mkdir -p "$BUILD_CACHE"

  if [ ! -x "$dir/bin/node" ]; then
    if [ ! -f "$archive" ]; then
      log_info "下载 Node v${QWEN_NODE_VERSION}（构建用运行时）"
      curl -fsSL "${QWEN_NODE_MIRROR}/v${QWEN_NODE_VERSION}/$(node_archive_name)" -o "$archive.part"
      mv "$archive.part" "$archive"
    fi
    log_info "解压到 $BUILD_CACHE"
    rm -rf "$dir"
    tar -xJf "$archive" -C "$BUILD_CACHE"
    [ -x "$dir/bin/node" ] ||
      die "解压后找不到 $dir/bin/node；归档 $(node_archive_name) 可能与 $(host_arch) 不匹配"
  fi

  export PATH="$dir/bin:$PATH"
  hash -r 2>/dev/null || true
  node_ok || die "Node 运行时不可用：$dir/bin"
  if ! corepack_ok; then
    log_err "corepack 跑不起来：$dir/bin/corepack"
    log_err "常见原因：① 通过 proxychains 3.1 运行会把 node 打崩（Aborted），请改用 proxychains-ng 4.x 或不挂代理；"
    log_err "          ② 网络受限需要国内镜像，用 QWEN_MIRROR=cn 重跑"
    exit 1
  fi
  log_ok "使用下载的 Node $(node --version)"
}

# ---- 构建并安装 CLI ------------------------------------------------------
build_and_install_cli() {
  local target archive
  target="$(package_target)"
  archive="$REPO_DIR/dist/standalone/qwen-code-${target}.tar.gz"

  if [ "${QWEN_SKIP_BUILD:-0}" != "1" ]; then
    ensure_toolchain
    log_info "安装依赖（首次会构建一次，耗时数分钟）"
    (cd "$REPO_DIR" && corepack pnpm install --frozen-lockfile)
    log_info "构建、打包并生成 standalone 归档（target=${target}）"
    (cd "$REPO_DIR" && npm run build && npm run bundle && npm run prepare:package)
    (cd "$REPO_DIR" && npm run package:standalone -- --target "$target" \
      --node-archive "$BUILD_CACHE/$(node_archive_name)")
  fi
  [ -f "$archive" ] || die "找不到归档 $archive；去掉 --skip-build 重新执行"

  log_info "安装 CLI 到 $QWEN_INSTALL_ROOT"
  QWEN_INSTALL_ROOT="$QWEN_INSTALL_ROOT" \
    bash "$REPO_DIR/scripts/installation/install-qwen-standalone.sh" \
    --archive "$archive" --source local-build

  export PATH="$QWEN_INSTALL_ROOT/bin:$PATH"
  hash -r 2>/dev/null || true
  QWEN_BIN="$(command -v qwen)" || die "安装后找不到 qwen：$QWEN_INSTALL_ROOT/bin"
  log_ok "CLI 就绪：$QWEN_BIN（$("$QWEN_BIN" --version 2>/dev/null || echo '版本未知')）"
}

resolve_qwen_bin() {
  if [ -n "${QWEN_BIN:-}" ] && [ -x "${QWEN_BIN:-}" ]; then return 0; fi
  if [ -x "$QWEN_INSTALL_ROOT/bin/qwen" ]; then
    QWEN_BIN="$QWEN_INSTALL_ROOT/bin/qwen"
  else
    QWEN_BIN="$(command -v qwen || true)"
  fi
  [ -n "$QWEN_BIN" ] || die "找不到 qwen，请先执行 '$0 install'"
}

ensure_token() {
  mkdir -p "$QWEN_SERVE_HOME"
  if [ ! -f "$TOKEN_FILE" ]; then
    log_info "生成新的 bearer token"
    (umask 077; openssl rand -hex 32 >"$TOKEN_FILE")
  fi
  chmod 600 "$TOKEN_FILE"
  (umask 077; {
    printf 'QWEN_SERVER_TOKEN=%s\n' "$(cat "$TOKEN_FILE")"
    printf 'LANG=zh_CN.UTF-8\nLC_ALL=zh_CN.UTF-8\n'
  } >"$ENV_FILE")
  chmod 600 "$ENV_FILE"
}

write_conf() {
  (umask 077; {
    printf 'QWEN_SERVE_HOST=%q\n' "$QWEN_SERVE_HOST"
    printf 'QWEN_SERVE_PORT=%q\n' "$QWEN_SERVE_PORT"
    printf 'QWEN_SERVE_DIRS=%q\n' "$QWEN_SERVE_DIRS"
    printf 'QWEN_SERVE_ARGS=%q\n' "$QWEN_SERVE_ARGS"
    printf 'QWEN_SERVE_BACKEND=%q\n' "$QWEN_SERVE_BACKEND"
  } >"$CONF_FILE")
}

# ---- 后端 ----------------------------------------------------------------
systemd_available() {
  have systemctl || return 1
  systemctl --user is-system-running >/dev/null 2>&1 || systemctl --user status >/dev/null 2>&1
}

# StandardOutput=append: 需要 systemd ≥240（Debian 11 / Ubuntu 22.04 起满足）；
# 日志写到文件后，很多机器上不可用的 user journal 就不再是唯一线索。
systemd_supports_append() {
  local v
  v="$(systemctl --version 2>/dev/null | head -1 | awk '{print $2}')"
  [ "${v:-0}" -ge 240 ] 2>/dev/null
}

unit_log_lines() {
  if systemd_supports_append; then
    printf 'StandardOutput=append:%s\nStandardError=append:%s\n' "$LOG_FILE" "$LOG_FILE"
  else
    printf 'StandardOutput=journal\nStandardError=journal\n'
  fi
}

port_in_use() {
  have ss || return 1
  ss -ltn 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${QWEN_SERVE_PORT}\$"
}

resolve_backend() {
  if [ "$QWEN_SERVE_BACKEND" = auto ]; then
    if systemd_available; then QWEN_SERVE_BACKEND=systemd; else QWEN_SERVE_BACKEND=nohup; fi
  fi
  case "$QWEN_SERVE_BACKEND" in
    systemd | nohup) ;;
    *) die "QWEN_SERVE_BACKEND 只能是 auto / systemd / nohup" ;;
  esac
}

# ---- 工作区与 unit ------------------------------------------------------
resolve_workspaces() {
  local args="" first="" dir
  for dir in $QWEN_SERVE_DIRS; do
    if [ -d "$dir" ]; then
      args="$args --workspace $(cd "$dir" && pwd)"
      [ -z "$first" ] && first="$(cd "$dir" && pwd)"
    else
      log_warn "目录不存在，跳过：$dir"
    fi
  done
  if [ -z "$first" ]; then
    first="$(pwd)"
    args="--workspace $first"
  fi
  FIRST_WORKSPACE="$first"
  WORKSPACE_ARGS="$args"
}

unit_text() {
  resolve_qwen_bin
  resolve_workspaces
  local log_lines
  log_lines="$(unit_log_lines)"
  cat <<EOF
[Unit]
Description=Qwen Code 守护进程（HTTP + SSE）
After=network.target

[Service]
Type=simple
WorkingDirectory=$FIRST_WORKSPACE
ExecStart=$QWEN_BIN serve --hostname $QWEN_SERVE_HOST --port $QWEN_SERVE_PORT$WORKSPACE_ARGS${QWEN_SERVE_ARGS:+ $QWEN_SERVE_ARGS}
Environment=PATH=$(dirname "$QWEN_BIN"):/usr/local/bin:/usr/bin:/bin
EnvironmentFile=$ENV_FILE
Restart=on-failure
RestartSec=5
$log_lines

[Install]
WantedBy=default.target
EOF
}

# ---- 健康检查与运行态 ----------------------------------------------------
health_check() {
  have curl || return 1
  local host="$QWEN_SERVE_HOST"
  case "$host" in 0.0.0.0 | "::") host=127.0.0.1 ;; esac
  curl -fsS -H "Authorization: Bearer $(cat "$TOKEN_FILE" 2>/dev/null || true)" \
    "http://${host}:${QWEN_SERVE_PORT}/health" >/dev/null 2>&1
}

wait_health() {
  local i
  for ((i = 0; i < 30; i++)); do
    health_check && return 0
    sleep 0.5
  done
  return 1
}

nohup_running() {
  [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

service_active() {
  if [ "$QWEN_SERVE_BACKEND" = systemd ]; then
    [ -f "$UNIT_FILE" ] || return 1
    systemctl --user is-active --quiet "$QWEN_SERVE_SERVICE_NAME"
  else
    nohup_running
  fi
}

# ---- 命令 ----------------------------------------------------------------
cmd_install() {
  local skip_build=0 print_unit=0 dirs=()
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --skip-build) skip_build=1 ;;
      --print-unit) print_unit=1 ;;
      -h | --help) usage; return 0 ;;
      *) dirs+=("$1") ;;
    esac
    shift
  done
  if [ "${#dirs[@]}" -gt 0 ]; then
    local abs=() d
    for d in "${dirs[@]}"; do
      if [ -d "$d" ]; then abs+=("$(cd "$d" && pwd)"); else log_warn "目录不存在，跳过：$d"; fi
    done
    [ "${#abs[@]}" -gt 0 ] && QWEN_SERVE_DIRS="${abs[*]}"
  fi

  resolve_backend

  if [ "$print_unit" = "1" ]; then
    [ "$QWEN_SERVE_BACKEND" = systemd ] || die "--print-unit 需要 systemd 后端"
    unit_text
    return 0
  fi

  log_info "检查运行环境"
  if [ -n "${QWEN_NPM_REGISTRY:-}" ]; then
    log_info "镜像：node=$QWEN_NODE_MIRROR，registry=$QWEN_NPM_REGISTRY"
  else
    log_info "镜像：node=$QWEN_NODE_MIRROR，registry=官方默认（网络受限时加 QWEN_MIRROR=cn）"
  fi
  if [ "${QWEN_SERVE_SKIP_SYSTEM_SETUP:-0}" = "1" ]; then
    log_info "按 QWEN_SERVE_SKIP_SYSTEM_SETUP=1 跳过系统包安装"
    check_base_tools
  else
    ensure_base_tools
    setup_locale_and_fonts
  fi

  QWEN_SKIP_BUILD="$skip_build"
  build_and_install_cli
  ensure_token
  write_conf

  if [ "$QWEN_SERVE_BACKEND" = systemd ]; then
    log_info "写入 systemd 用户服务：$UNIT_FILE"
    mkdir -p "$QWEN_SERVE_UNIT_DIR"
    unit_text >"$UNIT_FILE"
    systemctl --user daemon-reload
    if systemctl --user is-active --quiet "$QWEN_SERVE_SERVICE_NAME"; then
      log_info "服务已在运行，重启以应用新配置"
      systemctl --user restart "$QWEN_SERVE_SERVICE_NAME"
    else
      if port_in_use && ! systemctl --user is-active --quiet "$QWEN_SERVE_SERVICE_NAME"; then
        log_warn "端口 ${QWEN_SERVE_PORT} 已被占用，若启动后反复重启请用 'ss -ltnp | grep ${QWEN_SERVE_PORT}' 查占用者"
      fi
      systemctl --user enable --now "$QWEN_SERVE_SERVICE_NAME"
      loginctl enable-linger "$(whoami)" 2>/dev/null ||
        log_warn "loginctl enable-linger 失败：退出登录后服务可能不会继续运行"
    fi
    if wait_health; then
      log_ok "安装完成，/health 正常"
    else
      log_warn "服务已启动但 /health 未在 15 秒内就绪；最近状态："
      service_diagnose
    fi
    print_status
    return 0
  fi

  log_info "未检测到 systemd，改用 nohup 后台运行"
  cmd_start
}

cmd_start() {
  if [ "$QWEN_SERVE_BACKEND" = systemd ]; then
    [ -f "$UNIT_FILE" ] || die "服务尚未安装，请先执行 '$0 install'"
    systemctl --user start "$QWEN_SERVE_SERVICE_NAME"
  else
    if nohup_running; then
      log_warn "已在运行（pid $(cat "$PID_FILE")）"
    else
      [ -f "$TOKEN_FILE" ] || die "没有 token，请先执行 '$0 install'"
      resolve_qwen_bin
      resolve_workspaces
      QWEN_SERVER_TOKEN="$(cat "$TOKEN_FILE")" nohup "$QWEN_BIN" serve \
        --hostname "$QWEN_SERVE_HOST" --port "$QWEN_SERVE_PORT"$WORKSPACE_ARGS${QWEN_SERVE_ARGS:+ $QWEN_SERVE_ARGS} \
        >>"$LOG_FILE" 2>&1 &
      echo $! >"$PID_FILE"
      log_info "已后台启动（pid $(cat "$PID_FILE")），日志：$LOG_FILE"
    fi
  fi
  wait_health || log_warn "/health 未在 15 秒内就绪"
  print_status
}

cmd_stop() {
  local quiet=0
  [ "${1:-}" = "--quiet" ] && quiet=1
  if [ "$QWEN_SERVE_BACKEND" = systemd ]; then
    systemctl --user stop "$QWEN_SERVE_SERVICE_NAME" 2>/dev/null || true
  else
    if nohup_running; then
      local pid i
      pid="$(cat "$PID_FILE")"
      kill "$pid" 2>/dev/null || true
      for ((i = 0; i < 20; i++)); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.5
      done
      if kill -0 "$pid" 2>/dev/null; then
        kill -KILL "$pid" 2>/dev/null || true
        log_warn "SIGTERM 10 秒无效，已强杀 (pid $pid)"
      else
        log_ok "已停止 (pid $pid)"
      fi
    else
      log_warn "未在运行"
    fi
    rm -f "$PID_FILE"
  fi
  [ "$quiet" = "1" ] || print_status
}

cmd_restart() {
  if [ "$QWEN_SERVE_BACKEND" = systemd ]; then
    [ -f "$UNIT_FILE" ] || die "服务尚未安装，请先执行 '$0 install'"
    systemctl --user restart "$QWEN_SERVE_SERVICE_NAME"
    wait_health || log_warn "/health 未在 15 秒内就绪"
    print_status
  else
    cmd_stop --quiet
    cmd_start
  fi
}

cmd_logs() {
  if [ "$QWEN_SERVE_BACKEND" = systemd ]; then
    if systemd_supports_append; then
      [ -f "$LOG_FILE" ] || die "没有日志文件：$LOG_FILE"
      tail -n 200 -f "$LOG_FILE"
    else
      journalctl --user -u "$QWEN_SERVE_SERVICE_NAME" -f
    fi
  else
    [ -f "$LOG_FILE" ] || die "没有日志：$LOG_FILE"
    tail -n 200 -f "$LOG_FILE"
  fi
}

# 启动异常时的现场：状态、退出码、重启次数、最近日志
service_diagnose() {
  systemctl --user status "$QWEN_SERVE_SERVICE_NAME" --no-pager -l 2>/dev/null | head -12 || true
  local restarts
  restarts="$(systemctl --user show "$QWEN_SERVE_SERVICE_NAME" --property=NRestarts --value 2>/dev/null || true)"
  if [ -n "$restarts" ] && [ "$restarts" -gt 0 ] 2>/dev/null; then
    log_warn "服务已重启 $restarts 次（持续增长说明启动即崩）"
  fi
  if [ -f "$LOG_FILE" ]; then
    echo "--- $LOG_FILE 末尾 ---"
    tail -n 15 "$LOG_FILE" 2>/dev/null || true
  elif have journalctl; then
    echo "--- journalctl 末尾 ---"
    journalctl --user -u "$QWEN_SERVE_SERVICE_NAME" -n 15 --no-pager 2>/dev/null || true
  fi
}

cmd_token() {
  ensure_token
  log_ok "token 已轮换：$TOKEN_FILE"
  log_info "重启以生效：$0 restart"
}

cmd_uninstall() {
  log_info "卸载服务"
  if [ "$QWEN_SERVE_BACKEND" = systemd ]; then
    systemctl --user stop "$QWEN_SERVE_SERVICE_NAME" 2>/dev/null || true
    systemctl --user disable "$QWEN_SERVE_SERVICE_NAME" 2>/dev/null || true
    if [ -f "$UNIT_FILE" ]; then
      rm -f "$UNIT_FILE"
      systemctl --user daemon-reload 2>/dev/null || true
      log_ok "systemd 服务已删除"
    fi
  else
    nohup_running && kill "$(cat "$PID_FILE")" 2>/dev/null || true
    rm -f "$PID_FILE"
    log_ok "后台进程已停止"
  fi

  local reply="n"
  if [ -t 0 ]; then
    read -r -p "是否同时删除 token 文件？(y/N) " reply || reply="n"
  fi
  if [[ "$reply" =~ ^[Yy]$ ]]; then
    rm -f "$TOKEN_FILE" "$ENV_FILE"
    log_ok "token 文件已删除"
  else
    log_info "已保留 token 文件：$TOKEN_FILE"
  fi
}

print_status() {
  local active=inactive pid=0
  if [ "$QWEN_SERVE_BACKEND" = systemd ]; then
    [ -f "$UNIT_FILE" ] || {
      log_warn "服务尚未安装（$UNIT_FILE 不存在）"
      return 1
    }
    active="$(systemctl --user is-active "$QWEN_SERVE_SERVICE_NAME" 2>/dev/null || true)"
    [ -n "$active" ] || active=inactive
    pid="$(systemctl --user show "$QWEN_SERVE_SERVICE_NAME" --property=MainPID --value 2>/dev/null || echo 0)"
  elif nohup_running; then
    active=active
    pid="$(cat "$PID_FILE")"
  fi

  echo "============================================================"
  if [ "$active" = "active" ]; then
    echo -e "运行状态 : 🟢 ${GREEN}active${NC}（pid $pid）"
  else
    echo -e "运行状态 : 🔴 ${RED}${active}${NC}"
    if [ "$QWEN_SERVE_BACKEND" = systemd ]; then
      local sub restarts
      sub="$(systemctl --user show "$QWEN_SERVE_SERVICE_NAME" --property=SubState --value 2>/dev/null || true)"
      restarts="$(systemctl --user show "$QWEN_SERVE_SERVICE_NAME" --property=NRestarts --value 2>/dev/null || true)"
      echo -e "子状态   : ${sub:-未知}${restarts:+（已重启 $restarts 次）}"
      echo -e "提示     : 反复 activating 通常是启动即崩，看 '$(basename "$0")' logs 或 systemctl --user status $QWEN_SERVE_SERVICE_NAME"
    fi
  fi
  echo -e "后端     : $QWEN_SERVE_BACKEND"
  echo -e "监听     : ${QWEN_SERVE_HOST}:${QWEN_SERVE_PORT}"
  if [ "$QWEN_SERVE_BACKEND" = systemd ] && [ -f "$UNIT_FILE" ]; then
    local work; work="$(grep '^WorkingDirectory=' "$UNIT_FILE" 2>/dev/null | cut -d= -f2- || true)"
    echo -e "工作目录 : ${work:-未设置}"
    grep -oE '\-\-workspace [^ ]+' "$UNIT_FILE" 2>/dev/null | awk '{print "           - " $2}' || true
  elif [ -n "$QWEN_SERVE_DIRS" ]; then
    local d
    for d in $QWEN_SERVE_DIRS; do echo -e "工作区   : $d"; done
  fi
  echo -e "Token    : ${YELLOW}$(cat "$TOKEN_FILE" 2>/dev/null || echo '未找到 token 文件')${NC}"
  if [ "$active" = "active" ]; then
    if health_check; then
      echo -e "健康检查 : 🟢 /health 正常"
    else
      echo -e "健康检查 : 🔴 /health 异常"
    fi
  fi
  echo "============================================================"
}

usage() {
  cat <<EOF
用法：$(basename "$0") <命令> [选项]

  install [目录...]   从本地源码构建安装 CLI、生成 token、写入并启动服务
      --skip-build    跳过构建，直接用 dist/standalone 下的归档
      --print-unit    只打印将生成的 systemd unit（不写入、不启动）
  start               启动服务
  stop                停止服务
  restart             重启服务
  status              查看运行状态、工作区与 token
  logs                跟踪日志（systemd 与 nohup 都写 ~/.qwen-serve.log，systemd <240 时用 journalctl）
  token               轮换 token（restart 生效）
  uninstall           停止并删除服务，可选择同时删除 token

环境变量：QWEN_SERVE_HOME、QWEN_SERVE_UNIT_DIR、QWEN_SERVE_SERVICE_NAME、
  QWEN_SERVE_BACKEND(auto|systemd|nohup)、QWEN_SERVE_HOST、QWEN_SERVE_PORT、
  QWEN_SERVE_DIRS、QWEN_SERVE_ARGS、QWEN_NODE_VERSION、QWEN_INSTALL_ROOT、
  QWEN_SERVE_SKIP_SYSTEM_SETUP=1（跳过 apt 装基础工具/locale/字体）
镜像：QWEN_MIRROR=cn（等价于把下面两项设成 npmmirror）、QWEN_NODE_MIRROR、
  QWEN_NPM_REGISTRY（会导出给 corepack/pnpm/npm）
注意：不要用 proxychains 3.1 运行（会把 node 打崩），需要代理请用 proxychains-ng 4.x

示例：
  $(basename "$0") install ~/project-a ~/project-b
  $(basename "$0") install --skip-build
  QWEN_SERVE_PORT=4587 $(basename "$0") install
  QWEN_MIRROR=cn $(basename "$0") install
  $(basename "$0") logs
EOF
}

main() {
  local cmd="${1:-}"
  if [ "$#" -gt 0 ]; then shift; fi
  resolve_backend
  case "$cmd" in
    install | setup) cmd_install "$@" ;;
    start) cmd_start ;;
    stop) cmd_stop ;;
    restart) cmd_restart ;;
    status) print_status ;;
    logs) cmd_logs ;;
    token) cmd_token ;;
    uninstall | remove) cmd_uninstall ;;
    "")
      if service_active || [ -f "$UNIT_FILE" ]; then print_status; else cmd_install "$@"; fi
      ;;
    -h | --help | help) usage ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
}

main "$@"
