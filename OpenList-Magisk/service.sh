#!/system/bin/sh
# shellcheck shell=ash
# service.sh for OpenList Magisk Module (All-in-One)

MODDIR="${0%/*}"
DATA_DIR="__PLACEHOLDER_DATA_DIR__"
OPENLIST_BINARY="__PLACEHOLDER_BINARY_PATH__"
BIN_DIR="$MODDIR/bin"
WEB_DIR="$MODDIR/web"
CONFIG_DIR="$DATA_DIR/config"
MODULE_PROP_FILE="$MODDIR/module.prop"
LOG_FILE="$MODDIR/service.log"
SERVICES_CONF="$CONFIG_DIR/services.conf"
TEMP_IP_FILE="$MODDIR/ip_result.tmp"

# ============== 通用工具函数 ==============

toast_find_busybox() {
    if [ -x "/data/adb/magisk/busybox" ]; then
        echo "/data/adb/magisk/busybox"
    elif [ -x "/data/adb/ksu/bin/busybox" ]; then
        echo "/data/adb/ksu/bin/busybox"
    elif command -v busybox >/dev/null; then
        command -v busybox
    else
        echo ""
    fi
}

log() {
    if [ -f "$LOG_FILE" ] && [ "$(stat -c %s "$LOG_FILE" 2>/dev/null || echo 0)" -gt 1048576 ]; then
        mv "$LOG_FILE" "${LOG_FILE}.bak"
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

wait_for_boot() {
    local elapsed=0
    local max_wait=60
    while [ $elapsed -lt $max_wait ]; do
        if [ "$(getprop sys.boot_completed)" = "1" ]; then
            log "系统启动完成"
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    log "警告: 等待系统启动超时"
}

get_lan_ip() {
    local BUSYBOX IP_CMD GREP_CMD AWK_CMD CUT_CMD HEAD_CMD
    BUSYBOX=$(toast_find_busybox)
    if [ -n "$BUSYBOX" ] && [ -x "$BUSYBOX" ]; then
        IP_CMD="$BUSYBOX ip"
        GREP_CMD="$BUSYBOX grep"
        AWK_CMD="$BUSYBOX awk"
        CUT_CMD="$BUSYBOX cut"
        HEAD_CMD="$BUSYBOX head"
    else
        IP_CMD="ip"
        GREP_CMD="grep"
        AWK_CMD="awk"
        CUT_CMD="cut"
        HEAD_CMD="head"
    fi

    local retry=0
    while [ $retry -lt 30 ]; do
        local iface=$($IP_CMD link 2>/dev/null | $GREP_CMD "state UP" | $AWK_CMD '{print $2}' | $CUT_CMD -d: -f1 | $GREP_CMD -E "^wlan" | $HEAD_CMD -n 1)
        if [ -z "$iface" ]; then
            echo "localhost"
            return 0
        fi
        local ip=$($IP_CMD addr show "$iface" 2>/dev/null | $GREP_CMD 'inet ' | $AWK_CMD '{print $2}' | $CUT_CMD -d/ -f1)
        if [ -n "$ip" ]; then
            echo "$ip"
            return 0
        fi
        sleep 1
        retry=$((retry + 1))
    done
    echo "无法获取IP"
}

is_service_enabled() {
    local service_name="$1"
    if [ ! -f "$SERVICES_CONF" ]; then
        return 1
    fi
    grep -q "^${service_name}=true" "$SERVICES_CONF" 2>/dev/null
}

get_pid() {
    local pattern="$1"
    pgrep -f "$pattern" 2>/dev/null | head -n 1
}

# ============== 配置文件生成 ==============

init_services_conf() {
    if [ ! -f "$SERVICES_CONF" ]; then
        log "创建服务配置文件: $SERVICES_CONF"
        cat > "$SERVICES_CONF" << 'EOF'
# OpenList All-in-One 服务启用配置
# 设置为 true 启用，false 禁用

# OpenList 文件服务器 (核心服务，建议保持启用)
openlist=true

# Aria2 下载器 (端口 6800)
aria2=false

# Qbittorrent BT下载 (端口 8080)
qbittorrent=false

# Frpc 内网穿透
frpc=false
EOF
    fi
}

init_aria2_conf() {
    local conf_file="$CONFIG_DIR/aria2.conf"
    local session_file="$DATA_DIR/aria2/aria2.session"
    local download_dir="$DATA_DIR/downloads"
    
    mkdir -p "$DATA_DIR/aria2"
    mkdir -p "$download_dir"
    touch "$session_file"
    
    if [ ! -f "$conf_file" ]; then
        log "创建 Aria2 配置文件: $conf_file"
        cat > "$conf_file" << EOF
# Aria2 配置文件

# 下载目录
dir=$download_dir

# 日志
log=$DATA_DIR/aria2/aria2.log
log-level=warn

# 会话文件
input-file=$session_file
save-session=$session_file
save-session-interval=60

# RPC 设置
enable-rpc=true
rpc-listen-all=true
rpc-listen-port=6800
rpc-allow-origin-all=true
rpc-secret=openlist

# 下载设置
max-concurrent-downloads=5
max-connection-per-server=16
min-split-size=1M
split=16
continue=true

# BT 设置
enable-dht=true
enable-dht6=true
bt-enable-lpd=true
bt-max-peers=128
bt-request-peer-speed-limit=10M

# 磁盘缓存
disk-cache=64M
file-allocation=none
EOF
    fi
}

init_qbittorrent_conf() {
    local qb_dir="$DATA_DIR/qbittorrent"
    local qb_conf_dir="$qb_dir/qBittorrent/config"
    local conf_file="$qb_conf_dir/qBittorrent.conf"
    local download_dir="$DATA_DIR/downloads"
    
    mkdir -p "$qb_conf_dir"
    mkdir -p "$download_dir"
    
    if [ ! -f "$conf_file" ]; then
        log "创建 Qbittorrent 配置文件: $conf_file"
        cat > "$conf_file" << EOF
[BitTorrent]
Session\DefaultSavePath=$download_dir
Session\Port=6881
Session\QueueingSystemEnabled=true

[Preferences]
WebUI\Enabled=true
WebUI\Port=8080
WebUI\Address=*
WebUI\LocalHostAuth=false
WebUI\AlternativeUIEnabled=true
WebUI\RootFolder=$WEB_DIR/vuetorrent
Downloads\SavePath=$download_dir
EOF
    fi
}

init_frpc_conf() {
    local conf_file="$CONFIG_DIR/frpc.toml"
    
    if [ ! -f "$conf_file" ]; then
        log "创建 Frpc 配置模板: $conf_file"
        cat > "$conf_file" << 'EOF'
# Frpc 配置文件
# 请根据你的 Frp 服务器信息修改

serverAddr = "your.frp.server.com"
serverPort = 7000
auth.token = "your_token"

# 示例: 暴露 OpenList
[[proxies]]
name = "openlist"
type = "tcp"
localIP = "127.0.0.1"
localPort = 5244
remotePort = 15244

# 示例: 暴露 Qbittorrent WebUI
# [[proxies]]
# name = "qbittorrent"
# type = "tcp"
# localIP = "127.0.0.1"
# localPort = 8080
# remotePort = 18080
EOF
        log "注意: Frpc 需要手动配置服务器信息后才能使用"
    fi
}

init_all_configs() {
    mkdir -p "$CONFIG_DIR"
    init_services_conf
    init_aria2_conf
    init_qbittorrent_conf
    init_frpc_conf
    log "配置文件初始化完成"
}

# ============== 服务启动函数 ==============

start_openlist() {
    if ! is_service_enabled "openlist"; then
        log "OpenList 已禁用，跳过启动"
        return 1
    fi
    
    if [ ! -x "$OPENLIST_BINARY" ]; then
        log "错误: OpenList 二进制不存在或不可执行"
        return 1
    fi
    
    local pid=$(get_pid "$OPENLIST_BINARY server")
    if [ -n "$pid" ]; then
        log "OpenList 已在运行 (PID: $pid)"
        return 0
    fi
    
    log "启动 OpenList..."
    $OPENLIST_BINARY server --data "$DATA_DIR" >> "$DATA_DIR/openlist.log" 2>&1 &
    sleep 2
    
    pid=$(get_pid "$OPENLIST_BINARY server")
    if [ -n "$pid" ]; then
        log "OpenList 启动成功 (PID: $pid)"
        return 0
    else
        log "错误: OpenList 启动失败"
        return 1
    fi
}

start_aria2() {
    if ! is_service_enabled "aria2"; then
        log "Aria2 已禁用，跳过启动"
        return 1
    fi
    
    local binary="$BIN_DIR/aria2c"
    local conf_file="$CONFIG_DIR/aria2.conf"
    
    if [ ! -x "$binary" ]; then
        log "错误: Aria2 二进制不存在"
        return 1
    fi
    
    if [ ! -f "$conf_file" ]; then
        log "错误: Aria2 配置文件不存在"
        return 1
    fi
    
    local pid=$(get_pid "aria2c")
    if [ -n "$pid" ]; then
        log "Aria2 已在运行 (PID: $pid)"
        return 0
    fi
    
    log "启动 Aria2..."
    "$binary" --conf-path="$conf_file" -D >> "$DATA_DIR/aria2/aria2.log" 2>&1
    sleep 2
    
    pid=$(get_pid "aria2c")
    if [ -n "$pid" ]; then
        log "Aria2 启动成功 (PID: $pid, RPC端口: 6800, 密钥: openlist)"
        return 0
    else
        log "错误: Aria2 启动失败"
        return 1
    fi
}

start_qbittorrent() {
    if ! is_service_enabled "qbittorrent"; then
        log "Qbittorrent 已禁用，跳过启动"
        return 1
    fi
    
    local binary="$BIN_DIR/qbittorrent-nox"
    local profile_dir="$DATA_DIR/qbittorrent"
    
    if [ ! -x "$binary" ]; then
        log "错误: Qbittorrent 二进制不存在"
        return 1
    fi
    
    local pid=$(get_pid "qbittorrent-nox")
    if [ -n "$pid" ]; then
        log "Qbittorrent 已在运行 (PID: $pid)"
        return 0
    fi
    
    log "启动 Qbittorrent..."
    "$binary" --profile="$profile_dir" -d >> "$DATA_DIR/qbittorrent/qbittorrent.log" 2>&1
    sleep 3
    
    pid=$(get_pid "qbittorrent-nox")
    if [ -n "$pid" ]; then
        log "Qbittorrent 启动成功 (PID: $pid, WebUI端口: 8080)"
        return 0
    else
        log "错误: Qbittorrent 启动失败"
        return 1
    fi
}

start_frpc() {
    if ! is_service_enabled "frpc"; then
        log "Frpc 已禁用，跳过启动"
        return 1
    fi
    
    local binary="$BIN_DIR/frpc"
    local conf_file="$CONFIG_DIR/frpc.toml"
    
    if [ ! -x "$binary" ]; then
        log "错误: Frpc 二进制不存在"
        return 1
    fi
    
    if [ ! -f "$conf_file" ]; then
        log "错误: Frpc 配置文件不存在"
        return 1
    fi
    
    # 检查是否已配置服务器
    if grep -q "your.frp.server.com" "$conf_file"; then
        log "警告: Frpc 未配置服务器信息，跳过启动"
        return 1
    fi
    
    local pid=$(get_pid "frpc -c")
    if [ -n "$pid" ]; then
        log "Frpc 已在运行 (PID: $pid)"
        return 0
    fi
    
    log "启动 Frpc..."
    "$binary" -c "$conf_file" >> "$DATA_DIR/frpc.log" 2>&1 &
    sleep 2
    
    pid=$(get_pid "frpc -c")
    if [ -n "$pid" ]; then
        log "Frpc 启动成功 (PID: $pid)"
        return 0
    else
        log "错误: Frpc 启动失败"
        return 1
    fi
}

# ============== 状态更新 ==============

update_module_prop() {
    local ip=$(get_lan_ip)
    local status_parts=""
    local running_count=0
    
    # OpenList 状态
    local ol_pid=$(get_pid "$OPENLIST_BINARY server")
    if [ -n "$ol_pid" ]; then
        status_parts="OpenList:${ip}:5244"
        running_count=$((running_count + 1))
    fi
    
    # Aria2 状态
    local aria2_pid=$(get_pid "aria2c")
    if [ -n "$aria2_pid" ]; then
        [ -n "$status_parts" ] && status_parts="$status_parts | "
        status_parts="${status_parts}Aria2:${ip}:6800"
        running_count=$((running_count + 1))
    fi
    
    # Qbittorrent 状态
    local qb_pid=$(get_pid "qbittorrent-nox")
    if [ -n "$qb_pid" ]; then
        [ -n "$status_parts" ] && status_parts="$status_parts | "
        status_parts="${status_parts}QB:${ip}:8080"
        running_count=$((running_count + 1))
    fi
    
    # Frpc 状态
    local frpc_pid=$(get_pid "frpc -c")
    if [ -n "$frpc_pid" ]; then
        [ -n "$status_parts" ] && status_parts="$status_parts | "
        status_parts="${status_parts}Frpc:运行中"
        running_count=$((running_count + 1))
    fi
    
    # 构建描述
    local new_desc
    if [ $running_count -gt 0 ]; then
        new_desc="description=【${running_count}个服务运行中】$status_parts | 配置目录: $CONFIG_DIR"
    else
        new_desc="description=【无服务运行】请检查 $SERVICES_CONF 配置"
    fi
    
    # 添加初始密码提示
    if [ -f "${DATA_DIR}/初始密码.txt" ]; then
        new_desc="$new_desc | OpenList密码: $(cat "${DATA_DIR}/初始密码.txt")"
    fi
    
    # 更新 module.prop
    if [ -f "$MODULE_PROP_FILE" ]; then
        grep -v '^description=' "$MODULE_PROP_FILE" > "${MODULE_PROP_FILE}.tmp"
        echo "$new_desc" >> "${MODULE_PROP_FILE}.tmp"
        mv "${MODULE_PROP_FILE}.tmp" "$MODULE_PROP_FILE"
        log "已更新 module.prop"
    fi
}

# ============== 主流程 ==============

main() {
    log "==============================================="
    log "OpenList All-in-One 服务启动"
    log "==============================================="
    
    # 前置检查
    if [ "$OPENLIST_BINARY" = "__PLACEHOLDER_BINARY_PATH__" ] || [ "$DATA_DIR" = "__PLACEHOLDER_DATA_DIR__" ]; then
        log "错误: 占位符未被替换，请检查安装脚本"
        exit 1
    fi
    
    # 等待系统启动
    wait_for_boot
    
    # 创建目录
    mkdir -p "$DATA_DIR"
    mkdir -p "$CONFIG_DIR"
    
    # 初始化配置文件
    init_all_configs
    
    # 设置二进制执行权限
    chmod 755 "$OPENLIST_BINARY" 2>/dev/null
    chmod 755 "$BIN_DIR"/* 2>/dev/null
    
    # 启动服务
    start_openlist
    start_aria2
    start_qbittorrent
    start_frpc
    
    # 更新状态显示
    sleep 2
    update_module_prop
    
    log "==============================================="
    log "服务启动流程完成"
    log "==============================================="
}

# 执行主函数
main
