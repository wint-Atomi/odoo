#!/bin/bash
# =============================================================
# SSH Login Notification via Telegram
# Cai dat: bash scripts/install_ssh_notify.sh
# Gui canh bao Telegram moi khi co phien SSH dang nhap vao VPS
# =============================================================
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# Doc cau hinh tu .env
if [ -f "$DIR/.env" ]; then
    export $(grep -v '^#' "$DIR/.env" | grep -v '^$' | xargs)
fi

BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-}"

if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    echo "[ERROR] Chua cau hinh TELEGRAM_BOT_TOKEN va TELEGRAM_CHAT_ID trong .env"
    exit 1
fi

# Tao script thong bao SSH
NOTIFY_SCRIPT="/usr/local/bin/ssh-login-notify.sh"
cat > "$NOTIFY_SCRIPT" << 'SCRIPT_EOF'
#!/bin/bash
# Chi gui thong bao khi co phien interactive (login shell)
if [ "$PAM_TYPE" != "open_session" ]; then
    exit 0
fi

# Chong spam / duplicate tin nhan khi client (nhu MobaXterm) mo dong thoi 2 session (Terminal + SFTP)
SAFE_IP=$(echo "${PAM_RHOST:-unknown}" | tr -cd '[:alnum:]_')
SAFE_USER=$(echo "${PAM_USER:-unknown}" | tr -cd '[:alnum:]_')
LOCK_BASE="/tmp/ssh_notify_${SAFE_USER}_${SAFE_IP}"

exec 200>"${LOCK_BASE}.lock"
flock -n 200 || exit 0

NOW=$(date +%s)
if [ -f "${LOCK_BASE}.ts" ]; then
    LAST_TS=$(cat "${LOCK_BASE}.ts" 2>/dev/null || echo 0)
    DIFF=$((NOW - LAST_TS))
    if [ "$DIFF" -ge 0 ] && [ "$DIFF" -lt 10 ]; then
        flock -u 200
        exit 0
    fi
fi
echo "$NOW" > "${LOCK_BASE}.ts"
flock -u 200

BOT_TOKEN="__BOT_TOKEN__"
CHAT_ID="__CHAT_ID__"

IP_INFO=""
if [ -n "$PAM_RHOST" ]; then
    IP_INFO="IP: $PAM_RHOST"
fi

MSG="<b>[SSH LOGIN]</b> $(hostname)

User: <code>$PAM_USER</code>
$IP_INFO
Thoi gian: $(date '+%d/%m/%Y %H:%M:%S')
TTY: ${PAM_TTY:-N/A}"

curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d parse_mode="HTML" \
    -d text="$MSG" > /dev/null 2>&1 &
SCRIPT_EOF

# Thay the placeholder bang gia tri thuc
sed -i "s|__BOT_TOKEN__|$BOT_TOKEN|g" "$NOTIFY_SCRIPT"
sed -i "s|__CHAT_ID__|$CHAT_ID|g" "$NOTIFY_SCRIPT"
chmod +x "$NOTIFY_SCRIPT"

# Them vao PAM (neu chua co)
PAM_SSHD="/etc/pam.d/sshd"
HOOK_LINE="session optional pam_exec.so seteuid $NOTIFY_SCRIPT"
if ! grep -qF "$NOTIFY_SCRIPT" "$PAM_SSHD" 2>/dev/null; then
    echo "$HOOK_LINE" >> "$PAM_SSHD"
    echo "[OK] Da them SSH login notification vao PAM."
else
    echo "[OK] SSH login notification da duoc cau hinh truoc do."
fi

echo "[OK] Moi phien SSH dang nhap se gui thong bao den Telegram."
