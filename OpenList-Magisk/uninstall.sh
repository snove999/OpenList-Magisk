# shellcheck shell=ash
# uninstall.sh for OpenList Magisk/KSU/APatch Module (All-in-One)

#==== 框架检测：Magisk / KernelSU / APatch ====
if [ -n "$APATCH" ] || [ -n "$APATCH_VER" ]; then
    MODROOT="$MODPATH"
elif [ -n "$KSU" ] || [ -n "$KERNELSU" ]; then
    MODROOT="$MODULEROOT"
elif [ -n "$MAGISK_VER" ]; then
    MODROOT="$MODPATH"
else
    MODROOT="$MODPATH"
fi
#==== 框架检测结束 ====

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# 停止所有服务
stop_all_services() {
    log "正在停止所有服务..."
    
    local services="openlist aria2c qbittorrent-nox frpc"
    for svc in $services; do
        if pgrep -f "$svc" >/dev/null 2>&1; then
            log "停止 $svc..."
            pkill -f "$svc"
        fi
    done
    
    sleep 2
    
    for svc in $services; do
        if pgrep -f "$svc" >/dev/null 2>&1; then
            log "强制终止 $svc..."
            pkill -9 -f "$svc"
        fi
    done
    
    log "所有服务已停止"
}

# 清理二进制文件
clean_binaries() {
    log "清理二进制文件..."
    
    local openlist_paths="/data/adb/openlist/bin/openlist $MODROOT/bin/openlist $MODROOT/system/bin/openlist"
    for path in $openlist_paths; do
        [ -f "$path" ] && rm -f "$path" && log "删除: $path"
    done
    
    [ -d "$MODROOT/bin" ] && rm -rf "$MODROOT/bin" && log "删除: $MODROOT/bin"
    [ -d "$MODROOT/web" ] && rm -rf "$MODROOT/web" && log "删除: $MODROOT/web"
    
    log "二进制文件清理完成"
}

# 自动清理数据目录
clean_data() {
    log "清理数据目录..."
    
    local data_dirs="/data/adb/openlist /sdcard/Android/openlist"
    for dir in $data_dirs; do
        if [ -d "$dir" ]; then
            log "删除: $dir"
            rm -rf "$dir"
        fi
    done
    
    log "数据目录清理完成"
}

# 主卸载流程
main() {
    log "=========================================="
    log "卸载 OpenList All-in-One 模块"
    log "=========================================="
    
    stop_all_services
    clean_binaries
    clean_data
    
    log "=========================================="
    log "卸载完成，请重启设备"
    log "=========================================="
}

main
