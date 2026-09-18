# Tai lieu He thong Odoo Production

Tai lieu huong dan van hanh, bao tri va phat trien he thong Odoo 17 Production.

## Muc luc

| Tai lieu | Noi dung |
|----------|---------|
| [Kien truc he thong](architecture.md) | So do kien truc, thanh phan, mang Docker, luong du lieu |
| [Huong dan van hanh](operations.md) | Kiem tra trang thai, cap nhat, backup/restore, SSL, log |
| [Phuc hoi su co](disaster-recovery.md) | VPS mat, database hong, chuyen may, rollback |
| [Huong dan phat trien](development.md) | Phat trien module, quy trinh Git, test local |

## Thong tin nhanh

| Hang muc | Gia tri |
|----------|---------|
| URL | https://odoo.example.com |
| VPS IP | `<YOUR_VPS_IP>` |
| SSH Port | `<YOUR_SSH_PORT>` |
| SSH Alias | `ssh <YOUR_SSH_ALIAS>` |
| OS | Ubuntu 24.04 LTS |
| Odoo | 17.0 (Docker) |
| Database | PostgreSQL 16 (Docker) |
| Repository | https://github.com/Win-tenh/odoo |
| Branch | main |
| Backup | /home/backup/odoo/ (moi ngay luc 3:00 AM, giu 7 ban) |
