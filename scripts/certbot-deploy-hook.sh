#!/bin/bash
# =============================================================
# Certbot Deploy Hook
# Tu dong reload Nginx sau khi SSL certificate duoc gia han
# Cai dat: certbot renew --deploy-hook "/home/odoo/scripts/certbot-deploy-hook.sh"
# =============================================================

echo "[$(date)] SSL certificate da duoc gia han. Dang reload Nginx..."
docker exec odoo-nginx nginx -s reload 2>/dev/null && \
    echo "[$(date)] Nginx da reload thanh cong." || \
    echo "[$(date)] [ERROR] Khong the reload Nginx!"
