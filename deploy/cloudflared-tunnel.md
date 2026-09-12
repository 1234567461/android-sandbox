# 在线公网访问配置

把跑在本机/VPS 的 Android Sandbox 暴露到公网，让任意浏览器直接访问。三种方案，按推荐度排序。

---

## 方案 A：Cloudflare Tunnel（推荐，免备案、免费、HTTPS）

无需公网 IP，无需开放端口，Cloudflare 提供免费隧道。

```bash
# 1. 装 cloudflared
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
  | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-main.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/cloudflared.list
sudo apt update && sudo apt install -y cloudflared

# 2. 登录（会弹一个 URL，浏览器打开授权）
cloudflared tunnel login

# 3. 创建隧道
cloudflared tunnel create android-sandbox
#   → 会输出 Tunnel ID，并生成凭证文件 ~/.cloudflared/<UUID>.json

# 4. 配置隧道（把 :7000 暴露出去）
cat > ~/.cloudflared/config.yml <<EOF
tunnel: <上一步的 UUID>
credentials-file: /root/.cloudflared/<UUID>.json

ingress:
  - hostname: sandbox.你的域名.com
    service: http://localhost:7000
  - service: http_status:404
EOF

# 5. 域名 DNS（Cloudflare 托管的域名）
cloudflared tunnel route dns android-sandbox sandbox.你的域名.com

# 6. 启动（前台先测，OK 后装成 systemd）
cloudflared tunnel run android-sandbox

# 装成开机自启
sudo cloudflared service install
sudo systemctl enable --now cloudflared
```

访问：`https://sandbox.你的域名.com`

**优点**：免费、自带 HTTPS、隐藏源 IP、不限服务器有没有公网 IP（家里宽带/办公室机器都行）。

---

## 方案 B：Nginx 反向代理 + 域名（有公网 IP 的 VPS）

```bash
sudo apt install -y nginx

sudo tee /etc/nginx/sites-available/android-sandbox <<'EOF'
server {
    listen 80;
    server_name sandbox.你的域名.com;

    # WebSocket（屏幕推流必需，否则实时画面不刷新）
    location / {
        proxy_pass http://127.0.0.1:7000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/android-sandbox /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# HTTPS（用 certbot 一键）
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d sandbox.你的域名.com
```

**注意**：`proxy_set_header Upgrade` 和 `Connection "upgrade"` 必须有，否则 WebSocket 推流画面不会动。

---

## 方案 C：frp / Tailscale 内网穿透（家里真机当设备）

适合：不想买 VPS，用家里的 Android 真机当被控设备。

```bash
# VPS 端（frps）
# frps.ini
#   [common]
#   bind_port = 7000
#   vhost_http_port = 8080

# 家里机器（frpc，跟 sandbox 一起跑）
# frpc.ini
#   [common]
#   server_addr = 你的VPS_IP
#   server_port = 7000
#   [sandbox]
#   type = http
#   local_port = 7000
#   custom_domains = sandbox.你的域名.com
```

或用 Tailscale（更简单，设备间自动组网）：

```bash
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up
# 然后用 tailscale 分配的 IP 访问 http://<tailscale-ip>:7000
```

---

## 选哪个

| 场景 | 推荐方案 |
|---|---|
| 有域名 + 想免费 HTTPS | A: Cloudflare Tunnel |
| VPS 有公网 IP + 自己的域名 | B: Nginx + certbot |
| 不想买 VPS，用家里真机 | C: Tailscale / frp |
| 临时给别人看一眼 | `cloudflared tunnel --url http://localhost:7000`（快速隧道，URL 每次变） |
