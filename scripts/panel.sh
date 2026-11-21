#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo "Jalankan sebagai root." >&2; exit 1; }
[[ -f /root/.ptero-db.env ]] || { echo "Jalankan database.sh terlebih dahulu." >&2; exit 1; }
. /root/.ptero-db.env

DOMAIN="${PANEL_DOMAIN:-}"
if [[ -z "$DOMAIN" ]]; then
  read -r -p "Domain Panel (contoh panel.example.com): " DOMAIN
fi
[[ "$DOMAIN" =~ ^([A-Za-z0-9-]+\.)+[A-Za-z]{2,}$ ]] || { echo "Domain tidak valid." >&2; exit 1; }

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y nginx curl tar unzip git ca-certificates gnupg jq \
  php8.3 php8.3-cli php8.3-common php8.3-gd php8.3-mysql php8.3-mbstring \
  php8.3-bcmath php8.3-xml php8.3-fpm php8.3-curl php8.3-zip php8.3-intl

# Install Composer 2 using the official installer and verify its published SHA-384.
EXPECTED="$(curl -fsSL https://composer.github.io/installer.sig)"
php -r "copy('https://getcomposer.org/installer', '/tmp/composer-setup.php');"
ACTUAL="$(php -r "echo hash_file('sha384', '/tmp/composer-setup.php');")"
[[ "$EXPECTED" == "$ACTUAL" ]] || { rm -f /tmp/composer-setup.php; echo "Verifikasi Composer gagal." >&2; exit 1; }
php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
rm -f /tmp/composer-setup.php

# Select newest non-prerelease 1.x Panel release from GitHub Releases API.
RELEASE_JSON="$(mktemp)"
curl -fsSL "https://api.github.com/repos/pterodactyl/panel/releases?per_page=100" -o "$RELEASE_JSON"
ASSET_URL="$(jq -r '[.[] | select(.draft == false and .prerelease == false and (.tag_name | test("^v1\\."))) ] | sort_by(.published_at) | last | .assets[]? | select(.name == "panel.tar.gz") | .browser_download_url' "$RELEASE_JSON" | head -n1)"
TAG="$(jq -r '[.[] | select(.draft == false and .prerelease == false and (.tag_name | test("^v1\\."))) ] | sort_by(.published_at) | last | .tag_name' "$RELEASE_JSON")"
rm -f "$RELEASE_JSON"
[[ -n "$ASSET_URL" && "$ASSET_URL" != "null" && -n "$TAG" && "$TAG" != "null" ]] || { echo "Tidak dapat menemukan release 1.x stable." >&2; exit 1; }

INSTALL_DIR="/var/www/pterodactyl"
if [[ -e "$INSTALL_DIR/.env" ]]; then
  echo "Folder Panel sudah berisi .env. Hentikan untuk mencegah menimpa instalasi." >&2
  exit 1
fi
install -d -o www-data -g www-data "$INSTALL_DIR"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl -fL "$ASSET_URL" -o "$TMP/panel.tar.gz"
tar -xzf "$TMP/panel.tar.gz" -C "$INSTALL_DIR"
cd "$INSTALL_DIR"

cp .env.example .env
export DB_NAME DB_USER DB_PASS DOMAIN
python3 - <<'PY'
from pathlib import Path
import os
p = Path("/var/www/pterodactyl/.env")
values = {
    "APP_ENV": "production",
    "APP_DEBUG": "false",
    "APP_URL": "https://" + os.environ["DOMAIN"],
    "DB_CONNECTION": "mysql",
    "DB_HOST": "127.0.0.1",
    "DB_PORT": "3306",
    "DB_DATABASE": os.environ["DB_NAME"],
    "DB_USERNAME": os.environ["DB_USER"],
    "DB_PASSWORD": os.environ["DB_PASS"],
    "CACHE_DRIVER": "redis",
    "SESSION_DRIVER": "redis",
    "QUEUE_DRIVER": "redis",
    "REDIS_HOST": "127.0.0.1",
}
lines = p.read_text().splitlines()
for key, value in values.items():
    replacement = f"{key}={value}"
    for i, line in enumerate(lines):
        if line.startswith(key + "="):
            lines[i] = replacement
            break
    else:
        lines.append(replacement)
p.write_text("\n".join(lines) + "\n")
PY

COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader --no-interaction
php artisan key:generate --force
php artisan migrate --seed --force
chown -R www-data:www-data "$INSTALL_DIR"
chmod -R 755 storage/* bootstrap/cache

cat > /etc/nginx/sites-available/pterodactyl.conf <<EOF
server {
    listen 80;
    server_name ${DOMAIN};
    root /var/www/pterodactyl/public;
    index index.php;
    charset utf-8;
    client_max_body_size 100m;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize=100M \\n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
    }
    location ~ /\. {
        deny all;
    }
}
EOF
ln -sfn /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable --now nginx php8.3-fpm
systemctl reload nginx

# Queue worker and scheduler.
cat > /etc/systemd/system/pteroq.service <<'EOF'
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service mariadb.service
[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
[Install]
WantedBy=multi-user.target
EOF
cat > /etc/cron.d/pterodactyl <<'EOF'
* * * * * www-data php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1
EOF
chmod 644 /etc/cron.d/pterodactyl
systemctl daemon-reload
systemctl enable --now pteroq

echo "[OK] Panel $TAG terpasang."
echo "Buat admin dengan:"
echo "cd /var/www/pterodactyl && sudo -u www-data php artisan p:user:make"
