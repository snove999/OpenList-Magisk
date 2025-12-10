# shellcheck shell=ash
# customize.sh for OpenList Magisk Module (All-in-One)

#==== 侦探：Magisk or KernelSU ====
if [ -n "$MAGISK_VER" ]; then
    MODROOT="$MODPATH"
elif [ -n "$KSU" ] || [ -n "$KERNELSU" ]; then
    MODROOT="$MODULEROOT"
else
    MODROOT="$MODPATH"
fi
#==== 侦探结束 ====

ui_print ""
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print "  OpenList All-in-One 模块安装"
ui_print "  包含: Aria2 | Qbittorrent | Frpc | Rclone"
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 检测架构
ARCH=$(getprop ro.product.cpu.abi)
ui_print "📱 设备架构: $ARCH"

BINARY_NAME="openlist"

# 按键检测函数
until_key() {
    local eventCode
    while :; do
        eventCode=$(getevent -qlc 1 | awk '{if ($2=="EV_KEY" && $4=="DOWN") {print $3; exit}}')
        case "$eventCode" in
            KEY_VOLUMEUP) printf up; return ;;
            KEY_VOLUMEDOWN) printf down; return ;;
            KEY_POWER) echo -n power; return ;;
        esac
    done
}

# 菜单显示函数
show_binary_menu() {
    ui_print " "
    ui_print "📂 选择 OpenList 安装位置"
    ui_print "1、/data/adb/openlist/bin"
    ui_print "2、模块目录/bin"
    ui_print "3、模块目录/system/bin"
    ui_print "━━━━━━━━━━━━━━━━━━━━━━"
    ui_print "音量+ 确认  |  音量- 切换"
    ui_print "👉 当前选择：选项 $1"
}

show_data_menu() {
    ui_print " "
    ui_print "📁 选择数据目录"
    ui_print "1、/data/adb/openlist"
    ui_print "2、/sdcard/Android/openlist"
    ui_print "━━━━━━━━━━━━━━━━━━━━━━"
    ui_print "音量+ 确认  |  音量- 切换"
    ui_print "👉 当前选择：选项 $1"
}

show_password_menu() {
    ui_print " "
    ui_print "🔐 初始密码设置"
    ui_print "1、不修改（使用随机密码）"
    ui_print "2、设置为 admin"
    ui_print "━━━━━━━━━━━━━━━━━━━━━━"
    ui_print "音量+ 确认  |  音量- 切换"
    ui_print "👉 当前选择：选项 $1"
}

# 选择函数
make_selection() {
    local menu_type="$1"
    local max_options="$2"
    local current=1
    
    case "$menu_type" in
        "binary") show_binary_menu "$current" ;;
        "data") show_data_menu "$current" ;;
        "password") show_password_menu "$current" ;;
    esac
    
    while true; do
        case "$(until_key)" in
            "up")
                ui_print "✅ 已确认选项 $current"
                return $current
                ;;
            "down")
                current=$((current + 1))
                [ $current -gt $max_options ] && current=1
                ui_print "👉 当前选择：选项 $current"
                ;;
        esac
        sleep 0.3
    done
}

# ============== 安装流程 ==============

ui_print "⚙️ 开始配置..."

# 选择二进制安装路径
make_selection "binary" "3"
INSTALL_OPTION=$?

case $INSTALL_OPTION in
    1) 
        BINARY_PATH="/data/adb/openlist/bin"
        BINARY_SERVICE_PATH="/data/adb/openlist/bin/openlist"
        ;;
    2) 
        BINARY_PATH="$MODROOT/bin"
        BINARY_SERVICE_PATH="\$MODDIR/bin/openlist"
        ;;
    3) 
        BINARY_PATH="$MODROOT/system/bin"
        BINARY_SERVICE_PATH="\$MODDIR/system/bin/openlist"
        ;;
esac

mkdir -p "$BINARY_PATH"

# 安装 OpenList 二进制
if echo "$ARCH" | grep -q "arm64"; then
    ui_print "📦 安装 ARM64 版本..."
    if [ -f "$MODROOT/openlist-arm64" ]; then
        mv "$MODROOT/openlist-arm64" "$BINARY_PATH/$BINARY_NAME"
        rm -f "$MODROOT/openlist-arm"
    else
        abort "❌ 未找到 ARM64 版本文件"
    fi
else
    ui_print "📦 安装 ARM 版本..."
    if [ -f "$MODROOT/openlist-arm" ]; then
        mv "$MODROOT/openlist-arm" "$BINARY_PATH/$BINARY_NAME"
        rm -f "$MODROOT/openlist-arm64"
    else
        abort "❌ 未找到 ARM 版本文件"
    fi
fi

chmod 755 "$BINARY_PATH/$BINARY_NAME"
[ "$BINARY_PATH" = "$MODROOT/system/bin" ] && chcon -R u:object_r:system_file:s0 "$BINARY_PATH/$BINARY_NAME"

# 设置附加组件权限
ui_print "📦 配置附加组件..."
if [ -d "$MODROOT/bin" ]; then
    chmod 755 "$MODROOT/bin"/* 2>/dev/null
    ui_print "  ✓ Aria2, Qbittorrent, Frpc, Rclone"
fi
if [ -d "$MODROOT/web" ]; then
    ui_print "  ✓ AriaNg, VueTorrent WebUI"
fi

# 选择数据目录
make_selection "data" "2"
DATA_DIR_OPTION=$?

case $DATA_DIR_OPTION in
    1) DATA_DIR="/data/adb/openlist" ;;
    2) DATA_DIR="/sdcard/Android/openlist" ;;
esac

ui_print " "
ui_print "📢 配置信息"
ui_print "━━━━━━━━━━━━━━━━━━━━━━"
ui_print "数据目录: $DATA_DIR"
ui_print "配置文件: $DATA_DIR/config/"
ui_print "下载目录: $DATA_DIR/downloads/"
ui_print "━━━━━━━━━━━━━━━━━━━━━━"

# 更新配置文件中的占位符
if [ -f "$MODROOT/service.sh" ] && [ -f "$MODROOT/action.sh" ]; then
    # 替换 service.sh
    sed -i "s|__PLACEHOLDER_BINARY_PATH__|$BINARY_SERVICE_PATH|g" "$MODROOT/service.sh"
    sed -i "s|__PLACEHOLDER_DATA_DIR__|$DATA_DIR|g" "$MODROOT/service.sh"
    
    # 替换 action.sh
    sed -i "s|__PLACEHOLDER_BINARY_PATH__|$BINARY_SERVICE_PATH|g" "$MODROOT/action.sh"
    sed -i "s|__PLACEHOLDER_DATA_DIR__|$DATA_DIR|g" "$MODROOT/action.sh"
    
    # 验证替换
    if ! grep -q "__PLACEHOLDER_" "$MODROOT/service.sh" && \
       ! grep -q "__PLACEHOLDER_" "$MODROOT/action.sh"; then
        ui_print "✅ 配置更新成功"
    else
        ui_print "❌ 配置更新失败"
        abort "占位符替换验证失败"
    fi
else
    abort "❌ 未找到 service.sh 或 action.sh"
fi

# 密码设置
make_selection "password" "2"
PASSWORD_OPTION=$?

if [ "$PASSWORD_OPTION" = "2" ]; then
    ui_print "🔄 设置初始密码..."
    
    case $INSTALL_OPTION in
        1) "$BINARY_PATH/openlist" admin set admin --data "$DATA_DIR" ;;
        2) "$MODROOT/bin/openlist" admin set admin --data "$DATA_DIR" ;;
        3) "$MODROOT/system/bin/openlist" admin set admin --data "$DATA_DIR" ;;
    esac
    
    if [ $? -eq 0 ]; then
        mkdir -p "$DATA_DIR"
        echo "admin" > "$DATA_DIR/初始密码.txt"
        ui_print "✅ 密码已设为: admin"
    else
        ui_print "⚠️ 密码设置失败，将使用随机密码"
    fi
else
    ui_print "✓ 跳过密码设置"
fi

# 完成
ui_print ""
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print "✨ 安装完成"
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print "📍 OpenList: http://IP:5244"
ui_print "📍 Aria2 RPC: http://IP:6800 (密钥: openlist)"
ui_print "📍 Qbittorrent: http://IP:8080"
ui_print ""
ui_print "⚙️ 服务控制: $DATA_DIR/config/services.conf"
ui_print "👋 请重启设备启动服务"
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
