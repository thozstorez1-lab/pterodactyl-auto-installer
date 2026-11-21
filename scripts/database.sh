#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo "Jalankan sebagai root." >&2; exit 1; }

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y mariadb-server redis-server openssl

systemctl enable --now mariadb redis-server

DB_NAME="panel"
DB_USER="pterodactyl"
DB_PASS="$(openssl rand -hex 24)"

# Idempotent for this install: recreate only the dedicated panel account/database.
mariadb <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';
ALTER USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL

umask 077
cat > /root/.ptero-db.env <<EOF
DB_NAME='${DB_NAME}'
DB_USER='${DB_USER}'
DB_PASS='${DB_PASS}'
EOF
chmod 600 /root/.ptero-db.env

echo "[OK] MariaDB dan Redis aktif."
echo "[OK] Kredensial database tersimpan di /root/.ptero-db.env (mode 600)."
