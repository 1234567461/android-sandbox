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
# 安装 Python 依赖
# ============================================================
标题 "第三步：安装 Python 依赖"
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
标题 "第四步：生成部署脚本"

cat > deploy.sh << DEPLOY_EOF
#!/bin/bash
# Android Sandbox 一键部署脚本（自动生成）
# 用法: bash deploy.sh

set -e
cd "\$(cd "\$(dirname "\$0")" && pwd)"

# 读取配置
ADB_PATH="${ADB_PATH}"
DEVICE_ID="\${DEVICE_ID:-}"
HOST="\${HOST:-0.0.0.0}"
PORT="\${PORT:-7000}"
FRAME_INTERVAL="\${FRAME_INTERVAL:-1.0}"

echo ""
echo "============================================"
echo "  Android Sandbox 部署"
echo "============================================"
echo "  ADB:    \$ADB_PATH"
echo "  设备:   \${DEVICE_ID:-自动检测}"
echo "  地址:   http://localhost:\$PORT"
echo "  推流:   每 \${FRAME_INTERVAL}秒一帧"
echo "============================================"
echo ""

# 检查 adb
if ! command -v "\$ADB_PATH" &>/dev/null 2>&1; then
    if [ -x "\$HOME/platform-tools/adb" ]; then
        ADB_PATH="\$HOME/platform-tools/adb"
    else
        echo "❌ 找不到 adb，请先运行 install.sh 或手动安装"
        exit 1
    fi
fi

# 检查设备
echo "已连接的设备："
"\$ADB_PATH" devices
echo ""

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
echo "  1. 确保 Android 设备已用 USB 连接（开了 USB 调试）"
echo "     或者启动了 Android 模拟器（比如 AVD）"
echo "  2. 启动服务："
echo "     bash deploy.sh"
echo "  3. 打开浏览器："
echo "     http://localhost:7000"
echo ""
echo "如果有多台设备，设置环境变量指定："
echo "  DEVICE_ID=设备ID bash deploy.sh"
echo ""
echo "调整截图频率（秒）："
echo "  FRAME_INTERVAL=0.5 bash deploy.sh"
echo ""
