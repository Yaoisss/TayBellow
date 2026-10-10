#!/usr/bin/env bash

# Install and manage a long-lived `qwen serve` daemon from one script:
# install, start, stop, restart, status, logs, token.
# Documented in docs/users/qwen-serve-deploy-local.md.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOKEN_FILE="${QWEN_SERVE_TOKEN_FILE:-$HOME/.qwen-serve-token}"
PID_FILE="${QWEN_SERVE_PID_FILE:-$HOME/.qwen-serve.pid}"
LOG_FILE="${QWEN_SERVE_LOG_FILE:-$HOME/.qwen-serve.log}"
CONF_FILE="${QWEN_SERVE_CONF:-$HOME/.qwen-serve-ctl.conf}"
PACKAGE='@qwen-code/qwen-code'

# Built-in defaults; the environment overrides these, and the conf file
# (sourced below) overrides both.
QWEN_BIN="${QWEN_BIN:-qwen}"
QWEN_HOST="${QWEN_HOST:-127.0.0.1}"
QWEN_PORT="${QWEN_PORT:-4170}"
if [ -f "$CONF_FILE" ]; then
  # shellcheck source=/dev/null
  . "$CONF_FILE"
fi

usage() {
  cat <<EOF
Usage: $(basename "$0") <command>

  install   Install the qwen CLI (existing install is kept) and create the
            bearer token file if missing
  start     Start 'qwen serve' in the background and wait for /health
  stop      Stop the running daemon (SIGTERM, SIGKILL after 10s)
  restart   stop + start
  status    Process and /health state (exit 0 running, 1 unhealthy,
            3 stopped)
  logs      Tail the daemon log (last 200 lines)
  token     Rotate the bearer token (restart to apply)

Config file (bash, sourced): $CONF_FILE
  QWEN_BIN (qwen), QWEN_HOST (127.0.0.1), QWEN_PORT (4170),
  QWEN_WORKSPACES (array of absolute paths), QWEN_EXTRA_ARGS (extra
  'qwen serve' args, space-separated)
Files: token=$TOKEN_FILE pid=$PID_FILE log=$LOG_FILE
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

generate_token() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
  elif command -v node >/dev/null 2>&1; then
    node -e 'console.log(require("crypto").randomBytes(32).toString("hex"))'
  else
    die "neither openssl nor node available to generate a token"
  fi
}

is_running() {
  [ -f "$PID_FILE" ] || return 1
  kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

probe_health() {
  command -v curl >/dev/null 2>&1 || return 1
  local host="$QWEN_HOST"
  case "$host" in 0.0.0.0 | "::") host=127.0.0.1 ;; esac
  curl -fsS -H "Authorization: Bearer $(cat "$TOKEN_FILE" 2>/dev/null || true)" \
    "http://${host}:${QWEN_PORT}/health" >/dev/null 2>&1
}

cmd_install() {
  if ! command -v "$QWEN_BIN" >/dev/null 2>&1; then
    local installer="$SCRIPT_DIR/installation/install-qwen-standalone.sh"
    if [ -x "$installer" ]; then
      "$installer"
    else
      command -v npm >/dev/null 2>&1 ||
        die "npm not found and no bundled installer at $installer"
      npm install -g "$PACKAGE"
    fi
  fi
  if ! command -v "$QWEN_BIN" >/dev/null 2>&1; then
    echo "note: $QWEN_BIN was installed but is not on PATH yet; open a new shell before 'start'."
  fi
  if [ -f "$TOKEN_FILE" ]; then
    echo "token kept: $TOKEN_FILE"
  else
    (umask 077; generate_token >"$TOKEN_FILE")
    echo "token created: $TOKEN_FILE"
  fi
  echo "install ok: $($QWEN_BIN --version 2>/dev/null | head -1 || true)"
}

cmd_start() {
  if is_running; then
    die "already running (pid $(cat "$PID_FILE"))"
  fi
  [ -f "$TOKEN_FILE" ] ||
    die "no token at $TOKEN_FILE; run '$(basename "$0")' install first"
  local bin
  bin="$(command -v "$QWEN_BIN")" || die "$QWEN_BIN not found on PATH; run install first"

  local args=(--hostname "$QWEN_HOST" --port "$QWEN_PORT")
  local ws
  for ws in ${QWEN_WORKSPACES[@]+"${QWEN_WORKSPACES[@]}"}; do
    args+=(--workspace "$ws")
  done
  local extra=()
  # QWEN_EXTRA_ARGS is a space-separated string; splitting on purpose.
  if [ -n "${QWEN_EXTRA_ARGS:-}" ]; then
    read -r -a extra <<<"$QWEN_EXTRA_ARGS"
  fi

  QWEN_SERVER_TOKEN="$(cat "$TOKEN_FILE")" \
    nohup "$bin" serve "${args[@]}" ${extra[@]+"${extra[@]}"} \
    >>"$LOG_FILE" 2>&1 &
  echo $! >"$PID_FILE"
  local pid
  pid="$(cat "$PID_FILE")"

  if ! command -v curl >/dev/null 2>&1; then
    echo "started (pid $pid); curl not found, skipped the /health check"
    return
  fi
  local i
  for ((i = 0; i < 30; i++)); do
    if probe_health; then
      echo "started (pid $pid) http://${QWEN_HOST}:${QWEN_PORT}"
      return
    fi
    if ! kill -0 "$pid" 2>/dev/null; then
      rm -f "$PID_FILE"
      tail -n 20 "$LOG_FILE" >&2 || true
      die "daemon exited during startup (log tail above)"
    fi
    sleep 0.5
  done
  tail -n 20 "$LOG_FILE" >&2 || true
  die "started (pid $pid) but /health not ready within 15s (log tail above)"
}

cmd_stop() {
  if ! is_running; then
    rm -f "$PID_FILE"
    echo "not running"
    return
  fi
  local pid i
  pid="$(cat "$PID_FILE")"
  kill "$pid" 2>/dev/null || true
  for ((i = 0; i < 20; i++)); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.5
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill -KILL "$pid" 2>/dev/null || true
    echo "force-killed (pid $pid): it ignored SIGTERM for 10s"
  fi
  rm -f "$PID_FILE"
  echo "stopped (pid $pid)"
}

cmd_restart() {
  cmd_stop
  cmd_start
}

cmd_status() {
  if ! is_running; then
    rm -f "$PID_FILE"
    echo "stopped"
    exit 3
  fi
  local pid
  pid="$(cat "$PID_FILE")"
  if probe_health; then
    echo "running (pid $pid), /health ok"
  else
    echo "running (pid $pid), /health NOT ok — see '$(basename "$0")' logs" >&2
    exit 1
  fi
}

cmd_logs() {
  [ -f "$LOG_FILE" ] || die "no log at $LOG_FILE"
  tail -n 200 -f "$LOG_FILE"
}

cmd_token() {
  (umask 077; generate_token >"$TOKEN_FILE.tmp") && mv "$TOKEN_FILE.tmp" "$TOKEN_FILE"
  echo "token rotated: $TOKEN_FILE"
  if is_running; then
    echo "restart to apply: $(basename "$0") restart"
  fi
}

case "${1:-}" in
install | start | stop | restart | status | logs | token)
  "cmd_$1"
  ;;
-h | --help | help)
  usage
  ;;
"")
  usage
  exit 2
  ;;
*)
  usage >&2
  exit 2
  ;;
esac
