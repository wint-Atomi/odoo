#!/bin/bash
# =============================================================
# Odoo System Healthcheck Script
# Chay tu dong qua cron moi 5 phut
# Gui canh bao qua Telegram khi phat hien su co
# =============================================================

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$DIR"

# Doc cau hinh tu .env
if [ -f "$DIR/.env" ]; then
    export $(grep -v '^#' "$DIR/.env" | grep -v '^$' | xargs)
fi

BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-}"
DOMAIN="${DOMAIN:-odoo.wint.io.vn}"
HOSTNAME=$(hostname)

# ------ Ham gui Telegram ------
send_telegram() {
    local message="$1"
    if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
        echo "[WARN] Chua cau hinh Telegram. Bo qua gui canh bao."
        echo "$message"
        return
    fi
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d parse_mode="HTML" \
        -d text="$message" > /dev/null 2>&1
}

ERRORS=""

# ------ 1. Kiem tra Odoo web ------
# Kiem tra cong khai qua domain voi co che tu dong thu lai (retry 2 lan, max 15s)
HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 15 --retry 2 --retry-delay 2 --retry-all-errors "https://$DOMAIN/web/login" 2>/dev/null)
HTTP_CODE="${HTTP_CODE: -3}"
HTTP_CODE="${HTTP_CODE:-000}"

if [ "$HTTP_CODE" != "200" ]; then
    # Neu mang ngoai bi loi/timeout, kiem tra ngay noi bo localhost de xac minh Odoo co thuc su chet khong
    LOCAL_HTTP=$(curl -sk -o /dev/null -w "%{http_code}" --connect-timeout 3 --max-time 5 -H "Host: $DOMAIN" "https://127.0.0.1/web/login" 2>/dev/null)
    LOCAL_HTTP="${LOCAL_HTTP: -3}"
    LOCAL_HTTP="${LOCAL_HTTP:-000}"

    if [ "$LOCAL_HTTP" == "200" ]; then
        echo "[WARN] Mang cong khai/Cloudflare cham (HTTP $HTTP_CODE), nhung Odoo noi bo van 200 OK."
    else
        ERRORS="${ERRORS}\n- Odoo web tra ve HTTP $HTTP_CODE (noi bo: $LOCAL_HTTP, can 200)"
    fi
fi

# ------ 2. Kiem tra container dang chay ------
for CONTAINER in odoo-web odoo-web-2 odoo-db odoo-nginx; do
    STATUS=$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null || echo "false")
    if [ "$STATUS" != "true" ]; then
        ERRORS="${ERRORS}\n- Container $CONTAINER khong chay!"
    fi
done

# ------ 3. Kiem tra PostgreSQL ------
DB_CHECK=$(docker exec odoo-db pg_isready -U odoo 2>/dev/null || echo "FAIL")
if [[ "$DB_CHECK" != *"accepting connections"* ]]; then
    ERRORS="${ERRORS}\n- PostgreSQL khong tiep nhan ket noi!"
fi

# ------ 4. Kiem tra dung luong o dia ------
DISK_USAGE=$(df / --output=pcent | tail -1 | tr -d ' %')
if [ "$DISK_USAGE" -gt 80 ]; then
    ERRORS="${ERRORS}\n- O dia da su dung ${DISK_USAGE}% (nguong canh bao: 80%)"
fi

# ------ 5. Kiem tra SSL certificate ------
SSL_EXPIRY=$(openssl x509 -in /etc/letsencrypt/live/$DOMAIN/fullchain.pem -noout -enddate 2>/dev/null | cut -d= -f2)
if [ -n "$SSL_EXPIRY" ]; then
    EXPIRY_EPOCH=$(date -d "$SSL_EXPIRY" +%s 2>/dev/null || echo "0")
    NOW_EPOCH=$(date +%s)
    DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))
    if [ "$DAYS_LEFT" -lt 14 ]; then
        ERRORS="${ERRORS}\n- Chung chi SSL con $DAYS_LEFT ngay het han!"
    fi
fi

# ------ 6. Kiem tra updater daemon ------
UPDATER_STATUS=$(systemctl is-active odoo-updater 2>/dev/null || echo "inactive")
if [ "$UPDATER_STATUS" != "active" ]; then
    ERRORS="${ERRORS}\n- Dich vu odoo-updater khong hoat dong!"
fi

# ------ Gui ket qua ------
if [ -n "$ERRORS" ]; then
    MSG="<b>[CANH BAO] Odoo ($HOSTNAME)</b>

Phat hien su co luc $(date '+%d/%m/%Y %H:%M'):
$(echo -e "$ERRORS")"
    send_telegram "$MSG"
    echo "[ALERT] Da phat hien su co va gui canh bao Telegram."
    echo -e "$ERRORS"
    exit 1
fi

echo "[OK] He thong binh thuong - $(date '+%d/%m/%Y %H:%M:%S')"
