# Android Sandbox

> Linux 上通过网页实时操控 Android 设备/模拟器的沙箱工具
> 适合自动化测试、远程调试、设备管理

## 一键安装

```bash
curl -fsSL https://raw.githubusercontent.com/1234567461/android-sandbox/main/install.sh | bash
```

或者手动克隆：

```bash
git clone https://github.com/1234567461/android-sandbox.git
cd android-sandbox
bash install.sh
```

安装脚本会提示你：
1. 选在线模式还是离线模式
2. 是否自动安装 ADB（Android Platform Tools）
3. 自动装 Python 依赖
4. 生成 deploy.sh 部署脚本

## 一键启动

```bash
bash deploy.sh
```

然后浏览器打开 `http://localhost:7000`，就能看到 Android 屏幕并操控。

## 功能

| 功能 | 说明 |
|------|------|
| 实时画面 | WebSocket 推流，点击屏幕直接操作设备 |
| 截图 | 单张截图或连续实时推流 |
| 点击/滑动 | 网页点击 → 设备执行 |
| 按键 | HOME / BACK / MENU / 电源 / 音量 / 最近任务 |
| 文字输入 | 网页输入文字直接发到设备 |
| Shell 命令 | 网页执行 adb shell，实时返回结果 |
| 应用管理 | 安装/卸载/启动/停止应用 |
| 设备信息 | 型号、版本、分辨率、电量 |
| 多设备 | 列出所有已连接设备，环境变量指定 |

## 架构

```
浏览器 (index.html)
    ↕ WebSocket (实时推流) + HTTP REST API
Python 服务 (server.py)
    ↕ adb 命令
Android 设备 / 模拟器
```

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `ADB_PATH` | `adb` | adb 可执行文件路径 |
| `DEVICE_ID` | 自动检测 | 指定设备 ID（多设备时用） |
| `HOST` | `0.0.0.0` | 服务监听地址 |
| `PORT` | `7000` | Web 服务端口 |
| `FRAME_INTERVAL` | `1.0` | 实时推流间隔（秒） |

## 文件说明

| 文件 | 说明 |
|------|------|
| `sandbox/adb_controller.py` | ADB 封装：截图/点击/滑动/输入/安装/Shell |
| `sandbox/server.py` | Flask + Socket.IO 服务端 |
| `web/index.html` | Web 控制面板（单文件 HTML） |
| `install.sh` | 交互式中文安装脚本 |
| `deploy.sh` | 一键部署（安装后自动生成） |

## 前置条件

- Python 3.8+
- Android 设备开启 USB 调试，或运行 Android 模拟器（AVD/Genymotion）
- ADB（安装脚本可自动下载）

## License

MIT
