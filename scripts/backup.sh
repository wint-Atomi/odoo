#!/bin/bash
# =============================================================
# Odoo Database Backup Script
# Chay tu dong qua cron hoac thu cong: bash scripts/backup.sh
# =============================================================
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$DIR"

BACKUP_DIR="/home/backup/odoo"
MAX_BACKUPS=7
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Doc ten database tu PostgreSQL
DB_NAME=$(docker compose -f docker-compose.prod.yml exec -T db psql -U odoo -d postgres -tAc \
  "SELECT datname FROM pg_database WHERE datname NOT IN ('postgres') AND datistemplate = false LIMIT 1;" 2>/dev/null || true)

if [ -z "$DB_NAME" ]; then
    echo "[ERROR] Khong tim thay database Odoo de backup!"
    exit 1
fi

# Tao thu muc backup
mkdir -p "$BACKUP_DIR"

BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.sql.gz"

echo "=== Bat dau backup database '$DB_NAME' ==="
echo "Thoi gian: $(date)"
echo "File: $BACKUP_FILE"

# Dump database va nen bang gzip
docker compose -f docker-compose.prod.yml exec -T db pg_dump -U odoo "$DB_NAME" | gzip > "$BACKUP_FILE"

# Kiem tra file backup hop le
if [ ! -s "$BACKUP_FILE" ]; then
    echo "[ERROR] File backup rong hoac bi loi!"
    rm -f "$BACKUP_FILE"
    exit 1
fi

FILE_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "=== Backup thanh cong: $FILE_SIZE ==="

# Xoa cac ban backup cu, chi giu lai $MAX_BACKUPS ban moi nhat
BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/*.sql.gz 2>/dev/null | wc -l)
if [ "$BACKUP_COUNT" -gt "$MAX_BACKUPS" ]; then
    DELETE_COUNT=$((BACKUP_COUNT - MAX_BACKUPS))
    echo "Dang xoa $DELETE_COUNT ban backup cu..."
    ls -1t "$BACKUP_DIR"/*.sql.gz | tail -n "$DELETE_COUNT" | xargs rm -f
fi

echo "Hien co $(ls -1 "$BACKUP_DIR"/*.sql.gz 2>/dev/null | wc -l)/$MAX_BACKUPS ban backup."
echo "=== Hoan tat ==="
