#!/system/bin/sh
# shellcheck shell=ash
# action.sh for OpenList Magisk Module (All-in-One)

MODDIR="${0%/*}"
MODULE_PROP="$MODDIR/module.prop"
SERVICE_SH="$MODDIR/service.sh"
BIN_DIR="$MODDIR/bin"
OPENLIST_BINARY="__PLACEHOLDER_BINARY_PATH__"
DATA_DIR="__PLACEHOLDER_DATA_DIR__"
REPO_URL="https://github.com/snove999/OpenList-Magisk"

# 查找 BusyBox
find_busybox() {
    local paths="/data/adb/magisk/busybox /data/adb/ksu/bin/busybox /system/xbin/busybox /system/bin/busybox"
    for path in $paths; do
        [ -x "$path" ] && echo "$path" && return 0
    done
    command -v busybox 2>/dev/null && return 0
    echo ""
}

BUSYBOX=$(find_busybox)

# 获取服务状态
get_service_status() {
    local name="$1"
    local pattern="$2"
    if pgrep -f "$pattern" >/dev/null 2>&1; then
        echo "运行中"
        return 0
    else
        echo "已停止"
        return 1
    fi
}

# 检查是否有任何服务在运行
any_service_running() {
    pgrep -f "openlist" >/dev/null 2>&1 && return 0
    pgrep -f "aria2c" >/dev/null 2>&1 && return 0
    pgrep -f "qbittorrent-nox" >/dev/null 2>&1 && return 0
    pgrep -f "frpc" >/dev/null 2>&1 && return 0
    return 1
}

# 停止所有服务
stop_all_services() {
    echo "正在停止所有服务..."
    
    local services="openlist aria2c qbittorrent-nox frpc"
    for svc in $services; do
        if pgrep -f "$svc" >/dev/null 2>&1; then
            echo "  停止 $svc..."
            pkill -f "$svc"
        fi
    done
    
    sleep 2
    
    # 强制终止
    for svc in $services; do
        if pgrep -f "$svc" >/dev/null 2>&1; then
            pkill -9 -f "$svc"
        fi
    done
    
    echo "所有服务已停止"
}

# 更新 module.prop 为停止状态
update_module_prop_stopped() {
    local new_desc="description=【已停止】点击操作启动服务 | 项目: ${REPO_URL}"
    if [ -n "$BUSYBOX" ]; then
        "$BUSYBOX" sed -i "s|^description=.*|$new_desc|" "$MODULE_PROP"
    else
        sed -i "s|^description=.*|$new_desc|" "$MODULE_PROP"
    fi
}

# 显示当前状态
show_status() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 服务状态"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local ol_status=$(get_service_status "OpenList" "openlist")
    local aria2_status=$(get_service_status "Aria2" "aria2c")
    local qb_status=$(get_service_status "Qbittorrent" "qbittorrent-nox")
    local frpc_status=$(get_service_status "Frpc" "frpc")
    
    echo "OpenList:     $ol_status"
    echo "Aria2:        $aria2_status"
    echo "Qbittorrent:  $qb_status"
    echo "Frpc:         $frpc_status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ============== 主逻辑 ==============

if any_service_running; then
    # 有服务在运行，执行停止
    show_status
    stop_all_services
    update_module_prop_stopped
    echo ""
    echo "✅ 所有服务已停止"
else
    # 无服务运行，执行启动
    echo "正在启动服务..."
    
    if [ -f "$SERVICE_SH" ]; then
        sh "$SERVICE_SH"
        sleep 3
        
        if any_service_running; then
            show_status
            echo ""
            echo "✅ 服务启动成功"
        else
            echo "❌ 服务启动失败，请检查日志: $MODDIR/service.log"
            exit 1
        fi
    else
        echo "❌ 错误: service.sh 不存在"
        exit 1
    fi
fi
