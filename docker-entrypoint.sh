#!/bin/bash
# Docker 容器启动入口
# 1. 检查 /dev/kvm
# 2. 后台拉起 Android 模拟器（-no-window）
# 3. 轮询等 adb device online
# 4. 启动 Flask server
set -e

AVD_NAME="${AVD_NAME:-sandbox_avd}"
PORT="${PORT:-7000}"
HOST="${HOST:-0.0.0.0}"
FRAME_INTERVAL="${FRAME_INTERVAL:-1.0}"
BOOT_TIMEOUT="${BOOT_TIMEOUT:-180}"   # 轮询次数，每轮 sleep 2s

# ---- 1. KVM 检查 ----
if [ -e /dev/kvm ]; then
    echo "[entrypoint] ✅ /dev/kvm 可用，硬件加速"
else
    echo "[entrypoint] ⚠️  无 /dev/kvm，模拟器会非常慢（软渲染）"
    echo "[entrypoint]     宿主机需支持嵌套虚拟化："
    echo "       docker run 时加 --device /dev/kvm 或 --privileged"
    echo "       或用支持 KVM 的 VPS（Hetzner/Scaleway/Oracle AMD 付费实例）"
fi

# ---- 2. 启动模拟器 ----
echo "[entrypoint] 启动模拟器 AVD=$AVD_NAME ..."
nohup emulator -avd "$AVD_NAME" \
    -no-window -no-audio -no-boot-anim -no-snapshot-save \
    -gpu swiftshader_indirect \
    > /tmp/emulator.log 2>&1 &
EMU_PID=$!
echo "[entrypoint] 模拟器 PID=$EMU_PID, 日志 /tmp/emulator.log"

# ---- 3. 等待 adb 就绪 ----
echo -n "[entrypoint] 等待启动"
for i in $(seq 1 "$BOOT_TIMEOUT"); do
    sleep 2
    if adb get-state 2>/dev/null | grep -q device; then
        ONLINE=$(adb devices | awk 'NR>1 && $2=="device"{c++} END{print c+0}')
        if [ "$ONLINE" -ge 1 ]; then
            echo
            echo "[entrypoint] ✅ 模拟器就绪（${i}*2 秒）"
            break
        fi
    fi
    echo -n "."
done

ONLINE=$(adb devices | awk 'NR>1 && $2=="device"{c++} END{print c+0}')
if [ "$ONLINE" -eq 0 ]; then
    echo
    echo "[entrypoint] ⚠️  模拟器未在 ${BOOT_TIMEOUT}*2 秒内就绪，仍启动 server（稍后可连真机）"
    echo "    tail -50 /tmp/emulator.log 看原因"
fi

# 自动绑定到模拟器
EMU_ID=$(adb devices | awk 'NR>1 && $2=="device" && $1 ~ /^emulator/{print $1; exit}')
[ -n "$EMU_ID" ] && export DEVICE_ID="$EMU_ID"

# ---- 4. 启动 server ----
echo "[entrypoint] 启动 Flask server :$PORT （device=${DEVICE_ID:-自动}）"
exec env ADB_PATH=adb DEVICE_ID="${DEVICE_ID:-}" HOST=$HOST PORT=$PORT FRAME_INTERVAL=$FRAME_INTERVAL \
    python3 sandbox/server.py
