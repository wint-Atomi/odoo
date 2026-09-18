# Kien truc He thong

## Tong quan

He thong Odoo 17 chay tren VPS Ubuntu 24.04, su dung Docker Compose de quan ly cac dich vu.
Kien truc 2-container Odoo cho phep cap nhat khong gian doan (zero-downtime rolling restart).

## So do kien truc

```text
                    Internet
                       |
                  [Cloudflare CDN]
                       |
               [VPS: <YOUR_VPS_IP>]
                       |
            +-----[Nginx Container]-----+
            |     (odoo-nginx)          |
            |     Port 80/443           |
            |     SSL Termination       |
            +-----|------------|--------+
                  |            |
         +-------v---+  +-----v------+
         | Odoo Web  |  | Odoo Web2  |
         | (odoo-web)|  | (odoo-web-2)|
         | Port 8069 |  | Port 8069  |
         +-----+-----+  +------+-----+
               |               |
               +-------+-------+
                       |
              +--------v--------+
              | PostgreSQL 16   |
              | (odoo-db)       |
              | Port 5432       |
              +-----------------+
                       |
              [Docker Volume:   ]
              [odoo-db-data     ]

    +--------------------------------------------------+
    | /home/storage/odoo/  (bind mount, chia se 2 web)  |
    |  - filestore/  (anh, tai lieu dinh kem)           |
    |  - sessions/   (phien dang nhap)                  |
    |  - addons/     (module tu cai dat tu Odoo Store)  |
    +--------------------------------------------------+

    +--------------------------------------------------+
    | Updater Daemon (systemd, port 9999)               |
    |  - Nhan lenh kiem tra/cap nhat tu giao dien Odoo  |
    |  - Chay update.sh: git pull + rolling restart     |
    +--------------------------------------------------+
```

## Cac thanh phan chinh

### 1. Nginx Reverse Proxy (odoo-nginx)
- Tiep nhan toan bo luu luong HTTP/HTTPS tu internet
- Ket thuc SSL (Let's Encrypt certificate)
- Phan phoi tai (load balance) giua 2 container Odoo
- Chuyen tiep WebSocket cho Odoo Discuss/Chat
- Chan truy cap /web/database tu internet
- Cache file tinh CSS/JS

### 2. Odoo Web (odoo-web, odoo-web-2)
- 2 container chay song song, dung chung database va filestore
- Rolling restart: khi cap nhat, restart tung container mot
- `extra_hosts: host.docker.internal` cho phep goi Updater daemon tren host

### 3. PostgreSQL 16 (odoo-db)
- Database chinh, luu tru toan bo du lieu Odoo
- Du lieu luu trong Docker Volume `odoo-db-data`
- Cau hinh toi uu: shared_buffers=1GB, effective_cache_size=3GB

### 4. Updater Daemon (odoo-updater)
- Chay tren host (systemd service), lang nghe port 9999
- API endpoints:
  - `GET /health` - Kiem tra dich vu
  - `GET /check-update` - Kiem tra commit moi tren GitHub
  - `POST /update` - Keo code moi va rolling restart
- Xac thuc bang token `X-Update-Token`

### 5. Cloudflare CDN
- DNS proxy, che giau IP VPS thuc
- Cache tai nguyen tinh, bao ve DDoS
- Domain: odoo.wint.io.vn

## Mang Docker noi bo

```text
Docker Network (odoo_default):
  - odoo-web:     172.x.x.2
  - odoo-web-2:   172.x.x.3
  - odoo-db:      172.x.x.4
  - odoo-nginx:   172.x.x.5

Host Network:
  - docker0:      172.17.0.1 (host.docker.internal)
  - Updater:      0.0.0.0:9999
```

## Luong cap nhat code

```text
1. Developer push code len GitHub (branch main)
2. Admin bam "Cap nhat ngay tu GitHub" tren giao dien Odoo Settings
3. Odoo goi HTTP POST den host.docker.internal:9999/update
4. Updater daemon nhan lenh, chay update.sh:
   a. git fetch origin main && git reset --hard origin/main
   b. docker compose up -d (dong bo container)
   c. odoo -u <modules> -d wint-odoo --stop-after-init (upgrade module)
   d. Rolling restart: web -> cho san sang -> web2 -> cho san sang
   e. Nginx reload
5. He thong cap nhat xong, khong gian doan
```

## Luu tru du lieu

| Duong dan | Noi dung | Backup |
|-----------|---------|--------|
| Docker Volume `odoo-db-data` | Database PostgreSQL | backup.sh (cron 3:00 AM) |
| /home/storage/odoo/filestore/ | Anh, tai lieu dinh kem | Khong (tai tao duoc) |
| /home/storage/odoo/sessions/ | Phien dang nhap | Khong (tam thoi) |
| /home/odoo/ (git repo) | Code va cau hinh | GitHub |
| /home/backup/odoo/ | File backup .sql.gz | Giu 7 ban moi nhat |
| /etc/letsencrypt/ | Chung chi SSL | Certbot tu tao lai |
