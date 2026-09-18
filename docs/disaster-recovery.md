# Phuc hoi Su co (Disaster Recovery)

## Tinh huong 1: VPS mat hoan toan (phan cung hong, mat du lieu)

### Yeu cau
- VPS moi da cai Docker va Docker Compose
- File backup (.sql.gz) tu thu muc /home/backup/odoo/ cua VPS cu
  (Neu khong co, du lieu mat vinh vien!)

### Cac buoc thuc hien

```bash
# 1. Clone repository tu GitHub
git clone https://github.com/Win-tenh/odoo /home/odoo
cd /home/odoo

# 2. Tao file .env voi mat khau
cp .env.example .env
nano .env    # Dien mat khau database va Telegram token

# 3. Copy file backup tu may khac vao VPS moi
# (chay tu may co backup)
scp -P <YOUR_SSH_PORT> /home/backup/odoo/wint-odoo_latest.sql.gz root@<IP_VPS_MOI>:/home/backup/odoo/

# 4. Chay script migrate
bash scripts/migrate.sh /home/backup/odoo/wint-odoo_latest.sql.gz
```

Script migrate.sh se tu dong:
- Cap chung chi SSL Let's Encrypt
- Khoi dong tat ca container Docker
- Restore database tu backup
- Cai dat Updater daemon va SSH notification
- Dat cron backup + healthcheck

### Sau khi migrate
- Cap nhat DNS (Cloudflare) tro sang IP VPS moi
- Kiem tra: `curl -Isk https://odoo.wint.io.vn/web/login`
- Cap nhat SSH alias tren may ca nhan: `~/.ssh/config`

---

## Tinh huong 2: Database bi hong (khong doc duoc, du lieu sai)

```bash
cd /home/odoo

# 1. Xem danh sach backup
ls -lh /home/backup/odoo/

# 2. Restore tu ban backup gan nhat
bash scripts/restore.sh

# Hoac restore tu ban cu the
bash scripts/restore.sh /home/backup/odoo/wint-odoo_20260915_030000.sql.gz
```

---

## Tinh huong 3: Odoo bi treo / khong truy cap duoc

```bash
# Kiem tra container nao bi loi
docker compose -f docker-compose.prod.yml ps

# Xem log container loi
docker logs --tail 100 odoo-web

# Khoi dong lai toan bo
docker compose -f docker-compose.prod.yml restart

# Neu van loi, dung va bat lai
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml up -d
```

---

## Tinh huong 4: Rollback code ve phien ban cu

```bash
cd /home/odoo

# Xem lich su commit
git log --oneline -10

# Rollback ve commit cu the
git reset --hard <commit_hash>

# Restart de ap dung
bash scripts/update.sh
```

**Luu y:** Sau khi rollback, neu module da duoc upgrade (thay doi cot database),
co the can restore database tu backup tuong ung thoi diem do.

---

## Tinh huong 5: SSL het han / trinh duyet bao "Khong an toan"

```bash
# Kiem tra han SSL
openssl x509 -in /etc/letsencrypt/live/odoo.wint.io.vn/fullchain.pem -noout -dates

# Gia han thu cong
docker stop odoo-nginx
certbot renew --force-renewal
docker start odoo-nginx
```

---

## Tinh huong 6: O dia day

```bash
# Kiem tra dung luong
df -h /
du -sh /var/lib/docker/overlay2/* | sort -rh | head -5

# Don dep Docker (images/containers/volumes khong dung)
docker system prune -af --volumes

# Xoa log container cu
truncate -s 0 $(docker inspect --format='{{.LogPath}}' odoo-web)
truncate -s 0 $(docker inspect --format='{{.LogPath}}' odoo-web-2)
```

---

## Checklist phuc hoi

- [ ] Tat ca 4 container dang chay: `docker compose ps`
- [ ] Odoo tra ve HTTP 200: `curl -sk https://odoo.wint.io.vn/web/login -o /dev/null -w "%{http_code}"`
- [ ] Database ket noi duoc: `docker exec odoo-db pg_isready -U odoo`
- [ ] Updater daemon hoat dong: `systemctl is-active odoo-updater`
- [ ] SSL certificate con han: `openssl x509 -in /etc/letsencrypt/live/odoo.wint.io.vn/fullchain.pem -noout -dates`
- [ ] Cron backup da dat: `crontab -l | grep backup`
- [ ] Cron healthcheck da dat: `crontab -l | grep healthcheck`
- [ ] SSH notification hoat dong: dang nhap lai va kiem tra Telegram
