#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$ROOT_DIR/scripts"

fail() { echo "[ERROR] $*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || fail "Jalankan sebagai root: sudo bash install.sh"
[[ -r /etc/os-release ]] || fail "Tidak dapat membaca /etc/os-release"
. /etc/os-release
[[ "${ID:-}" == "ubuntu" && "${VERSION_ID:-}" == "24.04" ]] || fail "Installer ini khusus Ubuntu 24.04."
command -v systemctl >/dev/null || fail "systemd diperlukan."

echo "=============================================="
echo " Pterodactyl 1.x Stable - Ubuntu 24.04"
echo " Panel + MariaDB + Redis + Nginx + SSL + Wings"
echo "=============================================="
echo "Pastikan VPS baru/bersih, akses root, domain sudah"
echo "mengarah ke IP VPS, dan provider mengizinkan Docker."
echo
read -r -p "Domain Panel (contoh: panel.example.com): " PANEL_DOMAIN
read -r -p "Email untuk sertifikat Let's Encrypt: " LE_EMAIL
[[ "$PANEL_DOMAIN" =~ ^([A-Za-z0-9-]+\.)+[A-Za-z]{2,}$ ]] || fail "Format domain tidak valid."
[[ "$LE_EMAIL" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]] || fail "Format email tidak valid."

export PANEL_DOMAIN LE_EMAIL
echo
echo "Tahap 1/5: Database"
bash "$SCRIPTS_DIR/database.sh"

echo
echo "Tahap 2/5: Panel"
PANEL_DOMAIN="$PANEL_DOMAIN" bash "$SCRIPTS_DIR/panel.sh"

echo
echo "Tahap 3/5: SSL"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y certbot python3-certbot-nginx
certbot --nginx --non-interactive --agree-tos --redirect \
  --email "$LE_EMAIL" -d "$PANEL_DOMAIN" || fail "Penerbitan SSL gagal. Periksa DNS, firewall port 80/443, lalu jalankan: certbot --nginx -d $PANEL_DOMAIN"

echo
echo "Tahap 4/5: Egg Node.js"
bash "$SCRIPTS_DIR/eggs.sh"

echo
echo "Tahap 5/5: Wings"
echo "Wings memerlukan Node yang dibuat dari dashboard Panel."
echo "Setelah login Panel, buat Admin > Nodes > Create New,"
echo "buka tab Configuration, Generate Token, lalu jalankan wings.sh."
echo
echo "Panel: https://$PANEL_DOMAIN"
echo "Database credentials: /root/.ptero-db.env (izin 600)"
echo "Egg JSON: $ROOT_DIR/eggs/nodejs-22.json"
echo
echo "Pemasangan Panel selesai. Wings belum aktif sampai Node dikonfigurasi."
