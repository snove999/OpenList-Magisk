# shellcheck shell=ash
# uninstall-user.sh for OpenList Magisk/KSU Module (All-in-One)
# 交互式卸载，允许用户选择是否保留数据

#==== 侦探：Magisk or KernelSU ====
if [ -n "$MAGISK_VER" ]; then
    MODROOT="$MODPATH"
elif [ -n "$KSU" ] || [ -n "$KERNELSU" ]; then
    MODROOT="$MODULEROOT"
else
    MODROOT="$MODPATH"
fi
#==== 侦探结束 ====

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
    
    # 强制终止残留进程
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
        [ -f "$path" ] && rm -f "$path" && log "已删除: $path"
    done
    
    [ -d "$MODROOT/bin" ] && rm -rf "$MODROOT/bin" && log "已删除: $MODROOT/bin"
    [ -d "$MODROOT/web" ] && rm -rf "$MODROOT/web" && log "已删除: $MODROOT/web"
    
    log "二进制文件清理完成"
}

# 交互式数据清理
clean_data() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📁 数据清理选项"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "1. 保留所有数据（配置、下载等）"
    echo "2. 仅删除配置，保留下载文件"
    echo "3. 删除所有数据"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -n "请选择 [1-3]: "
    read -r choice

    case "$choice" in
        1)
            log "已选择：保留所有数据"
            ;;
        2)
            log "已选择：仅删除配置文件"
            for dir in "/data/adb/openlist" "/sdcard/Android/openlist"; do
                if [ -d "$dir/config" ]; then
                    log "删除配置目录: $dir/config"
                    rm -rf "$dir/config"
                fi
                # 删除各服务的配置/日志，保留 downloads
                [ -d "$dir/aria2" ] && rm -rf "$dir/aria2" && log "删除: $dir/aria2"
                [ -d "$dir/qbittorrent/qBittorrent" ] && rm -rf "$dir/qbittorrent/qBittorrent" && log "删除: $dir/qbittorrent/qBittorrent"
                [ -f "$dir/openlist.log" ] && rm -f "$dir/openlist.log"
                [ -f "$dir/frpc.log" ] && rm -f "$dir/frpc.log"
            done
            log "配置文件清理完成，下载文件已保留"
            ;;
        3)
            log "已选择：删除所有数据"
            for dir in "/data/adb/openlist" "/sdcard/Android/openlist"; do
                if [ -d "$dir" ]; then
                    log "删除数据目录: $dir"
                    rm -rf "$dir"
                fi
            done
            log "所有数据清理完成"
            ;;
        *)
            log "无效选择，默认保留所有数据"
            ;;
    esac
}

# 主卸载流程
main() {
    log "=========================================="
    log "OpenList All-in-One 模块卸载向导"
    log "=========================================="
    
    stop_all_services
    clean_binaries
    clean_data
    
    log "=========================================="
    log "卸载完成，请重启设备"
    log "=========================================="
}

main
