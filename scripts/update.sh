#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$DIR"

echo "=========================================="
echo "Bat dau cap nhat Odoo: $(date)"
echo "=========================================="

# 1. Keo code moi nhat tu GitHub
echo "1. Dang keo code moi tu GitHub (origin main)..."
git config core.fileMode false
git fetch origin main
git reset --hard origin/main

# 2. Dong bo container va tao web2 neu chua ton tai
echo "2. Dong bo trang thai container..."
docker compose -f docker-compose.prod.yml up -d --remove-orphans

# 3. Tim database Odoo dang hoat dong
echo "3. Kiem tra database Odoo..."
DB_NAME=$(docker compose -f docker-compose.prod.yml exec -T db psql -U odoo -d postgres -tAc "SELECT datname FROM pg_database WHERE datname NOT IN ('postgres') AND datistemplate = false LIMIT 1;" 2>/dev/null || true)

if [ -n "$DB_NAME" ]; then
    echo "-> Da tim thay database: '$DB_NAME'"
    CUSTOM_MODULES=$(ls -d addons/*/ 2>/dev/null | xargs -n 1 basename | paste -sd, -)
    MODULES_TO_UPGRADE="${CUSTOM_MODULES:-wint_hr_onboarding}"
    echo "-> Tu dong nang cap cac module: '$MODULES_TO_UPGRADE'..."
    docker compose -f docker-compose.prod.yml exec -T web odoo -u "$MODULES_TO_UPGRADE" -d "$DB_NAME" --no-http --stop-after-init || true
else
    echo "-> Khong tim thay ten database, bo qua buoc nang cap tu dong qua CLI."
fi

# 4. Khoi dong lai tuan tu (Zero-Downtime Rolling Restart)
echo "4. Khoi dong lai tuan tu cac container Odoo..."

# 4.1 Restart container web (odoo-web)
echo "-> [1/2] Dang khoi dong lai container web..."
docker compose -f docker-compose.prod.yml restart web

echo "-> Cho container web san sang phuc vu..."
for i in $(seq 1 30); do
    if docker compose -f docker-compose.prod.yml exec -T web python3 -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8069/web/health', timeout=3)" >/dev/null 2>&1; then
        echo "-> Container web da san sang!"
        break
    fi
    sleep 2
done

# 4.2 Restart container web2 (odoo-web-2)
echo "-> [2/2] Dang khoi dong lai container web2..."
docker compose -f docker-compose.prod.yml restart web2

echo "-> Cho container web2 san sang phuc vu..."
for i in $(seq 1 30); do
    if docker compose -f docker-compose.prod.yml exec -T web2 python3 -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8069/web/health', timeout=3)" >/dev/null 2>&1; then
        echo "-> Container web2 da san sang!"
        break
    fi
    sleep 2
done

# 4.3 Reload Nginx de dong bo upstream sach
echo "-> Reload Nginx..."
docker compose -f docker-compose.prod.yml exec -T nginx nginx -s reload || true

echo "=========================================="
echo "Cap nhat hoan tat thanh cong: $(date)"
echo "=========================================="
