#!/bin/sh
# SG v6 box (DoroCloud instance 67, Alpine 3.21) — clean VLESS, install sing-box AnyTLS.
# Runs ON the SG box via panel terminal. Generates its own random AnyTLS password
# and prints the node details at the end. No password is embedded in this script.
set -e
echo "=== SG AnyTLS setup ==="

# 1. Stop and remove any existing VLESS / proxy (xray, sing-box, v2ray).
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

# 2. Install sing-box 1.14.4 (official binary; detect arch).
echo "--- installing sing-box ---"
apk add --no-cache curl openssl ca-certificates 2>/dev/null || true
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) SB_ARCH="amd64" ;;
  aarch64) SB_ARCH="arm64" ;;
  *) echo "UNSUPPORTED_ARCH $ARCH"; exit 1 ;;
esac
cd /tmp
curl -sL -o sing-box.tar.gz "https://github.com/SagerNet/sing-box/releases/download/v1.14.4/sing-box-1.14.4-linux-${SB_ARCH}.tar.gz"
tar xzf sing-box.tar.gz
cp "sing-box-1.14.4-linux-${SB_ARCH}/sing-box" /usr/local/bin/sing-box
chmod +x /usr/local/bin/sing-box
/usr/local/bin/sing-box version

# 3. Generate a random AnyTLS password and a self-signed cert.
echo "--- generating password and cert ---"
mkdir -p /etc/sing-box
PW=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')
# Use openssl for a self-signed EC cert (CN = the box's public IPv6).
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -keyout /etc/sing-box/key.pem -out /etc/sing-box/cert.pem -days 3650 -nodes -subj "/CN=2600:3c15::2000:bfff:fee8:1268" 2>/dev/null
chmod 600 /etc/sing-box/key.pem
chmod 644 /etc/sing-box/cert.pem

# 4. Write sing-box config: AnyTLS inbound on 15935 (users array), direct outbound.
cat > /etc/sing-box/config.json <<EOF
{
  "log": {"level": "info"},
  "inbounds": [
    {
      "type": "anytls",
      "tag": "anytls-sg",
      "listen": "::",
      "listen_port": 15935,
      "users": [{"name": "root", "password": "$PW"}],
      "tls": {
        "enabled": true,
        "certificate_path": "/etc/sing-box/cert.pem",
        "key_path": "/etc/sing-box/key.pem"
      }
    }
  ],
  "outbounds": [
    {"type": "direct", "tag": "direct"},
    {"type": "block", "tag": "block"}
  ],
  "route": {"rules": [], "final": "direct"}
}
EOF
/usr/local/bin/sing-box check -c /etc/sing-box/config.json

# 5. OpenRC service (Alpine) + start.
cat > /etc/init.d/sing-box <<'SVC'
#!/sbin/openrc-run
name="sing-box"
command="/usr/local/bin/sing-box"
command_args="run -c /etc/sing-box/config.json"
command_background=true
pidfile="/run/${RC_SVCNAME}.pid"
depend() {
  need net
  after firewall
}
SVC
chmod +x /etc/init.d/sing-box
rc-update add sing-box default 2>/dev/null || true
rc-service sing-box restart
sleep 3
rc-service sing-box status
ss -tlnp 2>/dev/null | grep 15935 || netstat -tlnp 2>/dev/null | grep 15935 || echo "PORT_CHECK_MANUAL"

echo "=== SG_ANYTLS_DONE ==="
echo "SERVER 2600:3c15::2000:bfff:fee8:1268"
echo "PORT 15935"
echo "PASSWORD $PW"
echo "NAME 新加坡SG AnyTLS"
echo "NOTE: add this node to the main subscription (nodes group only, no splitting)."
