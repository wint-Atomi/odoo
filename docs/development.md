# Huong dan Phat trien

## Cau truc module Odoo custom

```text
addons/
  wint_hr_onboarding/        # Ten module (snake_case)
    __init__.py               # Import thu muc models
    __manifest__.py           # Khai bao ten, version, depends, data files
    models/
      __init__.py             # Import cac file model
      hr_employee.py          # Mo rong model hr.employee
      res_config_settings.py  # Mo rong Settings cua Odoo
    views/
      hr_employee_views.xml   # Giao dien form/tree cho Employee
      res_config_settings_views.xml  # Giao dien Settings
    security/                 # (tuy chon) Phan quyen
      ir.model.access.csv
    data/                     # (tuy chon) Du lieu mac dinh
    static/                   # (tuy chon) CSS, JS, anh
```

## Quy trinh lam viec voi Git

### 1. Clone repository ve may local
```bash
git clone https://github.com/Win-tenh/odoo
cd odoo
```

### 2. Chinh sua code tren may local
- Sua file trong `addons/wint_hr_onboarding/`
- Hoac tao module moi trong `addons/`

### 3. Test tren may local (Docker)
```bash
# Chay Odoo local (can PostgreSQL dang chay)
docker compose up -d
# Truy cap: http://localhost:8069
```

### 4. Commit va push len GitHub
```bash
git add .
git commit -m "feat: mo ta thay doi"
git push origin main
```

### 5. Deploy len VPS
- **Cach 1:** Bam nut "Cap nhat ngay tu GitHub" tren giao dien Odoo
- **Cach 2:** SSH vao VPS va chay `bash scripts/update.sh`

## Quy uoc commit message

```text
feat: tinh nang moi
fix: sua loi
docs: cap nhat tai lieu
refactor: tai cau truc code
config: thay doi cau hinh
security: bao mat
```

## Tao module moi

### 1. Tao thu muc
```bash
mkdir -p addons/wint_ten_module/models addons/wint_ten_module/views
```

### 2. Tao __manifest__.py
```python
{
    'name': 'Wint Ten Module',
    'version': '17.0.1.0.0',
    'summary': 'Mo ta ngan',
    'category': 'Category',
    'author': 'WinT Group',
    'depends': ['base'],
    'data': [
        'views/ten_view.xml',
    ],
    'installable': True,
    'license': 'LGPL-3',
}
```

### 3. Tao __init__.py
```python
from . import models
```

### 4. Push len GitHub va deploy
Module moi se duoc tu dong nhan dien boi `update.sh` khi deploy.

## Cach debug

### Xem log Odoo realtime
```bash
ssh odoo-vps
docker logs -f --tail 50 odoo-web
```

### Chay Odoo shell de test code
```bash
ssh odoo-vps
docker compose -f /home/odoo/docker-compose.prod.yml exec web odoo shell -d wint-odoo --no-http
```

### Upgrade module thu cong (khong restart)
```bash
docker compose -f docker-compose.prod.yml exec web odoo -u wint_hr_onboarding -d wint-odoo --no-http --stop-after-init
```
