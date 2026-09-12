#!/bin/bash
# ============================================================
#   Android Sandbox — Linux 一键安装脚本
#   懂中文就能用，跟着提示输入数字就行
# ============================================================

set -e

# 颜色
红='\033[0;31m'; 绿='\033[0;32m'; 黄='\033[1;33m'
蓝='\033[0;34m'; 紫='\033[0;35m'; 结='\033[0m'

提示() { echo -e "${蓝}$1${结}"; }
成功() { echo -e "${绿}✅ $1${结}"; }
警告() { echo -e "${黄}⚠️  $1${结}"; }
报错() { echo -e "${红}❌ $1${结}"; }
标题() { echo -e "\n${紫}============================================${结}"; echo -e "${紫}  $1${结}"; echo -e "${紫}============================================${结}"; }

仓库地址="https://github.com/1234567461/android-sandbox.git"
安装目录="${1:-$HOME/android-sandbox}"

标题 "Android Sandbox — Linux 一键安装"
echo ""
echo "这个脚本会帮你："
echo "  1. 检查环境（Python、git、adb）"
echo "  2. 选择在线模式还是离线模式"
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
    成功 "Python $PYVER"
else
    报错 "没找到 python3"
    echo "  Ubuntu/Debian: sudo apt install python3 python3-pip"
    echo "  CentOS/RHEL:   sudo yum install python3 python3-pip"
    exit 1
fi

# pip
if python3 -m pip --version &>/dev/null; then
    成功 "pip 已安装"
else
    警告 "pip 没装，尝试自动安装..."
    python3 -m ensurepip --upgrade 2>/dev/null || {
        报错 "pip 安装失败，请手动装"
        exit 1
    }
    成功 "pip 安装完成"
fi

# git
if command -v git &>/dev/null; then
    成功 "git 已安装"
else
    警告 "git 没装，尝试自动安装..."
    if command -v apt &>/dev/null; then
        sudo apt update -qq && sudo apt install -y git
    elif command -v yum &>/dev/null; then
        sudo yum install -y git
    else
        报错 "git 自动安装失败"
        exit 1
    fi
    成功 "git 安装完成"
fi

# adb
ADB_OK=false
if command -v adb &>/dev/null; then
    成功 "adb 已安装"
    ADB_OK=true
else
    警告 "adb 没装"
fi

echo ""

# ============================================================
# 选择模式
# ============================================================
标题 "第一步：选择安装模式"
echo ""
echo "  ${绿}[1]${结} 在线模式（推荐）—— 从 GitHub 下载代码"
echo "      需要联网"
echo ""
echo "  ${黄}[2]${结} 离线模式 —— 本地已有项目文件"
echo "      不需要联网，适合内网"
echo ""
read -p "请输入数字（默认 1）: " 模式
模式="${模式:-1}"

if [ "$模式" = "1" ]; then
    成功 "在线模式"
    if [ -d "$安装目录" ]; then
        提示 "目录已存在，更新代码..."
        cd "$安装目录"
        git pull --rebase 2>/dev/null || true
    else
        提示 "从 GitHub 克隆..."
        git clone "$仓库地址" "$安装目录"
        cd "$安装目录"
    fi
elif [ "$模式" = "2" ]; then
    成功 "离线模式"
    if [ -d "./sandbox" ]; then
        安装目录="$(pwd)"
        提示 "使用当前目录"
    elif [ -d "$安装目录/sandbox" ]; then
        cd "$安装目录"
    else
        报错 "找不到项目文件，请把项目放到 $安装目录 下"
        exit 1
    fi
else
    警告 "不认识，默认在线模式"
    git clone "$仓库地址" "$安装目录" 2>/dev/null || true
    cd "$安装目录"
fi

echo ""

# ============================================================
# 安装 ADB
# ============================================================
if [ "$ADB_OK" = false ]; then
    标题 "第二步：安装 ADB（Android Platform Tools）"
    echo ""
    echo "  ${绿}[1]${结} 自动安装（推荐，会从 Google 下载）"
    echo "  ${绿}[2]${结} 跳过（我手动装，或者用模拟器自带的 adb）"
    echo ""
    read -p "选一个（默认 1）: " 装adb
    装adb="${装adb:-1}"

    if [ "$装adb" = "1" ]; then
        提示 "下载 Android Platform Tools..."
        # 尝试用包管理器装
        if command -v apt &>/dev/null; then
            sudo apt install -y android-tools-adb 2>/dev/null && 成功 "adb 安装完成（apt）"
        fi
        # 如果包管理器没装上，手动下载
        if ! command -v adb &>/dev/null; then
            PT_DIR="$HOME/platform-tools"
            if [ ! -d "$PT_DIR" ]; then
                URL="https://dl.google.com/android/repository/platform-tools-latest-linux.zip"
                TMP="/tmp/ptools.zip"
                提示 "从 Google 下载 Platform Tools..."
                if command -v wget &>/dev/null; then
                    wget -q "$URL" -O "$TMP" || { 警告 "下载失败，请手动安装 adb"; }
                elif command -v curl &>/dev/null; then
                    curl -fsSL "$URL" -o "$TMP" || { 警告 "下载失败，请手动安装 adb"; }
                fi
                if [ -f "$TMP" ]; then
                    提示 "解压..."
                    if command -v unzip &>/dev/null; then
                        unzip -qo "$TMP" -d "$HOME" && 成功 "Platform Tools 安装完成"
                    else
                        警告 "没有 unzip，请手动解压 $TMP"
                    fi
                    rm -f "$TMP"
                fi
            fi
            # 检查
            if [ -x "$PT_DIR/adb" ]; then
                成功 "adb 路径: $PT_DIR/adb"
                ADB_PATH="$PT_DIR/adb"
                # 加到 PATH
                if ! echo "$PATH" | grep -q "platform-tools"; then
                    echo "export PATH=\$HOME/platform-tools:\$PATH" >> "$HOME/.bashrc"
                    提示 "已把 platform-tools 加入 PATH（下次开终端生效）"
                    export PATH="$PT_DIR:$PATH"
                fi
            else
                警告 "adb 没装上，请手动安装"
                echo "  方式1: sudo apt install android-tools-adb"
                echo "  方式2: 从 https://developer.android.com/tools/releases/platform-tools 下载"
                ADB_PATH="adb"
            fi
        else
            ADB_PATH="adb"
        fi
    else
        警告 "跳过 adb 安装"
        echo "  请确保 adb 在 PATH 里，或者后面在 config.sh 里指定路径"
        ADB_PATH="adb"
    fi
    echo ""
else
    ADB_PATH="adb"
    标题 "第二步：ADB 已安装，跳过"
    echo ""
fi

# ============================================================
# 拉起 Android 模拟器（没有真机时的兜底方案）
# ============================================================
标题 "第三步：Android 模拟器（无真机时用）"
echo ""
echo "  如果你没有真机/外部模拟器，沙箱可以在这台机器上拉起一个 Android 模拟器。"
echo ""
echo "  ${绿}[1]${结} 自动装 + 启动模拟器（推荐，无设备时选这个）"
echo "      会装 Android SDK + 创建一个 AVD + 启动"
echo "  ${绿}[2]${结} 跳过（我有真机/已有模拟器）"
echo ""
read -p "选一个（默认 2）: " 起模拟器
起模拟器="${起模拟器:-2}"

AVD_NAME=""
SDK_DIR="${ANDROID_HOME:-$HOME/android-sdk}"
SDK_INSTALLED=false

if [ "$起模拟器" = "1" ]; then
    成功 "进入模拟器安装流程"

    # --- 0. KVM 加速检测（不影响安装，但会影响运行性能） ---
    if [ -e /dev/kvm ]; then
        成功 "检测到 /dev/kvm，可用硬件加速"
    else
        警告 "未检测到 /dev/kvm（可能在容器里或未开虚拟化）"
        echo "  模拟器仍可启动，但会非常慢（软渲染）。"
        echo "  若要硬件加速：BIOS 开 VT-x/SVM，或用支持嵌套虚拟化的主机。"
    fi

    # --- 1. 装 SDK 工具 ---
    SDK_DIR="${ANDROID_HOME:-$HOME/android-sdk}"
    mkdir -p "$SDK_DIR"
    export ANDROID_HOME="$SDK_DIR"
    export ANDROID_SDK_ROOT="$SDK_DIR"

    if [ -x "$SDK_DIR/cmdline-tools/latest/bin/sdkmanager" ]; then
        成功 "cmdline-tools 已存在"
    else
        提示 "下载 Android cmdline-tools..."
        CLT_VER="11076708"
        CLT_ZIP="commandlinetools-linux-${CLT_VER}_latest.zip"
        CLT_URL="https://dl.google.com/android/repository/$CLT_ZIP"
        TMP_ZIP="/tmp/$CLT_ZIP"
        if command -v wget &>/dev/null; then
            wget -q "$CLT_URL" -O "$TMP_ZIP" || 警告 "下载失败"
        elif command -v curl &>/dev/null; then
            curl -fsSL "$CLT_URL" -o "$TMP_ZIP" || 警告 "下载失败"
        else
            报错 "需要 wget 或 curl"
        fi
        if [ -f "$TMP_ZIP" ]; then
            提示 "解压 cmdline-tools..."
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
                成功 "cmdline-tools 安装完成"
            else
                警告 "没有 unzip，请手动解压 $TMP_ZIP 到 $SDK_DIR"
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
        提示 "接受 SDK 许可协议并安装组件（platform-tools / emulator / 系统镜像）..."
        yes 2>/dev/null | "$SDKMAN" --licenses >/dev/null 2>&1 || true
        "$SDKMAN" "platform-tools" "emulator" "platforms;android-34" "system-images;android-34;google_apis;x86_64" 2>&1 | tail -3
        成功 "SDK 组件安装完成"
        SDK_INSTALLED=true

        # --- 3. 创建 AVD ---
        AVD_NAME="sandbox_avd"
        if [ -x "$AVDMAN" ]; then
            提示 "创建 AVD: $AVD_NAME"
            echo "no" | "$AVDMAN" create avd -n "$AVD_NAME" -k "system-images;android-34;google_apis;x86_64" -d pixel_6 2>/dev/null || 警告 "AVD 创建可能已存在或失败"
        else
            警告 "avdmanager 不可用"
        fi

        # 把环境变量写进 deploy.sh 会在后面处理
        成功 "模拟器就绪，AVD 名: $AVD_NAME"
        echo "  启动命令: $EMULATOR_BIN -avd $AVD_NAME -no-window -no-audio -no-boot-anim"
    else
        警告 "sdkmanager 不可用，跳过 SDK 安装"
        echo "  请手动装 Android Studio 或 cmdline-tools"
    fi
else
    警告 "跳过模拟器安装"
fi
echo ""

# ============================================================
# 安装 Python 依赖
# ============================================================
标题 "第四步：安装 Python 依赖"
提示 "安装 Flask + Socket.IO..."
if [ -f "requirements.txt" ]; then
    python3 -m pip install -r requirements.txt -q 2>&1 | tail -1
    成功 "Python 依赖安装完成"
else
    python3 -m pip install flask flask-socketio -q 2>&1 | tail -1
    成功 "Python 依赖安装完成"
fi
echo ""

# ============================================================
# 生成部署脚本
# ============================================================
标题 "第五步：生成部署脚本"

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
# 如果没有在线设备，且安装时配了 AVD，自动拉起模拟器
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

export ADB_PATH DEVICE_ID HOST PORT FRAME_INTERVAL
exec python3 sandbox/server.py
DEPLOY_EOF

chmod +x deploy.sh
成功 "部署脚本已生成: deploy.sh"

# ============================================================
# 完成
# ============================================================
标题 "安装完成！"
echo ""
echo "下一步："
echo "  1. 启动服务："
echo "     bash deploy.sh"
if [ "$SDK_INSTALLED" = "true" ]; then
echo "     （检测到没真机时，会自动拉起模拟器 $AVD_NAME）"
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
