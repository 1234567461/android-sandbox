"""
ADB 控制器 —— 封装所有跟 Android 设备/模拟器的交互
功能: 截图、安装应用、启动应用、输入文字、按键、滑动、点击、Shell 命令
"""

import subprocess
import os
import time
import base64
import tempfile
import shutil
import json
from typing import Optional


class ADBController:
    """封装 adb 命令，提供一个干净的接口给 Web 服务调用"""

    def __init__(self, device_id: str = "", adb_path: str = "adb"):
        self.device_id = device_id
        self.adb = adb_path
        # 如果指定了设备 ID，所有命令都带 -s 参数
        self._device_arg = f"-s {device_id}" if device_id else ""

    def _run(self, args: str, timeout: int = 30) -> str:
        """执行 adb 命令，返回输出"""
        cmd = f"{self.adb} {self._device_arg} {args}"
        try:
            result = subprocess.run(
                cmd, shell=True, capture_output=True, text=True, timeout=timeout
            )
            if result.returncode != 0:
                return f"错误: {result.stderr.strip()}"
            return result.stdout.strip()
        except subprocess.TimeoutExpired:
            return "错误: 命令超时"
        except FileNotFoundError:
            return "错误: 找不到 adb，请先安装 Android Platform Tools"

    def _run_bytes(self, args: str, timeout: int = 30) -> bytes:
        """执行 adb 命令，返回原始字节数据（用于截图等二进制输出）"""
        cmd = f"{self.adb} {self._device_arg} {args}"
        try:
            result = subprocess.run(
                cmd, shell=True, capture_output=True, timeout=timeout
            )
            if result.returncode != 0:
                return b""
            return result.stdout
        except subprocess.TimeoutExpired:
            return b""
        except FileNotFoundError:
            return b""

    def devices(self) -> list:
        """列出所有已连接的设备"""
        output = self._run("devices")
        devices = []
        for line in output.split("\n")[1:]:
            line = line.strip()
            if line and "\t" in line:
                dev_id, state = line.split("\t")
                devices.append({"id": dev_id, "state": state})
        return devices

    def screenshot(self) -> bytes:
        """截图，返回 PNG 图片的字节数据

        使用 `adb exec-out screencap -p` 直接把 PNG 流到 stdout，
        省掉了原来的「截图到 /sdcard → pull → 删除」三步磁盘 I/O，
        推流延迟明显降低。
        """
        # exec-out 不经过 device 端的 pty，二进制不会被改坏
        data = self._run_bytes("exec-out screencap -p", timeout=10)
        if data:
            # screencap 输出的 PNG 以 0x89 50 4E 47 开头
            if data[:4] == b"\x89PNG":
                return data
            # 某些设备会把 \n 转成 \r\n，需要还原
            if b"\r\n" in data:
                data = data.replace(b"\r\n", b"\n")
                if data[:4] == b"\x89PNG":
                    return data
        # 回退到老的 pull 方式
        return self._screenshot_legacy()

    def _screenshot_legacy(self) -> bytes:
        """旧版截图方式（兼容 exec-out 不可用的设备）"""
        tmp_remote = "/sdcard/sandbox_screenshot.png"
        self._run(f"shell screencap -p {tmp_remote}", timeout=10)

        tmp_local = tempfile.NamedTemporaryFile(suffix=".png", delete=False)
        tmp_local.close()

        cmd = f"{self.adb} {self._device_arg} pull {tmp_remote} {tmp_local.name}"
        subprocess.run(cmd, shell=True, capture_output=True, timeout=10)

        # 删掉设备上的临时文件
        self._run(f"shell rm {tmp_remote}", timeout=5)

        with open(tmp_local.name, "rb") as f:
            data = f.read()

        os.unlink(tmp_local.name)
        return data

    def screenshot_base64(self) -> str:
        """截图，返回 base64 编码的字符串"""
        data = self.screenshot()
        return base64.b64encode(data).decode("utf-8")

    def install(self, apk_path: str) -> str:
        """安装 APK"""
        if not os.path.exists(apk_path):
            return f"错误: 文件不存在 {apk_path}"
        return self._run(f"install -r {apk_path}", timeout=120)

    def uninstall(self, package: str) -> str:
        """卸载应用"""
        return self._run(f"uninstall {package}", timeout=30)

    def launch(self, package: str, activity: str = "") -> str:
        """启动应用"""
        if activity:
            return self._run(
                f"shell am start -n {package}/{activity}", timeout=10
            )
        # 用 monkey 启动主 Activity
        return self._run(
            f"shell monkey -p {package} -c android.intent.category.LAUNCHER 1",
            timeout=10,
        )

    def stop_app(self, package: str) -> str:
        """强制停止应用"""
        return self._run(f"shell am force-stop {package}", timeout=10)

    def tap(self, x: int, y: int) -> str:
        """点击屏幕坐标"""
        return self._run(f"shell input tap {x} {y}", timeout=5)

    def swipe(self, x1: int, y1: int, x2: int, y2: int, duration: int = 300) -> str:
        """滑动"""
        return self._run(
            f"shell input swipe {x1} {y1} {x2} {y2} {duration}", timeout=5
        )

    def input_text(self, text: str) -> str:
        """输入文字"""
        # 转义特殊字符
        text = text.replace(" ", "%s").replace("&", "\\&").replace("<", "\\<").replace(">", "\\>")
        return self._run(f"shell input text '{text}'", timeout=5)

    def key(self, keycode: str) -> str:
        """按键，比如 HOME, BACK, POWER"""
        return self._run(f"shell input keyevent {keycode}", timeout=5)

    def back(self) -> str:
        """返回键"""
        return self.key("4")

    def home(self) -> str:
        """Home 键"""
        return self.key("3")

    def menu(self) -> str:
        """菜单键"""
        return self.key("82")

    def shell(self, command: str) -> str:
        """执行任意 shell 命令"""
        return self._run(f'shell {command}', timeout=30)

    # ============================================================
    # 键盘映射：把电脑键盘按键映射到 Android
    # ============================================================

    # 电脑键盘 → Android keycode 映射表
    # 参考: https://developer.android.com/reference/android/view/KeyEvent
    # JS KeyboardEvent.code 命名参考: https://gist.github.com/GalvinGao/83ae9530434b11b0c203138025789f46
    KEY_MAP = {
        # 特殊键
        "Enter":      "66",   # KEYCODE_ENTER
        "Backspace":  "67",   # KEYCODE_DEL
        "Tab":        "61",   # KEYCODE_TAB
        "Escape":     "111",  # KEYCODE_ESCAPE
        " ":          "62",   # KEYCODE_SPACE
        "Delete":     "112",  # KEYCODE_FORWARD_DEL
        "Space":      "62",   # KEYCODE_SPACE（KeyboardEvent.code 兼容）
        # 方向键
        "ArrowUp":    "19",   # KEYCODE_DPAD_UP
        "ArrowDown":  "20",   # KEYCODE_DPAD_DOWN
        "ArrowLeft":  "21",   # KEYCODE_DPAD_LEFT
        "ArrowRight": "22",   # KEYCODE_DPAD_RIGHT
        # 功能键
        "Home":       "3",    # KEYCODE_HOME
        "End":        "123",  # KEYCODE_MOVE_END
        "PageUp":     "92",   # KEYCODE_PAGE_UP
        "PageDown":   "93",   # KEYCODE_PAGE_DOWN
        # 修饰键
        "Shift":      "59",   # KEYCODE_SHIFT_LEFT
        "ShiftLeft":  "59",
        "ShiftRight": "60",
        "Control":    "113",  # KEYCODE_CTRL_LEFT
        "ControlLeft":  "113",
        "ControlRight": "114",
        "Alt":        "57",   # KEYCODE_ALT_LEFT
        "AltLeft":    "57",
        "AltRight":   "58",
        "Meta":       "117",  # KEYCODE_META_LEFT
        "MetaLeft":   "117",
        "MetaRight":  "118",
        # Android 功能键
        "F1":  "131", "F2": "132", "F3": "133", "F4": "134",
        "F5":  "135", "F6": "136", "F7": "137", "F8": "138",
        "F9":  "139", "F10": "140", "F11": "141", "F12": "142",
        # 数字键（主键盘区，KeyboardEvent.code 命名）
        "Digit0": "7",  "Digit1": "8",  "Digit2": "9",  "Digit3": "10",
        "Digit4": "11", "Digit5": "12", "Digit6": "13", "Digit7": "14",
        "Digit8": "15", "Digit9": "16",
        # 小键盘
        "Numpad0": "7",  "Numpad1": "8",  "Numpad2": "9",  "Numpad3": "10",
        "Numpad4": "11", "Numpad5": "12", "Numpad6": "13", "Numpad7": "14",
        "Numpad8": "15", "Numpad9": "16",
        "NumpadMultiply": "17",  # *
        "NumpadAdd":      "81",  # +
        "NumpadSubtract": "69",  # -
        "NumpadDecimal":  "56",  # .
        "NumpadDivide":   "76",  # /
        "NumpadEnter":    "66",  # Enter
        # 字母键 A-Z（KeyboardEvent.code 命名: KeyA..KeyZ）
        "KeyA": "29",  "KeyB": "30",  "KeyC": "31",  "KeyD": "32",
        "KeyE": "33",  "KeyF": "34",  "KeyG": "35",  "KeyH": "36",
        "KeyI": "37",  "KeyJ": "38",  "KeyK": "39",  "KeyL": "40",
        "KeyM": "41",  "KeyN": "42",  "KeyO": "43",  "KeyP": "44",
        "KeyQ": "45",  "KeyR": "46",  "KeyS": "47",  "KeyT": "48",
        "KeyU": "49",  "KeyV": "50",  "KeyW": "51",  "KeyX": "52",
        "KeyY": "53",  "KeyZ": "54",
        # 符号键
        "Minus":         "69",  # -
        "Equal":         "70",  # =
        "BracketLeft":   "71",  # [
        "BracketRight":  "72",  # ]
        "Backslash":     "73",  # \
        "Semicolon":     "74",  # ;
        "Quote":         "75",  # '
        "Comma":         "55",  # ,
        "Period":        "56",  # .
        "Slash":         "76",  # /
        "Backquote":     "68",  # `
        # 兼容单字符输入（input_text 走文本通道）
        "-":  "69",  "=":  "70",  "+":  "81",  "*":  "17",  "/":  "76",
        ".":  "56",  ",":  "55",  "'":  "75",  "`":  "68",
        "[":  "71",  "]":  "72",  "\\": "73",  ";":  "74",  "@":  "77",
    }

    def keyboard_input(self, key: str, shift: bool = False) -> str:
        """模拟电脑键盘输入到 Android 设备

        参数:
            key: 按键名（如 'a', 'A', 'Enter', 'ArrowUp'）
            shift: 是否按了 Shift
        """
        # 特殊键
        if key in self.KEY_MAP:
            return self.key(self.KEY_MAP[key])

        # 单个字符（字母、数字、符号）
        if len(key) == 1:
            # 如果是大写字母或 Shift 组合，发大写
            if shift and key.isalpha():
                key = key.upper()
            elif shift:
                # Shift + 符号，映射到对应字符
                shift_map = {
                    "1": "!", "2": "@", "3": "#", "4": "$", "5": "%",
                    "6": "^", "7": "&", "8": "*", "9": "(", "0": ")",
                    "-": "_", "=": "+", "[": "{", "]": "}",
                    "\\": "|", ";": ":", "'": "\"", ",": "<",
                    ".": ">", "/": "?", "`": "~",
                }
                key = shift_map.get(key, key)
            return self.input_text(key)

        return f"未映射的键: {key}"

    # ============================================================
    # Root 相关命令
    # ============================================================

    def root_status(self) -> dict:
        """检查设备 root 状态"""
        result = {}
        # 检查 su 命令是否可用
        su_check = self._run("shell which su", timeout=5)
        result["su_available"] = "su" in su_check and "错误" not in su_check
        result["su_path"] = su_check if result["su_available"] else ""

        # 检查当前是否以 root 运行
        uid = self._run("shell id", timeout=5)
        result["is_root"] = "uid=0" in uid
        result["current_uid"] = uid

        # 检查 adb root 是否可用
        adb_root = self._run("root", timeout=5)
        result["adb_root_response"] = adb_root

        # 检查 Magisk
        magisk = self._run("shell which magisk", timeout=5)
        result["magisk"] = "magisk" in magisk and "错误" not in magisk

        return result

    def root_enable(self) -> str:
        """尝试启用 root（adb root）"""
        return self._run("root", timeout=10)

    def root_shell(self, command: str) -> str:
        """以 root 执行命令（需要设备已 root）"""
        return self._run(f'shell su -c "{command}"', timeout=30)

    def root_remount(self) -> str:
        """重新挂载 /system 为可写（需要 root）"""
        return self._run("shell su -c 'mount -o remount,rw /system'", timeout=10)

    def root_install_su(self, apk_path: str) -> str:
        """安装 Superuser / Magisk（通过刷入或安装 APK）"""
        if not os.path.exists(apk_path):
            return f"错误: 文件不存在 {apk_path}"
        # 先正常安装 APK
        install_result = self.install(apk_path)
        # 尝试通过 root 执行
        return install_result

    # ============================================================
    # Magisk 一键安装辅助（仅在 userdebug ROM / 模拟器可直接 root；
    # 真机一般需解锁 BL 后用 Magisk App 自行 patch boot.img）
    # ============================================================

    # Magisk 官方 release 地址（可被环境变量覆盖）
    MAGISK_URL = "https://github.com/topjohnwu/Magisk/releases/latest/download/app-debug.apk"

    def magisk_install(self, apk_path: str = "") -> str:
        """一键安装 Magisk

        流程：
          1. 如果没给 apk_path，尝试从官方下载 app-debug.apk
          2. 推送并安装到设备
          3. 尝试 adb root + remount（userdebug 才行）
          4. 返回逐步结果
        真机要解锁 BL + Magisk App patch boot.img，本工具做不了。
        """
        steps = []

        # 1. 下载
        if not apk_path:
            apk_path = "/tmp/magisk-app-debug.apk"
            if not os.path.exists(apk_path):
                import urllib.request
                try:
                    urllib.request.urlretrieve(self.MAGISK_URL, apk_path)
                    steps.append(f"下载完成: {apk_path}")
                except Exception as e:
                    steps.append(f"下载失败: {e}")
                    return "\n".join(steps)
            else:
                steps.append("APK 已存在，跳过下载")

        if not os.path.exists(apk_path):
            steps.append(f"错误: 文件不存在 {apk_path}")
            return "\n".join(steps)

        # 2. 安装 APK
        steps.append("安装 APK: " + self.install(apk_path)[:200])

        # 3. 尝试 adb root（userdebug ROM）
        root_resp = self.root_enable()
        steps.append(f"adb root: {root_resp[:200]}")

        # 4. 启动 Magisk App
        launch_result = self.launch("com.topjohnwu.magisk")
        steps.append(f"启动 Magisk: {launch_result[:200]}")

        steps.append(
            "提示: 真机如果失败，需要：① 解锁 Bootloader；"
            "② 在 Magisk App 里 patch boot.img；③ fastboot flash boot patched.img"
        )
        return "\n".join(steps)

    # ============================================================
    # 桌面模式（Android 10+ 自由窗口 / Desktop Mode）
    # ============================================================

    def desktop_mode_enable(self) -> str:
        """开启桌面模式（自由窗口）

        1. 打开 freeform 窗口支持
        2. 强制开启 desktop mode（开发者选项里的开关）
        3. 重启 systemui 让设置生效（需要 root 或 userdebug）
        """
        steps = []
        # 开启自由窗口（无需 root，但需要 Android 10+）
        steps.append(self._run("shell settings put global freeform_display 1", timeout=5))
        # 让 desktop mode 开关在开发者选项里可见
        steps.append(self._run("shell settings put global development_settings_enabled 1", timeout=5))
        # 尝试强制开启桌面模式（仅 userdebug / root 可写）
        r = self._run("shell su -c 'settings put global desktop_mode 2'", timeout=5)
        if "错误" in r or not r:
            steps.append("desktop_mode 写入需要 root，跳过（自由窗口仍可用）")
        else:
            steps.append(r)
        return "\n".join(steps)

    def desktop_launch_app(self, package: str, activity: str = "") -> str:
        """以自由窗口（桌面窗口）方式启动应用"""
        if activity:
            cmd = (
                f"shell am start -n {package}/{activity} "
                f"--windowingMode freeform "
                f"--activity-clear-task"
            )
            return self._run(cmd, timeout=10)
        # 没有 activity 就先用 monkey 启动主 Activity，再切到自由窗口
        self._run(
            f"shell monkey -p {package} -c android.intent.category.LAUNCHER 1",
            timeout=10,
        )
        # 解析出主 Activity 名，再用 freeform 模式启动一次
        resolve = self._run(
            f"shell cmd package resolve-activity --brief {package}",
            timeout=10,
        )
        # resolve 输出最后一行形如 "package/activity"
        last = resolve.strip().splitlines()[-1] if resolve.strip() else ""
        if "/" in last:
            pkg_name, act_name = last.split("/", 1)
            return self._run(
                f"shell am start -n {pkg_name}/{act_name} "
                f"--windowingMode freeform --activity-clear-task",
                timeout=10,
            )
        return f"无法解析主 Activity，已普通启动 {package}"

    def show_desktop(self) -> str:
        """回到桌面（HOME）并展开自由窗口的桌面视图"""
        # 先按 HOME
        self.home()
        # 再触发 recents（最近任务）让用户挑自由窗口
        time.sleep(0.3)
        self.key("187")  # APP_SWITCH
        return "已切到桌面/最近任务视图"

    def get_installed_apps(self) -> list:
        """获取已安装的第三方应用列表"""
        output = self._run("shell pm list packages -3", timeout=15)
        apps = []
        for line in output.split("\n"):
            line = line.strip()
            if line.startswith("package:"):
                apps.append(line.replace("package:", ""))
        return apps

    def get_device_info(self) -> dict:
        """获取设备信息"""
        info = {}
        info["model"] = self._run("shell getprop ro.product.model", timeout=5)
        info["brand"] = self._run("shell getprop ro.product.brand", timeout=5)
        info["version"] = self._run("shell getprop ro.build.version.release", timeout=5)
        info["sdk"] = self._run("shell getprop ro.build.version.sdk", timeout=5)
        info["resolution"] = self._run("shell wm size", timeout=5)
        info["battery"] = self._run("shell dumpsys battery | grep level", timeout=5)
        return info

    def push_file(self, local: str, remote: str) -> str:
        """推送文件到设备"""
        return self._run(f"push {local} {remote}", timeout=30)

    def pull_file(self, remote: str, local: str) -> str:
        """从设备拉取文件"""
        return self._run(f"pull {remote} {local}", timeout=30)
