#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo "Jalankan sebagai root." >&2; exit 1; }
. /etc/os-release
[[ "${ID:-}" == "ubuntu" && "${VERSION_ID:-}" == "24.04" ]] || { echo "Khusus Ubuntu 24.04." >&2; exit 1; }

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y docker.io curl jq ca-certificates
systemctl enable --now docker

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64) WINGS_ARCH="amd64" ;;
  aarch64|arm64) WINGS_ARCH="arm64" ;;
  *) echo "Arsitektur tidak didukung: $ARCH" >&2; exit 1 ;;
esac

# Latest stable Wings 1.x release.
RELEASE_JSON="$(mktemp)"
curl -fsSL "https://api.github.com/repos/pterodactyl/wings/releases?per_page=100" -o "$RELEASE_JSON"
TAG="$(jq -r '[.[] | select(.draft == false and .prerelease == false and (.tag_name | test("^v1\\."))) ] | sort_by(.published_at) | last | .tag_name' "$RELEASE_JSON")"
rm -f "$RELEASE_JSON"
[[ -n "$TAG" && "$TAG" != "null" ]] || { echo "Release Wings 1.x tidak ditemukan." >&2; exit 1; }

install -d -m 755 /etc/pterodactyl
curl -fL "https://github.com/pterodactyl/wings/releases/download/${TAG}/wings_linux_${WINGS_ARCH}" -o /usr/local/bin/wings
chmod 755 /usr/local/bin/wings

cat > /etc/systemd/system/wings.service <<'EOF'
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service
[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload

echo "[OK] Wings $TAG dan Docker terpasang."
echo
echo "BUAT NODE TERLEBIH DAHULU di Panel: Admin > Nodes > Create New."
echo "Lalu buka tab Configuration > Generate Token."
read -r -p "URL Panel (contoh https://panel.example.com): " PANEL_URL
read -r -p "Node ID (angka): " NODE_ID
[[ "$PANEL_URL" =~ ^https://[A-Za-z0-9.-]+$ ]] || { echo "URL harus HTTPS." >&2; exit 1; }
[[ "$NODE_ID" =~ ^[0-9]+$ ]] || { echo "Node ID harus angka." >&2; exit 1; }
read -r -s -p "Token Auto-Deploy (input tidak ditampilkan): " TOKEN
echo
[[ "$TOKEN" =~ ^ptla_[A-Za-z0-9]+$ ]] || { unset TOKEN; echo "Format token tidak sesuai." >&2; exit 1; }

wings configure --panel-url "$PANEL_URL" --token "$TOKEN" --node "$NODE_ID"
unset TOKEN
[[ -s /etc/pterodactyl/config.yml ]] || { echo "Config Wings tidak terbentuk." >&2; exit 1; }

systemctl enable --now wings
sleep 2
systemctl --no-pager --full status wings || true
echo "[OK] Wings telah dimulai. Periksa status Node di Panel."
