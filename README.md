# Pterodactyl Auto Installer (1.x Stable)

Installer bertahap untuk **Ubuntu 24.04**. Memasang Pterodactyl Panel 1.x stable, MariaDB, Redis, Nginx, PHP 8.3, Let's Encrypt SSL, Docker, Wings 1.x, serta membuat Egg Node.js 22 untuk diimpor.

> Gunakan pada VPS milik sendiri dengan izin administrator. Disarankan VPS baru/bersih. Script membutuhkan root dan mengubah konfigurasi Nginx, MariaDB, PHP, Docker, systemd, serta firewall (firewall rules tetap perlu disesuaikan sendiri).

## Persyaratan

- Ubuntu Server 24.04 LTS, akses root/sudo.
- VPS virtualisasi KVM atau lingkungan yang mendukung Docker. OpenVZ/LXC bisa membatasi Docker.
- Domain/subdomain yang DNS A record-nya sudah mengarah ke IP publik VPS.
- Port TCP 80 dan 443 terbuka untuk Panel/Let's Encrypt.
- Untuk Wings: port TCP 8080 (daemon), TCP 2022 (SFTP), serta rentang port allocation game yang dipilih di Node.
- RAM/CPU/disk mencukupi untuk Panel dan game server. Kebutuhan game server bergantung pada game yang dijalankan.

## Struktur

```text
pterodactyl-auto-installer/
├── install.sh
├── scripts/
│   ├── database.sh
│   ├── panel.sh
│   ├── wings.sh
│   └── eggs.sh
├── eggs/
│   └── nodejs-22.json
└── README.md
```

## Instalasi

Clone repository di VPS (atau upload folder ke VPS), lalu:

```bash
cd pterodactyl-auto-installer
chmod +x install.sh scripts/*.sh
sudo bash install.sh
```

Installer akan meminta domain Panel dan email Let's Encrypt. Domain harus sudah resolve ke IP VPS sebelum meminta sertifikat.

Tahapan:
1. Memasang MariaDB dan Redis, membuat database khusus Panel dan menyimpan kredensial dengan izin file `0600` di `/root/.ptero-db.env`.
2. Mengunduh release Panel terbaru yang tag-nya `v1.*` dan bukan prerelease, memasang dependency, migrasi database, Nginx, queue worker, dan cron scheduler.
3. Meminta sertifikat Let's Encrypt melalui plugin Nginx.
4. Membuat file Egg Node.js 22.
5. Memasang Docker dan binary Wings 1.x. Wings menunggu Node dibuat di Panel sebelum dikonfigurasi.

## Membuat akun administrator

Setelah instalasi Panel:

```bash
cd /var/www/pterodactyl
sudo -u www-data php artisan p:user:make
```

Buka `https://DOMAIN_PANEL` dan login.

## Mengimpor Egg Node.js

Egg JSON dibuat di `eggs/nodejs-22.json`. Di Panel:
1. Masuk Admin > Nests.
2. Pilih nest yang sesuai atau buat nest baru (misalnya `Applications`).
3. Gunakan Import Egg dan pilih `nodejs-22.json`.
4. Periksa Docker image, startup command, dan variabel sebelum dipakai.

Egg ini memakai image `ghcr.io/parkervcp/yolks:nodejs_22`. Pastikan image dapat di-pull dan sesuai arsitektur node.

## Mengaktifkan Wings

1. Di Panel buka Admin > Nodes > Create New.
2. Masukkan FQDN node. Jika Panel dan Wings satu VPS, gunakan domain node terpisah (misalnya `node.example.com`) dan arahkan DNS ke VPS.
3. Aktifkan SSL untuk FQDN node bila memakai HTTPS pada Panel. Wings juga perlu sertifikat untuk domain node.
4. Tentukan memory, disk, daemon port (umumnya 8080), SFTP port (umumnya 2022), lalu simpan.
5. Buka tab Configuration > Generate Token.
6. Di VPS jalankan:

```bash
sudo bash scripts/wings.sh
```

Masukkan URL Panel HTTPS, Node ID, dan token Auto-Deploy saat diminta. Token tidak ditampilkan saat diketik. Jangan membagikan token atau file `/etc/pterodactyl/config.yml`.

Jika sertifikat TLS untuk domain node belum ada, terbitkan sertifikat terlebih dahulu dan pastikan Wings memakai konfigurasi SSL yang sesuai. Jangan menonaktifkan validasi TLS sebagai jalan pintas.

## Verifikasi

```bash
systemctl status nginx php8.3-fpm mariadb redis-server pteroq
systemctl status docker wings
```

Log:
```bash
journalctl -u pteroq -n 100 --no-pager
journalctl -u wings -n 100 --no-pager
tail -n 100 /var/www/pterodactyl/storage/logs/laravel-*.log
```

## Keamanan penting

- Jangan commit `.env`, `/root/.ptero-db.env`, token Auto-Deploy, private key SSL, atau `config.yml` Wings ke GitHub.
- Gunakan password administrator unik dan aktifkan 2FA.
- Batasi akses SSH, gunakan firewall provider/UFW sesuai port yang benar-benar dibutuhkan.
- Jangan membuka port database (3306) atau Redis (6379) ke internet.
- Buat backup database dan direktori data Wings secara rutin.
- Jangan menjalankan installer pada server produksi yang sudah memiliki Nginx/Database tanpa meninjau setiap perubahan.
- Script memilih release `v1.*` terbaru dari GitHub Releases API saat dijalankan; selalu tinjau release dan script sebelum eksekusi.
- Script tidak membuat Node secara otomatis karena konfigurasi Node dan token dibuat dari Panel.

## Referensi resmi

- Panel 1.x: https://docs.pterodactyl.io/v1/panel/getting-started
- Wings 1.x: https://docs.pterodactyl.io/v1/wings/installing
- SSL: https://docs.pterodactyl.io/v1/guides/tutorials/ssl-certificates
- Panel source: https://github.com/pterodactyl/panel
- Wings source: https://github.com/pterodactyl/wings
- Egg ecosystem: https://eggs.pterodactyl.io/

MIT License applies to this installer unless otherwise stated. Pterodactyl and third-party components retain their own licenses.
