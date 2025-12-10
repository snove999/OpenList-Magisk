## 🤖 Assistant

# OpenList All-in-One Magisk/KernelSU 模块

[![Release](https://img.shields.io/github/v/release/snove999/OpenList-Magisk)](https://github.com/snove999/OpenList-Magisk/releases)
[![License](https://img.shields.io/github/license/snove999/OpenList-Magisk)](https://github.com/snove999/OpenList-Magisk/blob/main/LICENSE)

OpenList All-in-One 模块将 [OpenList](https://github.com/OpenListTeam/OpenList) 文件服务器及多款实用工具集成到 Android 系统中，通过 Magisk 或 KernelSU 以系统化方式运行，支持 ARM 和 ARM64 架构。

## ✨ 包含组件

| 组件 | 说明 | 默认端口 |
|------|------|---------|
| **OpenList** | 多存储聚合文件管理器 | 5244 |
| **Aria2** | 高速下载器 (支持 HTTP/BT/磁力) | 6800 (RPC) |
| **Qbittorrent** | BT/PT 下载客户端 | 8080 (WebUI) |
| **Frpc** | 内网穿透客户端 | - |
| **Rclone** | 云存储同步工具 (按需调用) | - |
| **AriaNg** | Aria2 Web 管理界面 | - |
| **VueTorrent** | Qbittorrent 现代化 WebUI | - |

## 功能亮点

- **🔧 模块化服务管理**：通过配置文件灵活启用/禁用各服务
- **📦 一键安装**：自动下载并配置所有组件
- **🎨 现代化 WebUI**：Qbittorrent 默认使用 VueTorrent 界面
- **🔐 安全配置**：Aria2 RPC 默认启用密钥认证
- **📱 双框架支持**：同时兼容 Magisk 和 KernelSU
- **🌐 智能网络适配**：自动识别 WiFi/移动网络 IP
- **📊 状态监控**：模块描述实时显示各服务运行状态

## 系统要求

- Android 设备（ARM64 架构，部分组件仅支持 ARM64）
- Magisk v20.4+ 或 KernelSU
- Root 权限
- 约 150MB 存储空间

## 安装步骤

### 1. 下载模块
从 [GitHub Releases](https://github.com/snove999/OpenList-Magisk/releases) 下载最新版本 `openlist-magisk-vX.X.X.zip`

### 2. 安装配置
1. 打开 Magisk/KernelSU 管理器
2. 选择「从本地安装」
3. 按提示配置：
 - **二进制安装位置**：推荐选择 `/data/adb/openlist/bin`
 - **数据目录**：推荐选择 `/data/adb/openlist`
 - **初始密码**：可选设置为 `admin`

### 3. 完成安装
- 等待安装完成后重启设备
- 首次启动会自动生成默认配置文件

## 使用说明

### 服务控制

**配置文件位置**：`<数据目录>/config/services.conf`

```bash
# 设置为 true 启用，false 禁用
openlist=true      # OpenList 文件服务器
aria2=false        # Aria2 下载器
qbittorrent=false  # Qbittorrent BT客户端
frpc=false         # Frpc 内网穿透
```

修改后重启设备或通过 Magisk「动作」按钮重启服务生效。

### 访问地址

| 服务 | 地址 | 默认凭据 |
|------|------|---------|
| OpenList | `http://<IP>:5244` | 见 `初始密码.txt` |
| Aria2 (AriaNg) | `http://<IP>:5244/ariang` | RPC密钥: `openlist` |
| Qbittorrent | `http://<IP>:8080` | admin / adminadmin |

> **提示**：设备 IP 地址显示在 Magisk 模块描述中

### 配置文件说明

所有配置文件位于 `<数据目录>/config/` 目录：

| 文件 | 说明 |
|------|------|
| `services.conf` | 服务启用控制 |
| `aria2.conf` | Aria2 配置 (RPC端口、下载目录等) |
| `frpc.toml` | Frpc 配置 (需手动填写服务器信息) |

### 目录结构

```
<数据目录>/
├── config/
│   ├── services.conf    # 服务开关
│   ├── aria2.conf       # Aria2 配置
│   └── frpc.toml        # Frpc 配置
├── downloads/           # 统一下载目录
├── aria2/
│   ├── aria2.session    # Aria2 会话
│   └── aria2.log        # Aria2 日志
├── qbittorrent/         # Qbittorrent 数据
├── openlist.log         # OpenList 日志
└── 初始密码.txt          # OpenList 初始密码
```

## 高级配置

### Aria2 配置
默认配置文件 `aria2.conf` 已优化，关键参数：
- **RPC 密钥**：`openlist`（可在配置文件中修改 `rpc-secret`）
- **下载目录**：`<数据目录>/downloads`
- **最大并发**：5 个任务

### Qbittorrent 配置
- WebUI 已默认启用 VueTorrent 主题
- 首次登录用户名 `admin`，密码 `adminadmin`
- **强烈建议首次登录后修改密码**

### Frpc 内网穿透
1. 编辑 `<数据目录>/config/frpc.toml`
2. 填写你的 Frp 服务器信息：
```toml
   serverAddr = "your.frp.server.com"
   serverPort = 7000
   auth.token = "your_token"
   ```
3. 在 `services.conf` 中启用：`frpc=true`
4. 重启服务

### Rclone 使用
Rclone 不作为服务运行，可通过命令行或 OpenList 调用：
```bash
# 二进制位置
/data/adb/modules/<模块ID>/bin/rclone

# 配置文件（需手动创建）
<数据目录>/config/rclone.conf
```

## 故障排除

### 查看日志
```bash
# 模块主日志
cat /data/adb/modules/openlist/service.log

# OpenList 日志
cat <数据目录>/openlist.log

# Aria2 日志
cat <数据目录>/aria2/aria2.log
```

### 常见问题

**Q: 服务无法启动**
- 检查 `services.conf` 是否正确配置
- 查看 `service.log` 获取错误信息
- 确认二进制文件有执行权限

**Q: 无法访问 WebUI**
- 确认设备与访问端在同一网络
- 检查对应服务是否已启用并运行
- 尝试使用 `localhost` 或 `127.0.0.1`（仅限设备本地）

**Q: Aria2 RPC 连接失败**
- 默认密钥为 `openlist`，在 AriaNg 设置中填写
- 检查端口 6800 是否被占用

**Q: Frpc 启动失败**
- 确认已正确配置服务器信息
- 检查 `frpc.toml` 语法是否正确
- 查看 `<数据目录>/frpc.log`

### 手动操作
```bash
# 查看运行中的服务
pgrep -fa "openlist|aria2c|qbittorrent|frpc"

# 停止所有服务
pkill -f openlist; pkill -f aria2c; pkill -f qbittorrent-nox; pkill -f frpc

# 手动启动服务
sh /data/adb/modules/openlist/service.sh
```

## 更新说明

- 更新时会保留现有配置和数据
- 新版本可能包含新的默认配置项，建议检查 `services.conf`
- 通过 Magisk 更新检查获取最新版本

## 卸载说明

### 通过 Magisk 卸载
- 完全卸载：自动停止服务并清理所有数据
- 使用 `uninstall-user.sh` 可选择保留下载文件

### 数据保留
卸载后以下目录可能保留（取决于选择）：
- `/data/adb/openlist/downloads/`
- `/sdcard/Android/openlist/downloads/`

## 致谢

- [OpenList](https://github.com/OpenListTeam/OpenList) - 核心文件服务器
- [Aria2](https://github.com/aria2/aria2) - 下载引擎
- [qBittorrent](https://github.com/qbittorrent/qBittorrent) - BT 客户端
- [frp](https://github.com/fatedier/frp) - 内网穿透
- [Rclone](https://github.com/rclone/rclone) - 云存储工具
- [AriaNg](https://github.com/mayswind/AriaNg) - Aria2 WebUI
- [VueTorrent](https://github.com/VueTorrent/VueTorrent) - qBittorrent WebUI

## 贡献

- 欢迎提交 Issue 和 Pull Request
- 问题反馈：[GitHub Issues](https://github.com/snove999/OpenList-Magisk/issues)

## 许可证

本项目基于 [MIT 许可证](LICENSE) 发布。
