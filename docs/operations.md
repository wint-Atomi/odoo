# Huong dan Van hanh

## Muc luc

- [Ket noi SSH vao VPS](#ket-noi-ssh-vao-vps)
- [Kiem tra trang thai he thong](#kiem-tra-trang-thai-he-thong)
- [Cap nhat code tu GitHub](#cap-nhat-code-tu-github)
- [Backup database](#backup-database)
- [Restore database](#restore-database)
- [Khoi dong lai dich vu](#khoi-dong-lai-dich-vu)
- [Xem log](#xem-log)
- [Quan ly SSL certificate](#quan-ly-ssl-certificate)
- [Quan ly database](#quan-ly-database)

---

## Ket noi SSH vao VPS

```bash
# Tu may tinh ca nhan (da cau hinh SSH alias)
ssh <YOUR_SSH_ALIAS>

# Hoac ket noi truc tiep
ssh -p <YOUR_SSH_PORT> root@<YOUR_VPS_IP>
```

Moi phien SSH se tu dong gui thong bao den Telegram bot @odoo_noti_bot.

---

## Kiem tra trang thai he thong

### Kiem tra nhanh toan bo container
```bash
cd /home/odoo
docker compose -f docker-compose.prod.yml ps
```

### Kiem tra suc khoe he thong (chay healthcheck thu cong)
```bash
bash scripts/healthcheck.sh
```

### Kiem tra tung dich vu
```bash
# Odoo web
curl -sk https://odoo.wint.io.vn/web/login -o /dev/null -w "HTTP %{http_code}\n"

# PostgreSQL
docker exec odoo-db pg_isready -U odoo

# Nginx
docker exec odoo-nginx nginx -t

# Updater daemon
systemctl status odoo-updater
curl http://127.0.0.1:9999/health
```

### Kiem tra tai nguyen VPS
```bash
# O dia
df -h /

# RAM
free -h

# CPU va tien trinh
htop   # hoac: top
```

---

## Cap nhat code tu GitHub

### Cach 1: Tu giao dien Odoo (khuyen dung)
1. Dang nhap Odoo voi tai khoan admin
2. Vao **Settings** (Cai dat)
3. Cuon xuong phan **Cap nhat he thong (GitHub Auto-Update)**
4. Bam **"Kiem tra ban cap nhat"** de xem co commit moi khong
5. Bam **"Cap nhat ngay tu GitHub"** de ap dung

### Cach 2: Tu SSH (khi can cap nhat thu cong)
```bash
cd /home/odoo
bash scripts/update.sh
```

### Cach 3: Chi pull code (khong restart)
```bash
cd /home/odoo
git pull origin main
```

---

## Backup database

### Backup thu cong
```bash
cd /home/odoo
bash scripts/backup.sh
```

### Kiem tra cac ban backup hien co
```bash
ls -lh /home/backup/odoo/
```

### Backup tu dong
- Cron chay moi ngay luc 3:00 AM
- Giu toi da 7 ban, tu dong xoa ban cu nhat
- Kiem tra cron: `crontab -l`

---

## Restore database

```bash
cd /home/odoo

# Restore ban moi nhat
bash scripts/restore.sh

# Hoac chi dinh file cu the
bash scripts/restore.sh /home/backup/odoo/wint-odoo_20260917_030000.sql.gz
```

**Luu y:** Script se hoi xac nhan truoc khi xoa database cu. Toan bo du lieu hien tai se bi thay the.

---

## Khoi dong lai dich vu

### Khoi dong lai toan bo (nhanh, co gian doan ~30 giay)
```bash
cd /home/odoo
docker compose -f docker-compose.prod.yml restart
```

### Rolling restart (khong gian doan)
```bash
cd /home/odoo
bash scripts/update.sh
```

### Khoi dong lai tung container
```bash
docker restart odoo-web
docker restart odoo-web-2
docker restart odoo-db
docker restart odoo-nginx
```

### Khoi dong lai Updater daemon
```bash
systemctl restart odoo-updater
```

### Tat va bat lai toan bo
```bash
cd /home/odoo
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml up -d
```

---

## Xem log

### Log Odoo (realtime)
```bash
# Container web chinh
docker logs -f --tail 50 odoo-web

# Container web phu
docker logs -f --tail 50 odoo-web-2
```

### Log Nginx
```bash
docker logs -f --tail 50 odoo-nginx
```

### Log PostgreSQL
```bash
docker logs -f --tail 50 odoo-db
```

### Log Updater daemon
```bash
journalctl -u odoo-updater -f --no-pager
# hoac
cat /home/odoo/scripts/updater.log
```

### Log backup
```bash
cat /home/odoo/scripts/backup.log
```

---

## Quan ly SSL certificate

### Kiem tra han SSL
```bash
openssl x509 -in /etc/letsencrypt/live/odoo.wint.io.vn/fullchain.pem -noout -dates
```

### Gia han thu cong
```bash
# Tam dung Nginx de nha port 80
docker stop odoo-nginx
certbot renew
docker start odoo-nginx
```

SSL duoc tu dong gia han qua certbot.timer (2 lan/ngay).
Sau khi gia han, script `certbot-deploy-hook.sh` se tu dong reload Nginx.

---

## Quan ly database

### Truy cap Database Manager (chi qua SSH tunnel)
```bash
# Tu may tinh ca nhan, mo tunnel
ssh -L 8069:172.18.0.5:8069 odoo-vps

# Sau do mo trinh duyet: http://localhost:8069/web/database/manager
```

**Luu y:** Trang /web/database bi chan tu internet (tra ve 404). Chi truy cap duoc qua SSH tunnel.

### Ket noi truc tiep PostgreSQL
```bash
# Tu trong VPS
docker exec -it odoo-db psql -U odoo -d wint-odoo
```
