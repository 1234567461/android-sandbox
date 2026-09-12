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
| 实时画面 | WebSocket 推流，`adb exec-out` 直读，点击屏幕直接操作设备 |
| 截图 | 单张截图或连续实时推流 |
| 点击/滑动 | 网页点击 → 设备执行，支持鼠标拖拽滑动 |
| 按键 | HOME / BACK / MENU / 电源 / 音量 / 最近任务等 12 个常用键 |
| **键盘直输** | 开关一开，电脑键盘直接发到设备（完整 Android keycode 映射，ESC 退出） |
| 文字输入 | 网页输入文字直接发到设备 |
| **桌面模式** | Android 10+ 自由窗口，以桌面窗口方式启动应用 |
| Shell 命令 | 网页执行 adb shell，实时返回结果 |
| 应用管理 | 安装/卸载/启动/停止应用 |
| 设备信息 | 型号、版本、分辨率、电量 |
| **多设备切换** | 右栏下拉框切换，模拟器自动标识，启动时自动绑定 |
| **Root 管理**（隐藏） | 连点 LOGO 5 次或 `Ctrl+Shift+R` 解锁：查 root 状态、一键 adb root、一键装 Magisk、root shell |

## 架构

```
浏览器 (index.html)
    ↕ WebSocket (实时推流) + HTTP REST API
Python 服务 (server.py)
    ↕ adb 命令
Android 设备 / 模拟器（自动探测绑定）
```

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `ADB_PATH` | `adb` | adb 可执行文件路径 |
| `DEVICE_ID` | 自动检测 | 指定设备 ID（多设备时用），留空自动绑第一个 |
| `HOST` | `0.0.0.0` | 服务监听地址 |
| `PORT` | `7000` | Web 服务端口 |
| `FRAME_INTERVAL` | `1.0` | 实时推流间隔（秒） |
| `BOOT_TIMEOUT` | `180` | 等模拟器启动轮询次数（每次 2 秒） |

## 文件说明

| 文件 | 说明 |
|------|------|
| `sandbox/adb_controller.py` | ADB 封装：截图/点击/滑动/键盘/桌面/Magisk/Root |
| `sandbox/server.py` | Flask + Socket.IO 服务端 + REST API |
| `web/index.html` | Web 控制面板（Glassmorphism 暗色界面） |
| `install.sh` | 交互式中文安装脚本（含模拟器自动安装） |
| `deploy.sh` | 一键部署（安装后自动生成，自动拉模拟器） |
| `Dockerfile` | Docker 镜像（Android SDK + 模拟器 + server） |
| `docker-compose.yml` | 一键 Docker 部署（KVM 透传） |
| `docker-entrypoint.sh` | 容器启动：拉模拟器 → 等就绪 → 启 server |
| `deploy/android-sandbox.service` | systemd 开机自启单元 |
| `deploy/cloudflared-tunnel.md` | 公网访问配置（Cloudflare/Nginx/frp/Tailscale） |

## 前置条件

- Python 3.8+（或 Docker）
- Android 设备开启 USB 调试，或运行 Android 模拟器（AVD/Genymotion，无设备时 `install.sh` 会自动装一个）
- ADB（安装脚本可自动下载）
- **跑模拟器需 `/dev/kvm`**（硬件虚拟化）：本地 BIOS 开 VT-x/SVM，云服务器选支持嵌套虚拟化的实例

---

## Docker 一键部署（推荐上云）

```bash
git clone https://github.com/1234567461/android-sandbox.git
cd android-sandbox
docker compose up -d
# 首次构建会下 Android SDK + 系统镜像（~5GB），耐心等
# 浏览器: http://localhost:7000
```

**前提**：宿主机必须支持 KVM。验证：

```bash
ls -la /dev/kvm                          # 存在即 OK
egrep -c '(vmx|svm)' /proc/cpuinfo        # > 0 即 OK
```

## 在线公网访问（不用本地部署，别人直接打开网址）

见 [deploy/cloudflared-tunnel.md](deploy/cloudflared-tunnel.md)，三种方案：

- **Cloudflare Tunnel**（推荐，免费、免备案、自带 HTTPS，无需公网 IP）
- **Nginx 反代 + certbot**（VPS 有公网 IP 时）
- **Tailscale / frp**（用家里真机当设备时）

## 选什么样的服务器做在线 Demo

| 场景 | 推荐 | 月费 | 能否跑模拟器 |
|------|------|------|---------------|
| **跑模拟器（自带设备）** | Hetzner CX22 / Scaleway DEV1-S | €3~4 | ✅ 原生 KVM |
| 跑模拟器（Oracle 付费 AMD） | Oracle VM.Standard.E5.Flex | 按量 | ✅ 嵌套 KVM |
| 免费层（Oracle ARM A1） | Oracle Always Free | 免费 | ❌ ARM 无嵌套 KVM，只能连真机 |
| 连家里真机（VPS 当网关） | 任意便宜 VPS / Tailscale | 免费~€1 | 不需要 KVM |

**注意**：Oracle Cloud 免费层的 ARM Ampere A1 **不支持嵌套虚拟化**，跑不了 Android 模拟器。要用模拟器需选 Oracle 的 AMD 付费实例（VM.Standard.E5.Flex）或 Hetzner/Scaleway 的 KVM VPS。

## License

MIT
