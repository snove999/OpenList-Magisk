#!/system/bin/sh
# shellcheck shell=ash
# action.sh for OpenList Magisk Module (All-in-One)
# 支持 Magisk / KernelSU / APatch

MODDIR="${0%/*}"
MODULE_PROP="$MODDIR/module.prop"
SERVICE_SH="$MODDIR/service.sh"
BIN_DIR="$MODDIR/bin"
OPENLIST_BINARY="__PLACEHOLDER_BINARY_PATH__"
DATA_DIR="__PLACEHOLDER_DATA_DIR__"
REPO_URL="https://github.com/snove999/OpenList-Magisk"

#==== 框架检测：Magisk / KernelSU / APatch ====
detect_framework() {
    if [ -n "$APATCH" ] || [ -n "$APATCH_VER" ]; then
        FRAMEWORK="APatch"
    elif [ -n "$KSU" ] || [ -n "$KERNELSU" ]; then
        FRAMEWORK="KernelSU"
    elif [ -n "$MAGISK_VER" ]; then
        FRAMEWORK="Magisk"
    else
        if [ -d "/data/adb/ap" ]; then
            FRAMEWORK="APatch"
        elif [ -d "/data/adb/ksu" ]; then
            FRAMEWORK="KernelSU"
        else
            FRAMEWORK="Magisk"
        fi
    fi
}
detect_framework
#==== 框架检测结束 ====

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

# 获取服务状态
get_service_status() {
    local pattern="$1"
    if pgrep -f "$pattern" >/dev/null 2>&1; then
        local pid=$(pgrep -f "$pattern" | head -n1)
        echo "运行中 (PID: $pid)"
        return 0
    else
        echo "已停止"
        return 1
    fi
}

# 检查是否有任何服务在运行
any_service_running() {
    pgrep -f "openlist server" >/dev/null 2>&1 && return 0
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
            echo "  强制终止 $svc..."
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
    echo "📊 服务状态 [$FRAMEWORK]"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    echo "OpenList:     $(get_service_status 'openlist server')"
    echo "Aria2:        $(get_service_status 'aria2c')"
    echo "Qbittorrent:  $(get_service_status 'qbittorrent-nox')"
    echo "Frpc:         $(get_service_status 'frpc')"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ============== 主逻辑 ==============

echo "框架: $FRAMEWORK"

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
