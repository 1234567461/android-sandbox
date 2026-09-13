#!/bin/bash
# ============================================================
#   Android Sandbox — Linux 一键安装脚本
#   懂中文就能用，跟着提示输入数字就行
# ============================================================

set -e

# 颜色
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; PURPLE='\033[0;35m'; RESET='\033[0m'

say_info() { echo -e "${BLUE}$1${RESET}"; }
say_ok() { echo -e "${GREEN}✅ $1${RESET}"; }
say_warn() { echo -e "${YELLOW}⚠️  $1${RESET}"; }
say_err() { echo -e "${RED}❌ $1${RESET}"; }
say_title() { echo -e "\n${PURPLE}============================================${RESET}"; echo -e "${PURPLE}  $1${RESET}"; echo -e "${PURPLE}============================================${RESET}"; }

REPO_URL="https://github.com/1234567461/android-sandbox.git"
INSTALL_DIR="${1:-$HOME/android-sandbox}"

say_title "Android Sandbox — Linux 一键安装"
echo ""
echo "这个脚本会帮你："
echo "  1. 检查环境（Python、git、adb）"
echo "  2. 选择在线MODE还是离线MODE"
echo "  3. 选择是否自动安装 Android Platform Tools（包含 adb）"
echo "  4. 自动安装 Python 依赖"
echo "  5. 生成 deploy.sh 部署脚本"
echo ""
echo "全程跟着提示走，输入数字回车就行。"
echo ""

# ============================================================
# 环境检查
# ============================================================
echo "--- 环境检查 ---"

# Python
if command -v python3 &>/dev/null; then
    PYVER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    say_ok "Python $PYVER"
else
    say_err "没找到 python3"
    echo "  Ubuntu/Debian: sudo apt install python3 python3-pip"
    echo "  CentOS/RHEL:   sudo yum install python3 python3-pip"
    exit 1
fi

# pip
if python3 -m pip --version &>/dev/null; then
    say_ok "pip 已安装"
else
    say_warn "pip 没装，尝试自动安装..."
    python3 -m ensurepip --upgrade 2>/dev/null || {
        say_err "pip 安装失败，请手动装"
        exit 1
    }
    say_ok "pip 安装完成"
fi

# git
if command -v git &>/dev/null; then
    say_ok "git 已安装"
else
    say_warn "git 没装，尝试自动安装..."
    if command -v apt &>/dev/null; then
        sudo apt update -qq && sudo apt install -y git
    elif command -v yum &>/dev/null; then
        sudo yum install -y git
    else
        say_err "git 自动安装失败"
        exit 1
    fi
    say_ok "git 安装完成"
fi

# adb
ADB_OK=false
if command -v adb &>/dev/null; then
    say_ok "adb 已安装"
    ADB_OK=true
else
    say_warn "adb 没装"
fi

echo ""

# ============================================================
# 选择MODE
# ============================================================
say_title "第一步：选择安装MODE"
echo ""
echo "  ${GREEN}[1]${RESET} 在线MODE（推荐）—— 从 GitHub 下载代码"
echo "      需要联网"
echo ""
echo "  ${YELLOW}[2]${RESET} 离线MODE —— 本地已有项目文件"
echo "      不需要联网，适合内网"
echo ""
read -p "请输入数字（默认 1）: " MODE
MODE="${MODE:-1}"

if [ "$MODE" = "1" ]; then
    say_ok "在线MODE"
    if [ -d "$INSTALL_DIR" ]; then
        say_info "目录已存在，更新代码..."
        cd "$INSTALL_DIR"
        git pull --rebase 2>/dev/null || true
    else
        say_info "从 GitHub 克隆..."
        git clone "$REPO_URL" "$INSTALL_DIR"
        cd "$INSTALL_DIR"
    fi
elif [ "$MODE" = "2" ]; then
    say_ok "离线MODE"
    if [ -d "./sandbox" ]; then
        INSTALL_DIR="$(pwd)"
        say_info "使用当前目录"
    elif [ -d "$INSTALL_DIR/sandbox" ]; then
        cd "$INSTALL_DIR"
    else
        say_err "找不到项目文件，请把项目放到 $INSTALL_DIR 下"
        exit 1
    fi
else
    say_warn "不认识，默认在线MODE"
    git clone "$REPO_URL" "$INSTALL_DIR" 2>/dev/null || true
    cd "$INSTALL_DIR"
fi

echo ""

# ============================================================
# 安装 ADB
# ============================================================
if [ "$ADB_OK" = false ]; then
    say_title "第二步：安装 ADB（Android Platform Tools）"
    echo ""
    echo "  ${GREEN}[1]${RESET} 自动安装（推荐，会从 Google 下载）"
    echo "  ${GREEN}[2]${RESET} 跳过（我手动装，或者用模拟器自带的 adb）"
    echo ""
    read -p "选一个（默认 1）: " 装adb
    装adb="${装adb:-1}"

    if [ "$装adb" = "1" ]; then
        say_info "下载 Android Platform Tools..."
        # 尝试用包管理器装
        if command -v apt &>/dev/null; then
            sudo apt install -y android-tools-adb 2>/dev/null && say_ok "adb 安装完成（apt）"
        fi
        # 如果包管理器没装上，手动下载
        if ! command -v adb &>/dev/null; then
            PT_DIR="$HOME/platform-tools"
            if [ ! -d "$PT_DIR" ]; then
                URL="https://dl.google.com/android/repository/platform-tools-latest-linux.zip"
                TMP="/tmp/ptools.zip"
                say_info "从 Google 下载 Platform Tools..."
                if command -v wget &>/dev/null; then
                    wget -q "$URL" -O "$TMP" || { say_warn "下载失败，请手动安装 adb"; }
                elif command -v curl &>/dev/null; then
                    curl -fsSL "$URL" -o "$TMP" || { say_warn "下载失败，请手动安装 adb"; }
                fi
                if [ -f "$TMP" ]; then
                    say_info "解压..."
                    if command -v unzip &>/dev/null; then
                        unzip -qo "$TMP" -d "$HOME" && say_ok "Platform Tools 安装完成"
                    else
                        say_warn "没有 unzip，请手动解压 $TMP"
                    fi
                    rm -f "$TMP"
                fi
            fi
            # 检查
            if [ -x "$PT_DIR/adb" ]; then
                say_ok "adb 路径: $PT_DIR/adb"
                ADB_PATH="$PT_DIR/adb"
                # 加到 PATH
                if ! echo "$PATH" | grep -q "platform-tools"; then
                    echo "export PATH=\$HOME/platform-tools:\$PATH" >> "$HOME/.bashrc"
                    say_info "已把 platform-tools 加入 PATH（下次开终端生效）"
                    export PATH="$PT_DIR:$PATH"
                fi
            else
                say_warn "adb 没装上，请手动安装"
                echo "  方式1: sudo apt install android-tools-adb"
                echo "  方式2: 从 https://developer.android.com/tools/releases/platform-tools 下载"
                ADB_PATH="adb"
            fi
        else
            ADB_PATH="adb"
        fi
    else
        say_warn "跳过 adb 安装"
        echo "  请确保 adb 在 PATH 里，或者后面在 config.sh 里指定路径"
        ADB_PATH="adb"
    fi
    echo ""
else
    ADB_PATH="adb"
    say_title "第二步：ADB 已安装，跳过"
    echo ""
fi

# ============================================================
# 拉起 Android 模拟器（没有真机时的兜底方案）
# ============================================================
say_title "第三步：Android 模拟器（无真机时用）"
echo ""
echo "  如果你没有真机/外部模拟器，沙箱可以在这台机器上拉起一个 Android 模拟器。"
echo ""
echo "  ${GREEN}[1]${RESET} 自动装 + 启动模拟器（推荐，无设备时选这个）"
echo "      会装 Android SDK + 创建一个 AVD + 启动"
echo "  ${GREEN}[2]${RESET} 跳过（我有真机/已有模拟器）"
echo ""
read -p "选一个（默认 2）: " START_EMU
START_EMU="${START_EMU:-2}"

AVD_NAME=""
SDK_DIR="${ANDROID_HOME:-$HOME/android-sdk}"
SDK_INSTALLED=false

if [ "$START_EMU" = "1" ]; then
    say_ok "进入模拟器安装流程"

    # --- 0. KVM 加速检测（不影响安装，但会影响运行性能） ---
    if [ -e /dev/kvm ]; then
        say_ok "检测到 /dev/kvm，可用硬件加速"
    else
        say_warn "未检测到 /dev/kvm（可能在容器里或未开虚拟化）"
        echo "  模拟器仍可启动，但会非常慢（软渲染）。"
        echo "  若要硬件加速：BIOS 开 VT-x/SVM，或用支持嵌套虚拟化的主机。"
    fi

    # --- 1. 装 SDK 工具 ---
    SDK_DIR="${ANDROID_HOME:-$HOME/android-sdk}"
    mkdir -p "$SDK_DIR"
    export ANDROID_HOME="$SDK_DIR"
    export ANDROID_SDK_ROOT="$SDK_DIR"

    if [ -x "$SDK_DIR/cmdline-tools/latest/bin/sdkmanager" ]; then
        say_ok "cmdline-tools 已存在"
    else
        say_info "下载 Android cmdline-tools..."
        CLT_VER="11076708"
        CLT_ZIP="commandlinetools-linux-${CLT_VER}_latest.zip"
        CLT_URL="https://dl.google.com/android/repository/$CLT_ZIP"
        TMP_ZIP="/tmp/$CLT_ZIP"
        if command -v wget &>/dev/null; then
            wget -q "$CLT_URL" -O "$TMP_ZIP" || say_warn "下载失败"
        elif command -v curl &>/dev/null; then
            curl -fsSL "$CLT_URL" -o "$TMP_ZIP" || say_warn "下载失败"
        else
            say_err "需要 wget 或 curl"
        fi
        if [ -f "$TMP_ZIP" ]; then
            say_info "解压 cmdline-tools..."
            if command -v unzip &>/dev/null; then
                unzip -qo "$TMP_ZIP" -d "$SDK_DIR"
                # cmdline-tools 解压出来是 cmdline-tools/bin，需规范成 latest 子目录
                mkdir -p "$SDK_DIR/cmdline-tools"
                if [ -d "$SDK_DIR/cmdline-tools/bin" ] && [ ! -d "$SDK_DIR/cmdline-tools/latest" ]; then
                    mv "$SDK_DIR/cmdline-tools" "$SDK_DIR/cmdline-tools-tmp"
                    mkdir -p "$SDK_DIR/cmdline-tools/latest"
                    mv "$SDK_DIR/cmdline-tools-tmp"/* "$SDK_DIR/cmdline-tools/latest/"
                    rm -rf "$SDK_DIR/cmdline-tools-tmp"
                fi
                say_ok "cmdline-tools 安装完成"
            else
                say_warn "没有 unzip，请手动解压 $TMP_ZIP 到 $SDK_DIR"
            fi
            rm -f "$TMP_ZIP"
        fi
    fi

    SDKMAN="$SDK_DIR/cmdline-tools/latest/bin/sdkmanager"
    AVDMAN="$SDK_DIR/cmdline-tools/latest/bin/avdmanager"
    EMULATOR_BIN="$SDK_DIR/emulator/emulator"

    if [ -x "$SDKMAN" ]; then
        export PATH="$SDK_DIR/cmdline-tools/latest/bin:$SDK_DIR/platform-tools:$SDK_DIR/emulator:$PATH"
        ADB_PATH="$SDK_DIR/platform-tools/adb"

        # --- 2. 装平台 + 系统镜像 + 模拟器 ---
        say_info "接受 SDK 许可协议并安装组件（platform-tools / emulator / 系统镜像）..."
        yes 2>/dev/null | "$SDKMAN" --licenses >/dev/null 2>&1 || true
        "$SDKMAN" "platform-tools" "emulator" "platforms;android-34" "system-images;android-34;google_apis;x86_64" 2>&1 | tail -3
        say_ok "SDK 组件安装完成"
        SDK_INSTALLED=true

        # --- 3. 创建 AVD ---
        AVD_NAME="sandbox_avd"
        if [ -x "$AVDMAN" ]; then
            say_info "创建 AVD: $AVD_NAME"
            echo "no" | "$AVDMAN" create avd -n "$AVD_NAME" -k "system-images;android-34;google_apis;x86_64" -d pixel_6 2>/dev/null || say_warn "AVD 创建可能已存在或失败"
        else
            say_warn "avdmanager 不可用"
        fi

        # 把环境变量写进 deploy.sh 会在后面处理
        say_ok "模拟器就绪，AVD 名: $AVD_NAME"
        echo "  启动命令: $EMULATOR_BIN -avd $AVD_NAME -no-window -no-audio -no-boot-anim"
    else
        say_warn "sdkmanager 不可用，跳过 SDK 安装"
        echo "  请手动装 Android Studio 或 cmdline-tools"
    fi
else
    say_warn "跳过模拟器安装"
fi
echo ""

# ============================================================
# 安装 Python 依赖
# ============================================================
say_title "第四步：安装 Python 依赖"
say_info "安装 Flask + Socket.IO..."
if [ -f "requirements.txt" ]; then
    python3 -m pip install -r requirements.txt -q 2>&1 | tail -1
    say_ok "Python 依赖安装完成"
else
    python3 -m pip install flask flask-socketio -q 2>&1 | tail -1
    say_ok "Python 依赖安装完成"
fi
echo ""

# ============================================================
# 生成部署脚本
# ============================================================
say_title "第五步：生成部署脚本"

cat > deploy.sh << DEPLOY_EOF
#!/bin/bash
# Android Sandbox 一键部署脚本（自动生成）
# 用法: bash deploy.sh

set -e
cd "\$(cd "\$(dirname "\$0")" && pwd)"

# 读取配置
ADB_PATH="${ADB_PATH}"
SDK_DIR="${SDK_DIR}"
AVD_NAME="${AVD_NAME}"
EMULATOR_BIN="${SDK_DIR}/emulator/emulator"
DEVICE_ID="\${DEVICE_ID:-}"
HOST="\${HOST:-0.0.0.0}"
PORT="\${PORT:-7000}"
FRAME_INTERVAL="\${FRAME_INTERVAL:-1.0}"
BOOT_TIMEOUT="\${BOOT_TIMEOUT:-180}"   # 等模拟器启动最长秒数

export ANDROID_HOME="\${ANDROID_HOME:-$SDK_DIR}"
export ANDROID_SDK_ROOT="\$ANDROID_HOME"

echo ""
echo "============================================"
echo "  Android Sandbox 部署"
echo "============================================"
echo "  ADB:     \$ADB_PATH"
echo "  SDK:     \$ANDROID_HOME"
if [ -n "\$AVD_NAME" ] && [ -x "\$EMULATOR_BIN" ]; then
echo "  模拟器: \$EMULATOR_BIN"
echo "  AVD:    \$AVD_NAME"
fi
echo "  设备:    \${DEVICE_ID:-自动检测}"
echo "  地址:    http://localhost:\$PORT"
echo "  推流:    每 \${FRAME_INTERVAL}秒一帧"
echo "============================================"
echo ""

# 检查 adb
if ! command -v "\$ADB_PATH" &>/dev/null 2>&1; then
    if [ -x "\$HOME/platform-tools/adb" ]; then
        ADB_PATH="\$HOME/platform-tools/adb"
    elif [ -x "\$ANDROID_HOME/platform-tools/adb" ]; then
        ADB_PATH="\$ANDROID_HOME/platform-tools/adb"
    else
        echo "❌ 找不到 adb，请先运行 install.sh 或手动安装"
        exit 1
    fi
fi

# 数一下当前有没有真机/已启动的模拟器
count_online() {
    "\$ADB_PATH" devices 2>/dev/null | awk 'NR>1 && \$2=="device"{c++} END{print c+0}'
}
ONLINE=\$(count_online)
echo "当前在线设备: \$ONLINE 台"
"\$ADB_PATH" devices
echo ""

# ============================================================
# 如果没有在线设备，且安装时配了 AVD，自动拉START_EMU
# ============================================================
if [ "\$ONLINE" -eq 0 ] && [ -n "\$AVD_NAME" ] && [ -x "\$EMULATOR_BIN" ]; then
    echo "没有在线设备，自动启动本地模拟器..."
    # -no-window 无界面（跑在服务器上推荐），-no-boot-anim 加快启动
    nohup "\$EMULATOR_BIN" -avd "\$AVD_NAME" \\
        -no-window -no-audio -no-boot-anim -no-snapshot-save \\
        > /tmp/sandbox_emulator.log 2>&1 &
    EMU_PID=\$!
    echo "模拟器进程 PID=\$EMU_PID，日志: /tmp/sandbox_emulator.log"

    echo -n "等待模拟器启动"
    for i in \$(seq 1 "\$BOOT_TIMEOUT"); do
        sleep 2
        if "\$ADB_PATH" get-state 2>/dev/null | grep -q device; then
            ONLINE=\$(count_online)
            if [ "\$ONLINE" -ge 1 ]; then
                echo
                echo "✅ 模拟器已就绪（\${i}*2 秒）"
                break
            fi
        fi
        echo -n "."
    done

    ONLINE=\$(count_online)
    if [ "\$ONLINE" -eq 0 ]; then
        echo
        echo "⚠️  模拟器在 \${BOOT_TIMEOUT}*2 秒内没起来"
        echo "    查看日志: tail -50 /tmp/sandbox_emulator.log"
        echo "    可能原因: 无 /dev/kvm（容器内常见）、镜像没下完整、内存不足"
        echo "    现在直接进入 Web 控制台，连上设备后会自动识别"
    fi
elif [ "\$ONLINE" -eq 0 ]; then
    echo "⚠️  没有在线设备，也没配模拟器"
    echo "    请连真机（开 USB 调试）或重跑 install.sh 选模拟器"
fi

# ============================================================
# 抓当前选中的设备 id（模拟器优先，没有就取第一个 online）
# 这样 server.py 启动时直接绑定到这台设备，避免多设备时报错
# ============================================================
pick_device() {
    "\$ADB_PATH" devices 2>/dev/null | awk 'NR>1 && \$2=="device"{print \$1}' | head -1
}
# 如果启动时配了 AVD（说明走的是模拟器路径），优先选 emulator-xxxx
if [ -n "\$AVD_NAME" ]; then
    EMU_ID=\$("\$ADB_PATH" devices 2>/dev/null | awk 'NR>1 && \$2=="device" && \$1 ~ /^emulator/{print \$1; exit}')
    [ -n "\$EMU_ID" ] && PICKED="\$EMU_ID" || PICKED=\$(pick_device)
else
    PICKED=\$(pick_device)
fi

if [ -n "\$PICKED" ]; then
    echo "✅ 绑定设备: \$PICKED"
    # 如果用户没显式设 DEVICE_ID，就用我们自动抓的
    [ -z "\$DEVICE_ID" ] && DEVICE_ID="\$PICKED"
else
    echo "⚠️  暂无在线设备，server 会以自动检测MODE启动"
fi

export ADB_PATH DEVICE_ID HOST PORT FRAME_INTERVAL
exec python3 sandbox/server.py
DEPLOY_EOF

chmod +x deploy.sh
say_ok "部署脚本已生成: deploy.sh"

# ============================================================
# 完成
# ============================================================
say_title "安装完成！"
echo ""
echo "下一步："
echo "  1. 启动服务："
echo "     bash deploy.sh"
if [ "$SDK_INSTALLED" = "true" ]; then
echo "     （检测到没真机时，会自动拉START_EMU $AVD_NAME）"
fi
echo "  2. 打开浏览器："
echo "     http://localhost:7000"
echo ""
echo "如果有多台设备，设置环境变量指定："
echo "  DEVICE_ID=设备ID bash deploy.sh"
echo ""
echo "调整截图频率（秒）："
echo "  FRAME_INTERVAL=0.5 bash deploy.sh"
echo ""
echo "模拟器启动等待超时（秒）："
echo "  BOOT_TIMEOUT=300 bash deploy.sh"
echo ""
