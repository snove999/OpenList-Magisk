#!/system/bin/sh
# shellcheck shell=ash
# service.sh for OpenList Magisk Module (All-in-One)
# 支持 Magisk / KernelSU / APatch

MODDIR="${0%/*}"

#==== 框架检测：Magisk / KernelSU / APatch ====
detect_framework() {
    if [ -n "$APATCH" ] || [ -n "$APATCH_VER" ]; then
        FRAMEWORK="APatch"
    elif [ -n "$KSU" ] || [ -n "$KERNELSU" ]; then
        FRAMEWORK="KernelSU"
    elif [ -n "$MAGISK_VER" ]; then
        FRAMEWORK="Magisk"
    else
        # 通过路径推断
        if [ -d "/data/adb/ap" ]; then
            FRAMEWORK="APatch"
        elif [ -d "/data/adb/ksu" ]; then
            FRAMEWORK="KernelSU"
        elif [ -d "/data/adb/magisk" ]; then
            FRAMEWORK="Magisk"
        else
            FRAMEWORK="Unknown"
        fi
    fi
}
detect_framework
#==== 框架检测结束 ====

# 配置路径（由 customize.sh 替换）
OPENLIST_BINARY="__PLACEHOLDER_BINARY_PATH__"
DATA_DIR="__PLACEHOLDER_DATA_DIR__"

# 其他路径定义
BIN_DIR="$MODDIR/bin"
WEB_DIR="$MODDIR/web"
CONFIG_DIR="$DATA_DIR/config"
DOWNLOADS_DIR="$DATA_DIR/downloads"
LOG_FILE="$MODDIR/service.log"
MODULE_PROP="$MODDIR/module.prop"
SERVICES_CONF="$CONFIG_DIR/services.conf"
REPO_URL="https://github.com/snove999/OpenList-Magisk"

# 查找 BusyBox
find_busybox() {
    local paths="/data/adb/magisk/busybox /data/adb/ksu/bin/busybox /data/adb/ap/bin/busybox /system/xbin/busybox /system/bin/busybox"
    for path in $paths; do
        [ -x "$path" ] && echo "$path" && return 0
    done
    command -v busybox 2>/dev/null && return 0
    echo ""
}

BUSYBOX=$(find_busybox)

# 日志函数
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$FRAMEWORK] $1"
    echo "$msg" >> "$LOG_FILE"
    echo "$msg"
}

# 初始化日志
echo "========== Service Start $(date '+%Y-%m-%d %H:%M:%S') ==========" > "$LOG_FILE"
log "框架: $FRAMEWORK"
log "模块目录: $MODDIR"
log "数据目录: $DATA_DIR"

# 等待系统启动完成
wait_boot_complete() {
    log "等待系统启动完成..."
    local count=0
    while [ "$(getprop sys.boot_completed)" != "1" ]; do
        sleep 2
        count=$((count + 1))
        if [ $count -ge 60 ]; then
            log "警告: 等待启动超时，继续执行"
            break
        fi
    done
    sleep 5
    log "系统启动完成"
}

# 获取 IP 地址
get_ip_address() {
    local ip=""
    
    # WiFi IP
    ip=$(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 | head -n1)
    
    # 以太网 IP
    if [ -z "$ip" ]; then
        ip=$(ip addr show eth0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 | head -n1)
    fi
    
    # 移动网络 IP (rmnet)
    if [ -z "$ip" ]; then
        ip=$(ip addr 2>/dev/null | grep -E 'inet .*(rmnet|ccmni|usb)' | awk '{print $2}' | cut -d/ -f1 | head -n1)
    fi
    
    if [ -n "$ip" ]; then
        echo "$ip"
    else
        echo "localhost"
    fi
}

# 读取服务配置
read_service_config() {
    local service="$1"
    if [ -f "$SERVICES_CONF" ]; then
        local value=$(grep "^${service}=" "$SERVICES_CONF" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
        [ "$value" = "true" ] && return 0
    fi
    return 1
}

# 初始化默认配置文件
init_default_configs() {
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$DOWNLOADS_DIR"
    mkdir -p "$DATA_DIR/aria2"
    mkdir -p "$DATA_DIR/qbittorrent"
    
    # 服务配置
    if [ ! -f "$SERVICES_CONF" ]; then
        log "创建默认服务配置: $SERVICES_CONF"
        cat > "$SERVICES_CONF" << 'EOF'
# OpenList All-in-One 服务配置
# 设置为 true 启用，false 禁用
# 修改后重启设备或通过 Action 按钮重启服务

openlist=true
aria2=false
qbittorrent=false
frpc=false
EOF
    fi
    
    # Aria2 配置
    if [ ! -f "$CONFIG_DIR/aria2.conf" ]; then
        log "创建默认 Aria2 配置"
        cat > "$CONFIG_DIR/aria2.conf" << EOF
# Aria2 配置文件

# 下载目录
dir=$DOWNLOADS_DIR

# 日志
log=$DATA_DIR/aria2/aria2.log
log-level=warn

# 会话
input-file=$DATA_DIR/aria2/aria2.session
save-session=$DATA_DIR/aria2/aria2.session
save-session-interval=60

# RPC 设置
enable-rpc=true
rpc-listen-all=true
rpc-listen-port=6800
rpc-secret=openlist
rpc-allow-origin-all=true

# 下载设置
max-concurrent-downloads=5
continue=true
max-connection-per-server=16
min-split-size=10M
split=16
max-overall-download-limit=0
max-download-limit=0

# BT 设置
enable-dht=true
enable-dht6=true
bt-enable-lpd=true
bt-max-peers=128
bt-request-peer-speed-limit=10M

# 磁盘设置
disk-cache=64M
file-allocation=none
EOF
        touch "$DATA_DIR/aria2/aria2.session"
    fi
    
    # Frpc 配置模板
    if [ ! -f "$CONFIG_DIR/frpc.toml" ]; then
        log "创建 Frpc 配置模板"
        cat > "$CONFIG_DIR/frpc.toml" << 'EOF'
# Frpc 配置文件
# 请根据你的 Frp 服务器信息修改以下配置

serverAddr = "your.frp.server.com"
serverPort = 7000

auth.method = "token"
auth.token = "your_token_here"

# OpenList 穿透示例
[[proxies]]
name = "openlist"
type = "tcp"
localIP = "127.0.0.1"
localPort = 5244
remotePort = 15244

# Aria2 RPC 穿透示例（可选）
# [[proxies]]
# name = "aria2"
# type = "tcp"
# localIP = "127.0.0.1"
# localPort = 6800
# remotePort = 16800
EOF
    fi
}

# 启动 OpenList
start_openlist() {
    if ! read_service_config "openlist"; then
        log "OpenList 已禁用，跳过启动"
        return 1
    fi
    
    if pgrep -f "openlist server" >/dev/null 2>&1; then
        log "OpenList 已在运行"
        return 0
    fi
    
    log "启动 OpenList..."
    
    # 解析实际路径
    local binary_path=$(echo "$OPENLIST_BINARY" | sed "s|\$MODDIR|$MODDIR|g")
    
    if [ ! -x "$binary_path" ]; then
        log "错误: OpenList 二进制不存在或无执行权限: $binary_path"
        return 1
    fi
    
    nohup "$binary_path" server --data "$DATA_DIR" >> "$DATA_DIR/openlist.log" 2>&1 &
    local pid=$!
    sleep 2
    
    if kill -0 $pid 2>/dev/null; then
        log "OpenList 启动成功 (PID: $pid)"
        echo "$pid" > "$DATA_DIR/openlist.pid"
        return 0
    else
        log "OpenList 启动失败"
        return 1
    fi
}

# 启动 Aria2
start_aria2() {
    if ! read_service_config "aria2"; then
        log "Aria2 已禁用，跳过启动"
        return 1
    fi
    
    if pgrep -f "aria2c" >/dev/null 2>&1; then
        log "Aria2 已在运行"
        return 0
    fi
    
    local aria2_bin="$BIN_DIR/aria2c"
    if [ ! -x "$aria2_bin" ]; then
        log "Aria2 二进制不存在: $aria2_bin"
        return 1
    fi
    
    log "启动 Aria2..."
    nohup "$aria2_bin" --conf-path="$CONFIG_DIR/aria2.conf" >> "$DATA_DIR/aria2/aria2.log" 2>&1 &
    local pid=$!
    sleep 2
    
    if kill -0 $pid 2>/dev/null; then
        log "Aria2 启动成功 (PID: $pid)"
        return 0
    else
        log "Aria2 启动失败"
        return 1
    fi
}

# 启动 Qbittorrent
start_qbittorrent() {
    if ! read_service_config "qbittorrent"; then
        log "Qbittorrent 已禁用，跳过启动"
        return 1
    fi
    
    if pgrep -f "qbittorrent-nox" >/dev/null 2>&1; then
        log "Qbittorrent 已在运行"
        return 0
    fi
    
    local qb_bin="$BIN_DIR/qbittorrent-nox"
    if [ ! -x "$qb_bin" ]; then
        log "Qbittorrent 二进制不存在: $qb_bin"
        return 1
    fi
    
    local qb_profile="$DATA_DIR/qbittorrent"
    mkdir -p "$qb_profile"
    
    # 设置 VueTorrent WebUI
    if [ -d "$WEB_DIR/vuetorrent" ]; then
        mkdir -p "$qb_profile/qBittorrent/config"
        if [ ! -f "$qb_profile/qBittorrent/config/qBittorrent.conf" ]; then
            cat > "$qb_profile/qBittorrent/config/qBittorrent.conf" << EOF
[Preferences]
WebUI\Enabled=true
WebUI\Port=8080
WebUI\LocalHostAuth=false
WebUI\AlternativeUIEnabled=true
WebUI\RootFolder=$WEB_DIR/vuetorrent
Downloads\SavePath=$DOWNLOADS_DIR
EOF
        fi
    fi
    
    log "启动 Qbittorrent..."
    nohup "$qb_bin" --profile="$qb_profile" >> "$DATA_DIR/qbittorrent/qbittorrent.log" 2>&1 &
    local pid=$!
    sleep 3
    
    if kill -0 $pid 2>/dev/null; then
        log "Qbittorrent 启动成功 (PID: $pid)"
        return 0
    else
        log "Qbittorrent 启动失败"
        return 1
    fi
}

# 启动 Frpc
start_frpc() {
    if ! read_service_config "frpc"; then
        log "Frpc 已禁用，跳过启动"
        return 1
    fi
    
    if pgrep -f "frpc" >/dev/null 2>&1; then
        log "Frpc 已在运行"
        return 0
    fi
    
    local frpc_bin="$BIN_DIR/frpc"
    local frpc_conf="$CONFIG_DIR/frpc.toml"
    
    if [ ! -x "$frpc_bin" ]; then
        log "Frpc 二进制不存在: $frpc_bin"
        return 1
    fi
    
    if [ ! -f "$frpc_conf" ]; then
        log "Frpc 配置不存在: $frpc_conf"
        return 1
    fi
    
    # 检查是否已配置服务器
    if grep -q "your.frp.server.com" "$frpc_conf"; then
        log "Frpc 配置未修改，跳过启动"
        return 1
    fi
    
    log "启动 Frpc..."
    nohup "$frpc_bin" -c "$frpc_conf" >> "$DATA_DIR/frpc.log" 2>&1 &
    local pid=$!
    sleep 2
    
    if kill -0 $pid 2>/dev/null; then
        log "Frpc 启动成功 (PID: $pid)"
        return 0
    else
        log "Frpc 启动失败"
        return 1
    fi
}

# 更新模块描述
update_module_prop() {
    local ip=$(get_ip_address)
    local status_parts=""
    local running_count=0
    
    # 检查各服务状态
    if pgrep -f "openlist server" >/dev/null 2>&1; then
        local ol_pid=$(pgrep -f "openlist server" | head -n1)
        status_parts="${status_parts}OpenList:${ip}:5244(${ol_pid}) | "
        running_count=$((running_count + 1))
    fi
    
    if pgrep -f "aria2c" >/dev/null 2>&1; then
        local aria2_pid=$(pgrep -f "aria2c" | head -n1)
        status_parts="${status_parts}Aria2:${ip}:6800(${aria2_pid}) | "
        running_count=$((running_count + 1))
    fi
    
    if pgrep -f "qbittorrent-nox" >/dev/null 2>&1; then
        local qb_pid=$(pgrep -f "qbittorrent-nox" | head -n1)
        status_parts="${status_parts}QB:${ip}:8080(${qb_pid}) | "
        running_count=$((running_count + 1))
    fi
    
    if pgrep -f "frpc" >/dev/null 2>&1; then
        local frpc_pid=$(pgrep -f "frpc" | head -n1)
        status_parts="${status_parts}Frpc(${frpc_pid}) | "
        running_count=$((running_count + 1))
    fi
    
    # 生成描述
    local new_desc=""
    if [ $running_count -gt 0 ]; then
        status_parts=$(echo "$status_parts" | sed 's/ | $//')
        new_desc="description=【运行中】${status_parts}"
    else
        new_desc="description=【已停止】点击操作启动服务 | 项目: ${REPO_URL}"
    fi
    
    # 更新 module.prop
    if [ -n "$BUSYBOX" ]; then
        "$BUSYBOX" sed -i "s|^description=.*|$new_desc|" "$MODULE_PROP"
    else
        sed -i "s|^description=.*|$new_desc|" "$MODULE_PROP"
    fi
    
    log "模块描述已更新: $running_count 个服务运行中"
}

# ============== 主流程 ==============

main() {
    wait_boot_complete
    
    log "========== 初始化配置 =========="
    init_default_configs
    
    log "========== 启动服务 =========="
    start_openlist
    start_aria2
    start_qbittorrent
    start_frpc
    
    log "========== 更新状态 =========="
    update_module_prop
    
    log "========== 服务启动完成 =========="
}

main
