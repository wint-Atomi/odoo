#!/usr/bin/env bash
set -e

DOMAIN="odoo.wint.io.vn"

echo "=========================================================="
echo "  GỠ CÀI ĐẶT ODOO PRODUCTION ($DOMAIN)"
echo "=========================================================="
echo "Cảnh báo: Thao tác này sẽ dừng toàn bộ dịch vụ Odoo, PostgreSQL, Nginx."
read -p "Bạn có chắc chắn muốn tiếp tục không? (y/N): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Đã hủy thao tác."
    exit 0
fi

# 1. Dừng và gỡ bỏ các container
echo ""
echo "[1/3] Đang dừng và gỡ các container..."
docker compose -f docker-compose.prod.yml down

# 2. Tùy chọn xóa dữ liệu (Docker Volumes)
echo ""
echo "----------------------------------------------------------"
read -p "Bạn có muốn XÓA HOÀN TOÀN CSDL và các tệp đính kèm không? (y/N): " PURGE_DATA
if [[ "$PURGE_DATA" == "y" || "$PURGE_DATA" == "Y" ]]; then
    echo ">> Đang xóa sạch Docker volumes và tệp lưu trữ..."
    docker compose -f docker-compose.prod.yml down -v
    rm -rf /home/storage/odoo/*
    echo ">> Toàn bộ dữ liệu CSDL và tệp /home/storage/odoo đã được xóa sạch."
else
    echo ">> Đã giữ lại dữ liệu CSDL (Docker Volumes an toàn, có thể bật lại sau)."
fi

# 3. Tùy chọn xóa chứng chỉ SSL
echo ""
echo "----------------------------------------------------------"
read -p "Bạn có muốn XÓA chứng chỉ SSL Let's Encrypt của $DOMAIN không? (y/N): " DELETE_SSL
if [[ "$DELETE_SSL" == "y" || "$DELETE_SSL" == "Y" ]]; then
    if command -v certbot &> /dev/null; then
        echo ">> Đang xóa chứng chỉ SSL..."
        certbot delete --cert-name "$DOMAIN" --non-interactive || true
    fi
else
    echo ">> Giữ lại chứng chỉ SSL."
fi

echo ""
echo "=========================================================="
echo "  GỠ BỎ HOÀN TẤT!"
echo "=========================================================="
