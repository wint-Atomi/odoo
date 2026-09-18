#!/bin/bash
# =============================================================
# Odoo Database Restore Script
# Su dung: bash scripts/restore.sh [ten_file_backup]
# Neu khong truyen tham so, se tu dong chon ban backup moi nhat
# =============================================================
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$DIR"

BACKUP_DIR="/home/backup/odoo"

# Xac dinh file backup
if [ -n "$1" ]; then
    BACKUP_FILE="$1"
    if [ ! -f "$BACKUP_FILE" ]; then
        BACKUP_FILE="$BACKUP_DIR/$1"
    fi
else
    echo "Cac ban backup hien co:"
    echo "---"
    ls -lhrt "$BACKUP_DIR"/*.sql.gz 2>/dev/null || { echo "Khong tim thay ban backup nao!"; exit 1; }
    echo "---"
    BACKUP_FILE=$(ls -1t "$BACKUP_DIR"/*.sql.gz 2>/dev/null | head -1)
    echo ""
    echo "Se su dung ban backup moi nhat: $(basename $BACKUP_FILE)"
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "[ERROR] Khong tim thay file: $BACKUP_FILE"
    exit 1
fi

# Tim ten database
DB_NAME=$(docker compose -f docker-compose.prod.yml exec -T db psql -U odoo -d postgres -tAc \
  "SELECT datname FROM pg_database WHERE datname NOT IN ('postgres') AND datistemplate = false LIMIT 1;" 2>/dev/null || true)

if [ -z "$DB_NAME" ]; then
    # Lay ten tu file backup (format: dbname_YYYYMMDD_HHMMSS.sql.gz)
    DB_NAME=$(basename "$BACKUP_FILE" | sed 's/_[0-9]\{8\}_[0-9]\{6\}\.sql\.gz$//')
    echo "Khong tim thay database hien tai, se tao moi: '$DB_NAME'"
fi

echo ""
echo "=========================================="
echo "  PHUC HOI DATABASE TU BACKUP"
echo "=========================================="
echo "File backup : $(basename $BACKUP_FILE) ($(du -h "$BACKUP_FILE" | cut -f1))"
echo "Database    : $DB_NAME"
echo ""
echo "[CANH BAO] Thao tac nay se XOA TOAN BO du lieu hien tai trong database '$DB_NAME'"
echo "           va thay the bang du lieu tu file backup!"
echo ""
read -p "Ban co chac chan muon tiep tuc? (y/N): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Da huy thao tac."
    exit 0
fi

# Dung cac container Odoo de giai phong ket noi database
echo ""
echo "[1/4] Dang dung cac container Odoo..."
docker compose -f docker-compose.prod.yml stop web web2

# Huy ket noi con ton dong va xoa database cu
echo "[2/4] Dang xoa database cu '$DB_NAME'..."
docker compose -f docker-compose.prod.yml exec -T db psql -U odoo -d postgres -c \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();" > /dev/null 2>&1 || true
docker compose -f docker-compose.prod.yml exec -T db dropdb -U odoo "$DB_NAME" 2>/dev/null || true

# Tao database moi va restore
echo "[3/4] Dang tao database moi va phuc hoi du lieu..."
docker compose -f docker-compose.prod.yml exec -T db createdb -U odoo "$DB_NAME"
gunzip -c "$BACKUP_FILE" | docker compose -f docker-compose.prod.yml exec -T db psql -U odoo "$DB_NAME" > /dev/null 2>&1

# Khoi dong lai
echo "[4/4] Dang khoi dong lai cac container Odoo..."
docker compose -f docker-compose.prod.yml start web web2

echo ""
echo "=========================================="
echo "  PHUC HOI HOAN TAT!"
echo "  Database '$DB_NAME' da duoc restore tu $(basename $BACKUP_FILE)"
echo "=========================================="
