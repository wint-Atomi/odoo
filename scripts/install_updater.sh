#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$DIR/.." && pwd )"
cd "$DIR"

echo "=========================================="
echo "Cai dat Odoo Updater Service tren VPS"
echo "=========================================="

git config core.fileMode false
chmod +x update.sh
chmod +x updater.py

# Tao service file cho systemd voi duong dan dong
cat << EOF > /etc/systemd/system/odoo-updater.service
[Unit]
Description=Odoo GitHub Auto-Updater Daemon
After=network.target docker.service

[Service]
Type=simple
User=root
WorkingDirectory=$REPO_ROOT
EnvironmentFile=$REPO_ROOT/.env
ExecStart=/usr/bin/python3 $DIR/updater.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Reload va kich hoat systemd service
systemctl daemon-reload
systemctl enable odoo-updater
systemctl restart odoo-updater

echo "=========================================="
echo "Kiem tra trang thai dich vu:"
systemctl is-active odoo-updater && echo "Service odoo-updater dang HOAT DONG!" || echo "Service chua chay!"
echo "=========================================="
echo "Tu bay gio, ban co the bam nut 'Cap nhat ngay tu GitHub' truc tiep trong Cai dat cua Odoo!"
