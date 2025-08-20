#!/bin/bash

# CD application control script.
# Version 4.3

# Install
#
## Project local install
# curl -o servicectl https://raw.githubusercontent.com/JonasGao/my-configs/master/cicd/v3multi/servicectl.sh
#
## Global install
# curl -o appctl https://raw.githubusercontent.com/JonasGao/my-configs/master/cicd/v3multi/servicectl.sh
# install appctl /usr/local/bin
# rm appctl

# 先存一个当前路径，说不定后边要用
CD=$(pwd)

# 工作空间
WD="$CD"

# 当前脚本的名字
PROG_NAME=$0

# 当前脚本的操作参数
ACTION="$1"

# 脚本版本号
VERSION="4.3"

# 应用的工作目录
# init 命令不强制要求参数目录已存在，未提供则使用当前目录
if [ "$ACTION" = "i" ] || [ "$ACTION" = "init" ]; then
  if [ -n "$2" ]; then
    case "$2" in
    /*)
      APP_HOME="$2"
      ;;
    *)
      APP_HOME="$(pwd)/$2"
      ;;
    esac
  else
    APP_HOME="$CD"
  fi
else
  APP_HOME=$(cd "$2" && pwd)
fi

# 应用目录名称
APP_NAME=$(basename "$WD/$APP_NAME")

# 准备相关工具
JAVA=$(which java 2>/dev/null)
NOHUP=$(which nohup 2>/dev/null)
PGREP=$(which pgrep 2>/dev/null)

# 环境配置文件名
SET_ENV_FILENAME="setenv.sh"

# 添加调试模式标志
[ -z "$SETENV_DEBUG" ] && SETENV_DEBUG=false

# 全局变量
CURR_PID=
OTHER_RUNNING=false

if [[ "$TERM" == xterm* ]]; then
  print-step() { printf "\r%s" "$1"; }
  start-step() { printf "\r%s" "$1"; }
  append-step() { printf "%s" "$1"; }
  finish-step() { printf "\r%s\n" "$1"; }
else
  print-step() { printf "%s\n" "$1"; }
  start-step() { printf "%s" "$1"; }
  append-step() { printf "%s\n" "$1"; }
  finish-step() { printf "%s\n" "$1"; }
fi

curlerr() {
  case $1 in
  7) printf "Failed to connect() to host or proxy." ;;
  *) printf "CURL return %s" "$1" ;;
  esac
}

health-check() {
  if [ "$HEALTH_CHECK" = "1" ]; then
    echo "Health check disabled"
    return
  fi
  exp_time=0
  echo "Health checking ${HEALTH_CHECK_URL}"
  while true; do
    start-step "$exp_time."
    if status_code=$(/usr/bin/curl -L -o /dev/null --connect-timeout 5 -s -w "%{http_code}" "${HEALTH_CHECK_URL}"); then
      append-step " Http respond $status_code"
      for code in "${HEALTH_HTTP_CODE[@]}"; do
        if [ "$status_code" == "$code" ]; then
          # break 2, finish health check.
          break 2
        fi
      done
    else
      append-step " $(curlerr $?)"
    fi

    # exp_time mod 10 == 0, check process is running.
    if [ $((exp_time % 10)) -eq 0 ]; then
      query-java-pid
      if [ "$CURR_PID" = "" ]; then
        finish-step "App start failed. try tail application log."
        tail "${APP_LOG}"
        exit 2
      fi
    fi

    sleep 1
    ((exp_time++))

    if [ "$exp_time" -gt "${APP_START_TIMEOUT}" ]; then
      finish-step "App start failed. try tail application log."
      tail "${APP_LOG}"
      exit 2
    fi
  done
  finish-step "Health check ${HEALTH_CHECK_URL} success."
}

print-info() {
  # 输出到文件时去除颜色代码
  echo "Working Directory: $(pwd)"
  echo "Using:"
  echo "  nohup: $NOHUP"
  echo "  java:  $JAVA"
  echo "  opts:  ${JVM_OPTS}"
  echo "  jar:   ${JAR_PATH}"
  echo "  args:  ${JAR_ARGS}"
}

start-application() {
  query-java-pid
  if [ "$CURR_PID" = "" ]; then
    if [ ! -f "$JAR_PATH" ]; then
      echo "There is no file \"$JAR_PATH\"" >&2
      exit 5
    fi
    cd "$APP_HOME" || exit 7
    print-info | tee "${LOG_HOME}/version.info"
    ${NOHUP} ${JAVA} ${JVM_OPTS} -jar ${JAR_PATH} ${JAR_ARGS} >${STD_OUT} 2>&1 &
    local PID=$!
    local NOHUP_RET=$?
    local RET=99
    if [ "$NOHUP_RET" = "0" ]; then
      echo "Run nohup succeed (NOHUP RETURN: $NOHUP_RET, APP PID: $PID)"
      echo "$PID" >"$PID_PATH"
      echo "Wait $PROC_START_TIMEOUT second."
      sleep "$PROC_START_TIMEOUT"
      if [ ! -d "/proc/$PID" ]; then
        wait "$PID"
        RET=$?
        echo "ERROR: Run app fail. Return: $RET"
        exit 4
      fi
    else
      echo "ERROR: Run jar failed with ($NOHUP_RET)"
      exit 3
    fi
  else
    echo "Running in $CURR_PID"
    OTHER_RUNNING=true
  fi
}

query-java-pid() {
  CURR_PID=
  if [ -f "$PID_PATH" ]; then
    local pid
    pid=$(cat "$PID_PATH")
    if ps "$pid" >/dev/null 2>&1; then
      CURR_PID="$pid"
      echo "Got pid ($pid) from \"$PID_PATH\""
    else
      echo "PID ($pid) from \"$PID_PATH\" can not found by ps. Will search by pgrep."
      rm -f "$PID_PATH"
    fi
  fi

  if [ -z "$CURR_PID" ] && [ -x "$PGREP" ]; then
    # 使用pgrep更精确地查找java进程，排除当前shell进程
    CURR_PID=$($PGREP -f "java.*$(basename "$JAR_PATH")" -v -p "$$" 2>/dev/null)

    # 如果找到多个进程，尝试更精确匹配
    local pid_count
    pid_count=$(echo "$CURR_PID" | wc -l)
    if [ "$pid_count" -gt 1 ]; then
      echo "WARNING: Found multiple processes, trying more precise matching"
      CURR_PID=$($PGREP -f "java.*-jar.*$(basename "$JAR_PATH")" -v -p "$$" 2>/dev/null)
    fi
  fi

  # 最后的验证，确保进程确实存在
  if [ -n "$CURR_PID" ]; then
    if ! ps $CURR_PID >/dev/null 2>&1; then
      CURR_PID=
    fi
  fi
}

stop-application() {
  query-java-pid

  if [[ ! $CURR_PID ]]; then
    echo "No java process!"
    return
  fi

  echo "Stopping java process ($CURR_PID)."
  times="$APP_START_TIMEOUT"
  for e in $(seq $times); do
    sleep 1
    COST_TIME=$((times - e))
    if ps "$CURR_PID" >/dev/null; then
      kill "$CURR_PID"
      print-step "Stopping java lasts $COST_TIME seconds."
    else
      finish-step "Java process has exited. Remove PID \"$PID_PATH\""
      rm "$PID_PATH" >/dev/null
      return
    fi
  done
  finish-step "Java process failed exit. Still running in $CURR_PID"
  exit 4
}

start() {
  start-application
  if [ "$OTHER_RUNNING" = false ]; then
    health-check
  fi
}

stop() {
  stop-application
}

# 新增deploy函数
deploy() {
  # 检查是否提供了第三个参数（jar包名称）
  if [ -n "$3" ]; then
    DEPLOY_JAR_PATH="$3"
    # 完全按照当前运行目录来处理指定的jar包路径
    DEPLOY_JAR_ABS_PATH="$(pwd)/$DEPLOY_JAR_PATH"
    DEPLOY_JAR_NAME=$(basename "$DEPLOY_JAR_PATH")
    echo "Deploying custom JAR: $DEPLOY_JAR_NAME from $DEPLOY_JAR_ABS_PATH"
  else
    DEPLOY_JAR_NAME="${JAR_NAME}.jar"
    DEPLOY_JAR_ABS_PATH="$APP_HOME/$DEPLOY_JAR_NAME"
    echo "Deploying default JAR: $DEPLOY_JAR_NAME"
  fi

  if [ ! -f "$DEPLOY_JAR_ABS_PATH" ]; then
    echo -e "\033[31mError: Deployment target does not exist: $DEPLOY_JAR_ABS_PATH\033[0m" >&2
    echo "Use '$PROG_NAME d --help' for deploy command help."
    exit 10
  fi
  echo "Do deploy. Stop first."
  stop
  echo "Replace $JAR_PATH with $DEPLOY_JAR_ABS_PATH"
  cp "$JAR_PATH" "${JAR_PATH}.bak"
  echo "Backup to ${JAR_PATH}.bak"
  cp "$DEPLOY_JAR_ABS_PATH" "$JAR_PATH"
  echo "Wait 1 second."
  sleep 1
  # 部署成功后删除指定的jar包
  rm "$DEPLOY_JAR_ABS_PATH"
  echo "Removed $DEPLOY_JAR_ABS_PATH"
  echo "Startup..."
  start
}

init-dirs() {
  echo "Initializing required directories..."
  # 创建出相关目录
  for d in "${INIT_DIRS[@]}"; do
    if [ ! -d "$d" ]; then
      echo "Creating directory: $d"
      mkdir -p "$d"
    else
      echo "Directory already exists: $d"
    fi
  done
  echo "Directory initialization completed."
}

update-self() {
  # 检查是否设置了GHPROXY，并提供相关信息
  if [ -n "$GHPROXY" ]; then
    # 确保GHPROXY以/结尾
    case "$GHPROXY" in
    */)
      # 已经以/结尾，无需处理
      ;;
    *)
      # 添加结尾的/
      GHPROXY="${GHPROXY}/"
      ;;
    esac
    echo "Using GHPROXY: $GHPROXY"
  else
    echo "No GHPROXY set. Using direct connection to GitHub."
    echo "If you're behind a firewall, you can set GHPROXY to improve connectivity."
    echo "Example: export GHPROXY=https://ghproxy.com/"
  fi

  echo "Update location: $PROG_NAME"

  # 创建临时文件用于下载
  local tmp_file=$(mktemp)
  if [ $? -ne 0 ]; then
    echo -e "\033[31mError: Failed to create temporary file for update\033[0m" >&2
    exit 1
  fi

  # 构建下载URL
  local download_url="${GHPROXY}https://raw.githubusercontent.com/JonasGao/my-configs/master/cicd/v3multi/servicectl.sh"
  # 通过时间戳禁用 HTTP 缓存
  local no_cache_ts=$(date +%s)
  local download_url_nc="${download_url}?_ts=${no_cache_ts}"
  echo "Downloading from: $download_url_nc"

  # 下载新版本
  echo "Downloading update..."
  if ! curl -f -s -H "Cache-Control: no-cache" -H "Pragma: no-cache" -o "$tmp_file" "$download_url_nc"; then
    echo -e "\033[31mError: Failed to download update from $download_url_nc\033[0m" >&2
    rm -f "$tmp_file"
    exit 1
  fi

  # 检查下载的文件是否为空
  if [ ! -s "$tmp_file" ]; then
    echo -e "\033[31mError: Downloaded update file is empty\033[0m" >&2
    rm -f "$tmp_file"
    exit 1
  fi

  # 简单验证下载的文件是否为有效的shell脚本
  if ! head -n 1 "$tmp_file" | grep -q "^#!.*bash"; then
    echo -e "\033[31mWarning: Downloaded file may not be a valid bash script\033[0m" >&2
    echo "First few lines of downloaded file:"
    head -n 3 "$tmp_file"
  fi

  # 备份当前版本
  local backup_file="${PROG_NAME}.bak"
  echo "Backing up current version to $backup_file"
  if ! cp "$PROG_NAME" "$backup_file"; then
    echo -e "\033[31mError: Failed to backup current version\033[0m" >&2
    rm -f "$tmp_file"
    exit 1
  fi

  # 应用更新
  echo "Applying update..."
  if ! mv "$tmp_file" "$PROG_NAME"; then
    echo -e "\033[31mError: Failed to apply update. Restoring from backup.\033[0m" >&2
    mv "$backup_file" "$PROG_NAME"
    rm -f "$tmp_file"
    exit 1
  fi

  # 设置执行权限
  chmod 755 "$PROG_NAME"

  # 删除备份文件（更新成功）
  rm -f "$backup_file"

  echo -e "\e[32mSuccessfully updated $PROG_NAME\e[0m"
}

usage() {
  printf """Usage: %s <command> <service|dir name> [jar file name]
There are some commands:
  i, init
  d, deploy
  s, start
  t, stop
  r, restart
  p, pid
  c, check
  u, update
  g, generate-env  Generate setenv.sh template
Version: %s
""" "$PROG_NAME" "$VERSION"
}

# 生成环境配置文件模板的函数
generate_env_template() {
  local target_dir="${1:-$APP_HOME/conf}"
  local template_file="$target_dir/$SET_ENV_FILENAME"

  if [ ! -d "$target_dir" ]; then
    echo "Error: Target directory does not exist: $target_dir" >&2
    return 1
  fi

  if [ -f "$template_file" ]; then
    echo "Warning: $template_file already exists. Skipping generation." >&2
    return 0
  fi

  cat >"$template_file" <<'EOF'
#!/bin/bash
# Environment configuration file for servicectl
# This file is automatically sourced by servicectl if it exists

# Application name (default: app)
# JAR_NAME="myapp"

# Application port (default: 8080)
# APP_PORT=8080

# JVM options (default: "-server -XX:+UseG1GC -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=$APP_HOME/logs/")
# JVM_OPTS="-server -Xmx1g -XX:+UseG1GC -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=$APP_HOME/logs/"

# JAR arguments (default: "--server.port=${APP_PORT}")
# JAR_ARGS="--server.port=${APP_PORT} --spring.profiles.active=prod"

# Process start timeout in seconds (default: 3)
# PROC_START_TIMEOUT=3

# Application start timeout in seconds (default: 150)
# APP_START_TIMEOUT=150

# Health check URL (default: "http://127.0.0.1:${APP_PORT}")
# HEALTH_CHECK_URL="http://127.0.0.1:${APP_PORT}/actuator/health"

# Disable health check (default: not set)
# HEALTH_CHECK=1

# Debug mode for setenv (default: false)
# SETENV_DEBUG=true

# Example of computed values
# LOG_HOME="$APP_HOME/logs"
# CUSTOM_VAR="some value"

# Example of variable interpolation
# DATABASE_URL="jdbc:mysql://localhost:3306/${JAR_NAME}_db"

echo "Custom environment loaded from $0"
EOF

  chmod +x "$template_file"
  echo "Generated setenv.sh template at $template_file"
}

# 部署命令帮助函数
deploy-help() {
  cat <<'EOF'

Deploy command:
  The deploy command will:
  1. Stop the currently running application
  2. Backup the current JAR file
  3. Replace it with the new JAR file from the service directory
  4. Start the application with the new JAR file

  Requirements:
  - A JAR file must exist in the service directory with the name specified or ${JAR_NAME}.jar by default
  - The application must be initialized (directories created) before deploying
  - The service directory must be specified as the second argument

  Usage:
    %s d <service> [jar-file-name]

  Examples:
    %s d my-service
    %s d my-service my-app-1.0.jar

EOF
}

# 环境配置文件帮助函数
env-help() {
  cat <<'EOF'

Environment Configuration:
  The servicectl script supports environment configuration through setenv.sh files.
  These files are sourced automatically if they exist in the following locations:
  
  1. Application conf directory: <app-home>/conf/setenv.sh
  2. Parent directory of APP_HOME: <app-home-parent>/setenv.sh
  3. User home directory: ~/setenv.sh
  
  The application conf setenv.sh takes precedence over the parent directory setenv.sh,
  which takes precedence over the user home directory setenv.sh.

Environment Variables:
  You can configure the following variables in setenv.sh:
  
  - JAR_NAME: Application JAR name (default: app)
  - APP_PORT: Port on which the application runs (default: 8080)
  - JVM_OPTS: JVM options (default: "-server -XX:+UseG1GC -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=$APP_HOME/logs/")
  - JAR_ARGS: Arguments passed to the JAR file (default: "--server.port=${APP_PORT}")
  - PROC_START_TIMEOUT: Process start timeout in seconds (default: 3)
  - APP_START_TIMEOUT: Application start timeout in seconds (default: 150)
  - HEALTH_CHECK_URL: Health check URL (default: "http://127.0.0.1:${APP_PORT}")
  - HEALTH_CHECK: Set to 1 to disable health check
  - SETENV_DEBUG: Set to true to enable environment loading debug output

Generate Template:
  To generate a template setenv.sh file, use:
    %s g [target-directory]
    
  Examples:
    %s g
    %s g /path/to/app/conf

EOF
}

# 加载环境配置文件的专用函数
load-environment() {
  # Check for setenv.sh in APP_HOME/conf directory (highest precedence)
  if [ -f "$APP_HOME/conf/$SET_ENV_FILENAME" ]; then
    if [ "$SETENV_DEBUG" = true ]; then
      echo "Loading environment from $APP_HOME/conf/$SET_ENV_FILENAME"
    fi
    source "$APP_HOME/conf/$SET_ENV_FILENAME"
  fi

  # Check for setenv.sh in parent directory of APP_HOME
  local parent_dir=$(dirname "$APP_HOME")
  if [ -f "$parent_dir/$SET_ENV_FILENAME" ]; then
    if [ "$SETENV_DEBUG" = true ]; then
      echo "Loading environment from $parent_dir/$SET_ENV_FILENAME"
    fi
    source "$parent_dir/$SET_ENV_FILENAME"
  fi

  # Check for setenv.sh in user's HOME directory (lowest precedence)
  if [ -f "$HOME/$SET_ENV_FILENAME" ]; then
    if [ "$SETENV_DEBUG" = true ]; then
      echo "Loading environment from $HOME/$SET_ENV_FILENAME"
    fi
    source "$HOME/$SET_ENV_FILENAME"
  fi
}

# 检查参数
if [ -z "$ACTION" ]; then
  echo -e "\033[31mError: Missing argument 'command' at position 1.\033[0m" >&2
  usage
  exit 1
fi

case "$ACTION" in
u | update)
  # Ignore #2 validation
  update-self
  exit 0
  ;;
i | init)
  # init 不需要第二个参数
  ;;
g | generate-env)
  generate_env_template "$2"
  exit 0
  ;;
d | deploy)
  # Deploy command can have help parameters without service name
  if [ "$2" = "-h" ] || [ "$2" = "--help" ]; then
    deploy-help
    exit 0
  elif [ -z "$2" ]; then
    echo -e "\033[31mError: Missing argument 'service or dir name' at position 2.\033[0m" >&2
    usage
    exit 2
  fi
  ;;
h | help | --help)
  # Help command doesn't require service name
  usage
  echo
  env-help
  exit 0
  ;;
*)
  if [ -z "$2" ]; then
    echo -e "\033[31mError: Missing argument 'service or dir name' at position 2.\033[0m" >&2
    usage
    exit 2
  fi
  ;;
esac

# 检查基本目录是否存在（init 跳过）
if [ "$ACTION" != "i" ] && [ "$ACTION" != "init" ]; then
  if [ ! -d "$APP_HOME" ]; then
    echo -e "\033[31mError: App home directory does not exist.\033[0m" >&2
    exit 9
  fi
fi

# 加载环境配置文件
load-environment

# 在环境变量加载后重新定义依赖这些变量的变量
# 日志输出目录
LOG_HOME="${APP_HOME}/logs"

# 程序库目录
LIB_HOME="${APP_HOME}/lib"

# 配置目录
CONF_HOME="${APP_HOME}/conf"

# 应用名称
[ -z "$JAR_NAME" ] && JAR_NAME="app"

# 应用启动的端口
[ -z "$APP_PORT" ] && APP_PORT=8080

# JVM 配置参数
[ -z "$JVM_OPTS" ] && JVM_OPTS="-server -XX:+UseG1GC -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=$APP_HOME/logs/"

# JAR 包启动的时候传递的参数
JAR_ARGS="--server.port=${APP_PORT}"

# 进程启动等待时间
[ -z "$PROC_START_TIMEOUT" ] && PROC_START_TIMEOUT=3

# 等待应用启动的时间
[ -z "$APP_START_TIMEOUT" ] && APP_START_TIMEOUT=150

# JAR 包的绝对路径
JAR_PATH="${LIB_HOME}/${JAR_NAME}.jar"

# 应用的控制台输出
STD_OUT="${LOG_HOME}/std.out"

# 应用的日志文件
APP_LOG=${STD_OUT}

# PID 位置
PID_PATH="${CONF_HOME}/pid"

# 需要初始化的目录
INIT_DIRS=("$APP_HOME" "$LOG_HOME" "$CONF_HOME" "$LIB_HOME")

# 应用健康检查URL
HEALTH_CHECK_URL="http://127.0.0.1:${APP_PORT}"

# 健康的HTTP代码
HEALTH_HTTP_CODE=(200 404 403 405)

case "$ACTION" in
d | deploy)
  deploy "$@"
  ;;
s | start)
  start
  ;;
t | stop)
  stop
  ;;
r | restart)
  echo "Do restart. Stop first."
  stop
  echo "Wait 1 second."
  sleep 1
  echo "Startup..."
  start
  ;;
p | pid)
  query-java-pid
  echo "Current running in $CURR_PID"
  ;;
c | check)
  print-info
  health-check
  ;;
i | init)
  init-dirs
  ;;
*)
  echo -e "\033[31mError: Unknown command '$ACTION'\033[0m" >&2
  usage
  exit 1
  ;;
esac
