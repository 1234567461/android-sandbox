# ============================================================
# Android Sandbox 镜像
# 内置: Android SDK + 模拟器(AVD) + Flask 服务端
# 需要: 宿主机 /dev/kvm（嵌套虚拟化）
# 参考: https://github.com/luoshixin93-sudo/android-cloud-emulator
# ============================================================

FROM ubuntu:22.04

# 避免交互
ENV DEBIAN_FRONTEND=noninteractive
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV PATH="${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/emulator"

# 系统依赖（含 KVM 加速库、x86 运行库、unzip/wget/java）
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 python3-pip \
        openjdk-17-jre-headless \
        unzip wget curl ca-certificates \
        cpu-checker libvirt-clients \
        libc6 libstdc++6 libgl1 libpulse0 libnss3 \
        socat \
    && rm -rf /var/lib/apt/lists/*

# cmdline-tools（按 Google 推荐的 latest 子目录结构摆放）
WORKDIR /tmp
ARG CLT_VER=11076708
RUN wget -q "https://dl.google.com/android/repository/commandlinetools-linux-${CLT_VER}_latest.zip" -O clt.zip \
    && unzip -q clt.zip -d ${ANDROID_HOME} \
    && mkdir -p ${ANDROID_HOME}/cmdline-tools/latest \
    && mv ${ANDROID_HOME}/cmdline-tools/bin ${ANDROID_HOME}/cmdline-tools/lib \
        ${ANDROID_HOME}/cmdline-tools/NOTICE.txt ${ANDROID_HOME}/cmdline-tools/source.properties \
        ${ANDROID_HOME}/cmdline-tools/latest/ 2>/dev/null || true \
    && rm clt.zip

# 接受协议 + 装平台组件和系统镜像（android-34 google_apis x86_64，支持 ARM 翻译）
RUN yes | sdkmanager --licenses >/dev/null 2>&1 || true \
    && sdkmanager \
        "platform-tools" \
        "emulator" \
        "platforms;android-34" \
        "system-images;android-34;google_apis;x86_64" \
        2>&1 | tail -5

# 创建 AVD（pixel_6 设备配置，无皮肤加快启动）
RUN echo "no" | avdmanager create avd \
        -n sandbox_avd \
        -k "system-images;android-34;google_apis;x86_64" \
        -d pixel_6

# Python 依赖
COPY requirements.txt /app/requirements.txt
RUN python3 -m pip install --no-cache-dir -r /app/requirements.txt

# 项目代码
COPY sandbox /app/sandbox
COPY web /app/web

WORKDIR /app

# 启动脚本：先拉起模拟器 → 等 adb 就绪 → 启 server
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# 默认 Web 端口；模拟器 ADB 端口 5555 也可暴露
EXPOSE 7000 5555

ENTRYPOINT ["/docker-entrypoint.sh"]
