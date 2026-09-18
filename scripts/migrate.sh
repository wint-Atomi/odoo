#!/bin/bash
# =============================================================
# Odoo VPS Migration Script
# Chay tren VPS MOI de khoi phuc he thong tu backup
#
# Yeu cau:
#   - VPS moi da cai Docker va Docker Compose
#   - Da copy file backup (.sql.gz) sang VPS moi
#
# Su dung:
#   1. Clone repo:  git clone https://github.com/Win-tenh/odoo /home/odoo
#   2. Copy backup:  scp user@old-vps:/home/backup/odoo/latest.sql.gz /home/backup/odoo/
#   3. Tao .env:    cp .env.example .env && nano .env
#   4. Chay script:  bash scripts/migrate.sh /home/backup/odoo/latest.sql.gz
# =============================================================
set -e

BACKUP_FILE="$1"
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$DIR"

if [ -z "$BACKUP_FILE" ]; then
    echo "Su dung: bash scripts/migrate.sh <duong_dan_file_backup.sql.gz>"
    echo ""
    echo "Vi du: bash scripts/migrate.sh /home/backup/odoo/wint-odoo_20260917_030000.sql.gz"
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "[ERROR] Khong tim thay file backup: $BACKUP_FILE"
    exit 1
fi

if [ ! -f "$DIR/.env" ]; then
    echo "[ERROR] Chua tao file .env! Chay truoc: cp .env.example .env && nano .env"
    exit 1
fi

echo "=========================================="
echo "  MIGRATE ODOO SANG VPS MOI"
echo "=========================================="
echo "File backup: $BACKUP_FILE"
echo ""

# 1. Chay setup co ban (SSL, thu muc, Docker)
echo "[1/6] Chay setup co ban..."
bash scripts/setup.sh

# 2. Cho database san sang
echo "[2/6] Cho database PostgreSQL san sang..."
sleep 10
for i in $(seq 1 30); do
    if docker compose -f docker-compose.prod.yml exec -T db pg_isready -U odoo > /dev/null 2>&1; then
        echo "-> PostgreSQL da san sang!"
        break
    fi
    echo "-> Cho PostgreSQL khoi dong... ($i/30)"
    sleep 3
done

# 3. Dung Odoo containers
echo "[3/6] Dung Odoo containers de restore..."
docker compose -f docker-compose.prod.yml stop web web2

# 4. Lay ten database tu file backup
DB_NAME=$(basename "$BACKUP_FILE" | sed 's/_[0-9]\{8\}_[0-9]\{6\}\.sql\.gz$//')
echo "[4/6] Tao database '$DB_NAME' va restore du lieu..."
docker compose -f docker-compose.prod.yml exec -T db createdb -U odoo "$DB_NAME" 2>/dev/null || true
gunzip -c "$BACKUP_FILE" | docker compose -f docker-compose.prod.yml exec -T db psql -U odoo "$DB_NAME" > /dev/null 2>&1

# 5. Khoi dong lai
echo "[5/6] Khoi dong lai cac container Odoo..."
docker compose -f docker-compose.prod.yml up -d

# 6. Cai dat cac dich vu phu tro
echo "[6/6] Cai dat Updater daemon va SSH notification..."
bash scripts/install_updater.sh
bash scripts/install_ssh_notify.sh

# Dat cron backup + healthcheck
chmod +x scripts/backup.sh scripts/healthcheck.sh scripts/certbot-deploy-hook.sh
(crontab -l 2>/dev/null; echo "0 3 * * * /home/odoo/scripts/backup.sh >> /home/odoo/scripts/backup.log 2>&1") | sort -u | crontab -
(crontab -l 2>/dev/null; echo "*/5 * * * * /home/odoo/scripts/healthcheck.sh >> /dev/null 2>&1") | sort -u | crontab -

# Dang ky certbot deploy hook
certbot renew --deploy-hook "/home/odoo/scripts/certbot-deploy-hook.sh" --dry-run 2>/dev/null || true

echo ""
echo "=========================================="
echo "  MIGRATE HOAN TAT!"
echo "  Database '$DB_NAME' da duoc phuc hoi."
echo "  Truy cap: https://odoo.wint.io.vn"
echo "=========================================="
