#!/bin/sh
# AU_MY_HOME box (DoroCloud instance 68, Alpine 3.21, 128MB RAM) — LEAN AnyTLS setup.
# v2: uses busybox wget (no curl install), downloads to /root (disk, not /tmp tmpfs),
# deletes the tarball right after extraction. Run on the box via panel terminal.
set -e
echo "=== AU_MY_HOME AnyTLS setup v2 (lean, 128MB) ==="

# 1. Stop and remove any existing proxy.
echo "--- cleaning old proxy ---"
for svc in sing-box xray v2ray; do
  rc-service "$svc" stop 2>/dev/null || true
  rc-update del "$svc" default 2>/dev/null || true
done
pkill -f sing-box 2>/dev/null || true
pkill -f xray 2>/dev/null || true
pkill -f v2ray 2>/dev/null || true
sleep 1
rm -rf /etc/sing-box /etc/xray /etc/v2ray /usr/local/etc/xray /usr/local/etc/v2ray
rm -f /etc/init.d/sing-box /etc/init.d/xray /etc/init.d/v2ray

# 2. Install only what we need (openssl for the cert, gcompat for the glibc binary).
echo "--- installing openssl + gcompat ---"
apk add --no-cache openssl gcompat ca-certificates 2>/dev/null || apk add --no-cache openssl gcompat

# 3. Download the sing-box binary to /root (disk), extract, install, clean up at once.
echo "--- downloading sing-box (to disk) ---"
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) SB_ARCH="amd64" ;;
  aarch64) SB_ARCH="arm64" ;;
  *) echo "UNSUPPORTED_ARCH $ARCH"; exit 1 ;;
esac
mkdir -p /root/sbdl && cd /root/sbdl
wget -q "https://github.com/SagerNet/sing-box/releases/download/v1.14.4/sing-box-1.14.4-linux-${SB_ARCH}.tar.gz" -O sb.tar.gz
tar xzf sb.tar.gz
SB_BIN=$(find . -name sing-box -type f | head -1)
[ -n "$SB_BIN" ] || { echo "SINGBOX_BIN_NOT_FOUND"; exit 1; }
cp "$SB_BIN" /usr/local/bin/sing-box
chmod +x /usr/local/bin/sing-box
# Free the disk/RAM immediately.
cd /root && rm -rf /root/sbdl
/usr/local/bin/sing-box version

# 4. Generate a random password and a self-signed cert.
echo "--- generating password and cert ---"
PW=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')
mkdir -p /etc/sing-box
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes \
  -keyout /etc/sing-box/key.pem -out /etc/sing-box/cert.pem \
  -days 3650 -subj "/CN=45.196.237.229" 2>/dev/null

# 5. Write the sing-box config (AnyTLS inbound on 15935, direct outbound).
cat > /etc/sing-box/config.json <<EOF
{
  "log": { "level": "warning" },
  "inbounds": [
    {
      "type": "anytls",
      "tag": "anytls-aumy",
      "listen": "0.0.0.0",
      "listen_port": 15935,
      "users": [
        { "name": "root", "password": "$PW" }
      ],
      "tls": {
        "enabled": true,
        "server_name": "45.196.237.229",
        "certificate_path": "/etc/sing-box/cert.pem",
        "key_path": "/etc/sing-box/key.pem"
      }
    }
  ],
  "outbounds": [
    { "type": "direct", "tag": "direct" }
  ],
  "route": { "rules": [], "final": "direct" }
}
EOF
/usr/local/bin/sing-box check -c /etc/sing-box/config.json

# 6. OpenRC service + start.
cat > /etc/init.d/sing-box <<'EOS'
#!/sbin/openrc-run
name="sing-box"
description="sing-box proxy"
command="/usr/local/bin/sing-box"
command_args="run -c /etc/sing-box/config.json"
command_background=true
pidfile="/run/sing-box.pid"
depend() {
  need net
  after firewall
}
EOS
chmod +x /etc/init.d/sing-box
rc-update add sing-box default 2>/dev/null || true
rc-service sing-box restart 2>/dev/null || rc-service sing-box start
sleep 2
rc-service sing-box status
ss -tlnp 2>/dev/null | grep 15935 || netstat -tlnp 2>/dev/null | grep 15935
free -m
echo "=== AU_MY_HOME_ANYTLS_DONE ==="
echo "SERVER 45.196.237.229"
echo "PORT 15935"
echo "PASSWORD $PW"
echo "NAME 澳洲家宽AnyTLS"
echo "NOTE: Malaysia relays to this box; add the node via the Malaysia relay."
