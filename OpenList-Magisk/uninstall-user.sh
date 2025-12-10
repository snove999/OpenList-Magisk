# shellcheck shell=ash
# uninstall-user.sh for OpenList Magisk/KSU/APatch Module (All-in-One)
# 交互式卸载，允许用户选择是否保留数据

#==== 框架检测：Magisk / KernelSU / APatch ====
detect_framework() {
    if [ -n "$APATCH" ] || [ -n "$APATCH_VER" ]; then
        FRAMEWORK="APatch"
        MODROOT="$MODPATH"
    elif [ -n "$KSU" ] || [ -n "$KERNELSU" ]; then
        FRAMEWORK="KernelSU"
        MODROOT="$MODULEROOT"
    elif [ -n "$MAGISK_VER" ]; then
        FRAMEWORK="Magisk"
        MODROOT="$MODPATH"
    else
        # 通过路径推断
        if [ -d "/data/adb/ap" ]; then
            FRAMEWORK="APatch"
        elif [ -d "/data/adb/ksu" ]; then
            FRAMEWORK="KernelSU"
        else
            FRAMEWORK="Magisk"
        fi
        MODROOT="$MODPATH"
    fi
}
detect_framework
#==== 框架检测结束 ====

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$FRAMEWORK] $1"
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
    
    # OpenList 可能的安装位置
    local openlist_paths="/data/adb/openlist/bin/openlist $MODROOT/bin/openlist $MODROOT/system/bin/openlist"
    for path in $openlist_paths; do
        [ -f "$path" ] && rm -f "$path" && log "已删除: $path"
    done
    
    # 清理模块附带的二进制目录
    [ -d "$MODROOT/bin" ] && rm -rf "$MODROOT/bin" && log "已删除: $MODROOT/bin"
    [ -d "$MODROOT/web" ] && rm -rf "$MODROOT/web" && log "已删除: $MODROOT/web"
    
    # 清理独立安装目录
    [ -d "/data/adb/openlist/bin" ] && {
        rm -rf "/data/adb/openlist/bin"
        log "已删除: /data/adb/openlist/bin"
    }
    
    log "二进制文件清理完成"
}

# 交互式数据清理
clean_data_interactive() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📁 数据清理选项"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "1. 保留所有数据（配置、下载、数据库等）"
    echo "2. 仅删除配置和日志，保留下载文件和数据库"
    echo "3. 删除所有数据（包括下载文件）"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -n "请选择 [1-3]（默认 1）: "
    read -r choice

    # 数据目录列表
    local data_dirs="/data/adb/openlist /sdcard/Android/openlist /storage/emulated/0/Android/openlist"

    case "$choice" in
        1|"")
            log "已选择：保留所有数据"
            echo "✓ 所有数据已保留"
            ;;
        2)
            log "已选择：仅删除配置和日志，保留下载文件"
            for dir in $data_dirs; do
                if [ -d "$dir" ]; then
                    # 删除配置目录
                    [ -d "$dir/config" ] && rm -rf "$dir/config" && log "删除: $dir/config"
                    
                    # 删除 Aria2 会话和日志
                    [ -d "$dir/aria2" ] && rm -rf "$dir/aria2" && log "删除: $dir/aria2"
                    
                    # 删除 Qbittorrent 配置（保留下载数据）
                    [ -d "$dir/qbittorrent/qBittorrent" ] && rm -rf "$dir/qbittorrent/qBittorrent" && log "删除: $dir/qbittorrent/qBittorrent"
                    
                    # 删除日志文件
                    [ -f "$dir/openlist.log" ] && rm -f "$dir/openlist.log" && log "删除: $dir/openlist.log"
                    [ -f "$dir/frpc.log" ] && rm -f "$dir/frpc.log" && log "删除: $dir/frpc.log"
                    [ -f "$dir/service.log" ] && rm -f "$dir/service.log" && log "删除: $dir/service.log"
                    
                    # 删除 PID 文件
                    [ -f "$dir/openlist.pid" ] && rm -f "$dir/openlist.pid"
                fi
            done
            echo "✓ 配置和日志已删除，下载文件和数据库已保留"
            log "配置文件清理完成，下载文件已保留"
            ;;
        3)
            log "已选择：删除所有数据"
            echo ""
            echo "⚠️  警告：这将删除所有数据，包括下载的文件！"
            echo -n "确认删除？[y/N]: "
            read -r confirm
            
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                for dir in $data_dirs; do
                    if [ -d "$dir" ]; then
                        log "删除数据目录: $dir"
                        rm -rf "$dir"
                    fi
                done
                echo "✓ 所有数据已删除"
                log "所有数据清理完成"
            else
                echo "✓ 已取消删除，数据已保留"
                log "用户取消删除操作"
            fi
            ;;
        *)
            log "无效选择，默认保留所有数据"
            echo "✓ 无效选择，已保留所有数据"
            ;;
    esac
}

# 显示数据目录信息
show_data_info() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 检测到的数据目录"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local found=0
    local data_dirs="/data/adb/openlist /sdcard/Android/openlist /storage/emulated/0/Android/openlist"
    
    for dir in $data_dirs; do
        if [ -d "$dir" ]; then
            local size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            echo "📂 $dir ($size)"
            found=1
            
            # 显示子目录信息
            [ -d "$dir/downloads" ] && {
                local dl_size=$(du -sh "$dir/downloads" 2>/dev/null | cut -f1)
                echo "   └─ downloads: $dl_size"
            }
            [ -d "$dir/config" ] && echo "   └─ config: 存在"
            [ -f "$dir/data.db" ] && echo "   └─ data.db: 存在"
        fi
    done
    
    [ $found -eq 0 ] && echo "未检测到数据目录"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 主卸载流程
main() {
    echo ""
    echo "=========================================="
    echo "  OpenList All-in-One 模块卸载向导"
    echo "  框架: $FRAMEWORK"
    echo "=========================================="
    
    stop_all_services
    clean_binaries
    show_data_info
    clean_data_interactive
    
    echo ""
    echo "=========================================="
    echo "✅ 卸载完成"
    echo "=========================================="
    echo "📌 请重启设备以完成清理"
    echo "=========================================="
}

main
