# Odoo 17 Production - WinT Group

He thong Odoo 17 Production chay tren Ubuntu Server voi Docker Compose,
Nginx Reverse Proxy (SSL), PostgreSQL 16, zero-downtime rolling restart,
va tu dong cap nhat tu GitHub.

## Cau truc du an

```text
odoo/
+-- .env.example              # Mau cau hinh mat khau (copy thanh .env)
+-- docker-compose.prod.yml   # Dich vu production (Odoo x2, DB, Nginx)
+-- docker-compose.yml        # Dich vu dev local
+-- config/
|   +-- odoo.conf             # Cau hinh Odoo (workers, memory limits)
|   +-- favicon.ico           # Icon trang web
+-- nginx/
|   +-- nginx.conf            # Nginx reverse proxy, SSL, load balancing
+-- addons/                   # Module custom
|   +-- wint_hr_onboarding/   # Auto onboarding + Cloudflare email
+-- scripts/
|   +-- setup.sh              # Cai dat lan dau tren VPS moi
|   +-- update.sh             # Cap nhat code + rolling restart
|   +-- updater.py            # HTTP daemon cho auto-update tu Odoo UI
|   +-- backup.sh             # Backup database tu dong (cron 3:00 AM)
|   +-- restore.sh            # Phuc hoi database tu backup
|   +-- migrate.sh            # Chuyen he thong sang VPS moi
|   +-- healthcheck.sh        # Kiem tra suc khoe + canh bao Telegram
|   +-- install_updater.sh    # Cai dat updater systemd service
|   +-- install_ssh_notify.sh # Cai dat thong bao SSH qua Telegram
|   +-- certbot-deploy-hook.sh # Reload Nginx sau khi SSL renew
|   +-- uninstall.sh          # Go bo he thong
+-- docs/                     # Tai lieu van hanh day du
    +-- architecture.md       # Kien truc he thong
    +-- operations.md         # Huong dan van hanh
    +-- disaster-recovery.md  # Phuc hoi su co
    +-- development.md        # Huong dan phat trien module
```

## Cai dat lan dau (VPS moi)

```bash
# 1. Clone repository
git clone https://github.com/Win-tenh/odoo /home/odoo
cd /home/odoo

# 2. Tao file cau hinh mat khau
cp .env.example .env
nano .env

# 3. Chay setup tu dong
bash scripts/setup.sh

# 4. Cai dat dich vu phu tro
bash scripts/install_updater.sh
bash scripts/install_ssh_notify.sh

# 5. Dat cron backup + healthcheck
chmod +x scripts/backup.sh scripts/healthcheck.sh scripts/certbot-deploy-hook.sh
(crontab -l 2>/dev/null; echo "0 3 * * * /home/odoo/scripts/backup.sh >> /home/odoo/scripts/backup.log 2>&1") | sort -u | crontab -
(crontab -l 2>/dev/null; echo "*/5 * * * * /home/odoo/scripts/healthcheck.sh >> /dev/null 2>&1") | sort -u | crontab -
```

## Cap nhat he thong

- **Tu Odoo UI:** Settings > Cap nhat he thong > Bam "Cap nhat ngay tu GitHub"
- **Tu SSH:** `cd /home/odoo && bash scripts/update.sh`

## Backup / Restore

- **Backup tu dong:** Moi ngay luc 3:00 AM, giu 7 ban moi nhat
- **Backup thu cong:** `bash scripts/backup.sh`
- **Restore:** `bash scripts/restore.sh`

## Tai lieu chi tiet

Xem thu muc [docs/](docs/README.md) de doc huong dan van hanh, kien truc, phuc hoi su co, va phat trien module.
