#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
if [ -f "$DIR/.env" ]; then
    export $(grep -v '^#' "$DIR/.env" | grep -v '^$' | xargs)
fi

DOMAIN="${DOMAIN:-odoo.example.com}"
EMAIL="${CERTBOT_EMAIL:-admin@example.com}"

echo "=========================================================="
echo "  TRIỂN KHAI ODOO PRODUCTION CHO DOMAIN: $DOMAIN"
echo "=========================================================="

# 1. Cài đặt Certbot nếu chưa có
if ! command -v certbot &> /dev/null; then
    echo "[1/4] Đang cài đặt Certbot..."
    apt update && apt install -y certbot
else
    echo "[1/4] Certbot đã được cài đặt."
fi

# 2. Lấy chứng chỉ SSL Let's Encrypt
echo "[2/4] Đang kiểm tra và cấp chứng chỉ SSL Let's Encrypt..."
if [ ! -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    # Tạm dừng nginx container nếu đang chạy để nhả port 80 cho certbot
    docker stop odoo-nginx 2>/dev/null || true
    
    certbot certonly --standalone \
        -d "$DOMAIN" \
        --non-interactive \
        --agree-tos \
        -m "$EMAIL"
    echo ">> Cấp chứng chỉ SSL thành công!"
else
    echo ">> Chứng chỉ SSL cho $DOMAIN đã tồn tại sẵn, bỏ qua bước cấp mới."
fi

# 3. Phân quyền và chuẩn bị
echo "[3/4] Chuẩn bị thư mục và quyền truy cập..."
mkdir -p addons config nginx
mkdir -p /home/storage/odoo
chmod -R 777 /home/storage/odoo

# 4. Khởi chạy Docker Compose Production
echo "[4/4] Đang khởi động các dịch vụ Odoo, PostgreSQL, Nginx..."
docker compose -f docker-compose.prod.yml up -d

echo ""
echo "=========================================================="
echo "  TRIỂN KHAI HOÀN TẤT!"
echo "  Truy cập ngay: https://$DOMAIN"
echo "=========================================================="
