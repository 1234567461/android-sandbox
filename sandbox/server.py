"""
Android Sandbox 服务端
功能: WebSocket 实时推流截图 + HTTP REST API 控制设备
依赖: pip install flask flask-socketio
"""

import os
import sys
import time
import threading
import base64
from io import BytesIO

from flask import Flask, request, jsonify, send_file
from flask_socketio import SocketIO, emit

# 导入 ADB 控制器
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from adb_controller import ADBController

# ============================================================
# 初始化
# ============================================================

app = Flask(__name__)
app.config["SECRET_KEY"] = "android-sandbox-secret"
socketio = SocketIO(app, cors_allowed_origins="*", async_mode="threading")

# 全局 ADB 控制器实例
ADB_PATH = os.environ.get("ADB_PATH", "adb")
DEVICE_ID = os.environ.get("DEVICE_ID", "")
FRAME_INTERVAL = float(os.environ.get("FRAME_INTERVAL", "1.0"))  # 截图间隔（秒）

adb = ADBController(device_id=DEVICE_ID, adb_path=ADB_PATH)

# 实时推流控制
streaming = False
stream_thread = None

# ============================================================
# HTTP REST API
# ============================================================

@app.route("/")
def index():
    """返回 Web 控制面板"""
    return send_file(os.path.join(os.path.dirname(__file__), "..", "web", "index.html"))

@app.route("/api/devices")
def api_devices():
    """列出所有已连接设备"""
    return jsonify(adb.devices())

@app.route("/api/device/info")
def api_device_info():
    """获取设备信息"""
    return jsonify(adb.get_device_info())

@app.route("/api/apps")
def api_apps():
    """列出已安装的第三方应用"""
    return jsonify(adb.get_installed_apps())

@app.route("/api/screenshot")
def api_screenshot():
    """获取单张截图"""
    try:
        data = adb.screenshot()
        return send_file(BytesIO(data), mimetype="image/png")
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/tap", methods=["POST"])
def api_tap():
    """点击屏幕"""
    x = int(request.json.get("x", 0))
    y = int(request.json.get("y", 0))
    adb.tap(x, y)
    return jsonify({"ok": True})

@app.route("/api/swipe", methods=["POST"])
def api_swipe():
    """滑动"""
    data = request.json
    adb.swipe(
        int(data.get("x1", 0)),
        int(data.get("y1", 0)),
        int(data.get("x2", 0)),
        int(data.get("y2", 0)),
        int(data.get("duration", 300)),
    )
    return jsonify({"ok": True})

@app.route("/api/input", methods=["POST"])
def api_input():
    """输入文字"""
    text = request.json.get("text", "")
    adb.input_text(text)
    return jsonify({"ok": True})

@app.route("/api/key", methods=["POST"])
def api_key():
    """按键"""
    keycode = request.json.get("keycode", "")
    adb.key(keycode)
    return jsonify({"ok": True})

@app.route("/api/install", methods=["POST"])
def api_install():
    """安装 APK"""
    apk_path = request.json.get("path", "")
    result = adb.install(apk_path)
    return jsonify({"result": result})

@app.route("/api/uninstall", methods=["POST"])
def api_uninstall():
    """卸载应用"""
    package = request.json.get("package", "")
    result = adb.uninstall(package)
    return jsonify({"result": result})

@app.route("/api/launch", methods=["POST"])
def api_launch():
    """启动应用"""
    package = request.json.get("package", "")
    activity = request.json.get("activity", "")
    result = adb.launch(package, activity)
    return jsonify({"result": result})

@app.route("/api/stop", methods=["POST"])
def api_stop_app():
    """停止应用"""
    package = request.json.get("package", "")
    adb.stop_app(package)
    return jsonify({"ok": True})

@app.route("/api/shell", methods=["POST"])
def api_shell():
    """执行 shell 命令"""
    command = request.json.get("command", "")
    result = adb.shell(command)
    return jsonify({"result": result})

# ============================================================
# 键盘输入 API
# ============================================================

@app.route("/api/keyboard", methods=["POST"])
def api_keyboard():
    """电脑键盘输入到设备"""
    data = request.json
    key = data.get("key", "")
    shift = data.get("shift", False)
    result = adb.keyboard_input(key, shift)
    return jsonify({"result": result})

# ============================================================
# 桌面模式 API
# ============================================================

@app.route("/api/desktop/enable", methods=["POST"])
def api_desktop_enable():
    """开启桌面模式（自由窗口）"""
    result = adb.desktop_mode_enable()
    return jsonify({"result": result})

@app.route("/api/desktop/show", methods=["POST"])
def api_desktop_show():
    """切到桌面（HOME + 最近任务）"""
    result = adb.show_desktop()
    return jsonify({"result": result})

@app.route("/api/desktop/launch", methods=["POST"])
def api_desktop_launch():
    """以自由窗口方式启动应用"""
    data = request.json
    package = data.get("package", "")
    activity = data.get("activity", "")
    result = adb.desktop_launch_app(package, activity)
    return jsonify({"result": result})

# ============================================================
# Root 管理 API
# ============================================================

@app.route("/api/root/status")
def api_root_status():
    """检查 root 状态"""
    return jsonify(adb.root_status())

@app.route("/api/root/enable", methods=["POST"])
def api_root_enable():
    """尝试启用 root（adb root）"""
    result = adb.root_enable()
    return jsonify({"result": result})

@app.route("/api/root/shell", methods=["POST"])
def api_root_shell():
    """以 root 执行命令"""
    command = request.json.get("command", "")
    result = adb.root_shell(command)
    return jsonify({"result": result})

@app.route("/api/root/remount", methods=["POST"])
def api_root_remount():
    """重新挂载 /system 为可写"""
    result = adb.root_remount()
    return jsonify({"result": result})

@app.route("/api/root/magisk", methods=["POST"])
def api_root_magisk():
    """一键安装 Magisk"""
    apk_path = request.json.get("path", "")
    result = adb.magisk_install(apk_path)
    return jsonify({"result": result})

# ============================================================
# WebSocket 实时推流
# ============================================================

@socketio.on("connect")
def on_connect():
    """客户端连接时"""
    emit("status", {"msg": "已连接到 Android Sandbox"})
    devices = adb.devices()
    emit("devices", {"devices": devices})
    if devices:
        emit("status", {"msg": f"当前设备: {devices[0]['id']} ({devices[0]['state']})"})

@socketio.on("start_stream")
def on_start_stream():
    """开始实时推流"""
    global streaming, stream_thread
    streaming = True
    emit("status", {"msg": "开始实时推流"})
    if stream_thread is None or not stream_thread.is_alive():
        stream_thread = threading.Thread(target=_stream_loop, daemon=True)
        stream_thread.start()

@socketio.on("stop_stream")
def on_stop_stream():
    """停止推流"""
    global streaming
    streaming = False
    emit("status", {"msg": "已停止推流"})

@socketio.on("tap")
def on_tap(data):
    """WebSocket 点击"""
    adb.tap(int(data["x"]), int(data["y"]))
    emit("status", {"msg": f"点击 ({data['x']}, {data['y']})"})

@socketio.on("swipe")
def on_swipe(data):
    """WebSocket 滑动"""
    adb.swipe(
        int(data["x1"]), int(data["y1"]),
        int(data["x2"]), int(data["y2"]),
        int(data.get("duration", 300)),
    )

@socketio.on("key")
def on_key(data):
    """WebSocket 按键"""
    adb.key(data["keycode"])
    emit("status", {"msg": f"按键 {data['keycode']}"})

@socketio.on("input")
def on_input(data):
    """WebSocket 输入文字"""
    adb.input_text(data["text"])
    emit("status", {"msg": f"输入: {data['text']}"})

@socketio.on("shell")
def on_shell(data):
    """WebSocket 执行 shell"""
    result = adb.shell(data["command"])
    emit("shell_result", {"result": result})

def _stream_loop():
    """实时截图推流循环"""
    global streaming
    while streaming:
        try:
            data = adb.screenshot()
            b64 = base64.b64encode(data).decode("utf-8")
            socketio.emit("frame", {"image": b64})
        except Exception as e:
            socketio.emit("status", {"msg": f"推流错误: {e}"})
            time.sleep(2)
        time.sleep(FRAME_INTERVAL)

# ============================================================
# 启动
# ============================================================

if __name__ == "__main__":
    host = os.environ.get("HOST", "0.0.0.0")
    port = int(os.environ.get("PORT", "7000"))
    print(f"\n{'='*50}")
    print(f"  Android Sandbox 服务启动")
    print(f"  地址: http://localhost:{port}")
    print(f"  截图间隔: {FRAME_INTERVAL}秒")
    print(f"{'='*50}\n")
    socketio.run(app, host=host, port=port, debug=False, allow_unsafe_werkzeug=True)
