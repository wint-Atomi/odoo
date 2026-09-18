# -*- coding: utf-8 -*-
import requests
from odoo import models, fields, api, _
from odoo.exceptions import UserError

class ResConfigSettings(models.TransientModel):
    _inherit = 'res.config.settings'

    auto_create_user = fields.Boolean(
        string="Tự động tạo tài khoản Odoo User",
        help="Tự động sinh email (Tên + Ngày sinh) và tạo User Odoo để nhân viên đăng nhập"
    )

    enable_cloudflare_sync = fields.Boolean(
        string="Tự động đồng bộ sang Cloudflare Email Routing",
        help="Bật để tự động tạo quy tắc chuyển tiếp email về Gmail cá nhân trên Cloudflare"
    )

    company_email_domain = fields.Char(
        string="Tên miền Email Công ty",
        help="Đuôi email của công ty, ví dụ: wint.io.vn"
    )

    cloudflare_zone_id = fields.Char(
        string="Cloudflare Zone ID",
        help="Zone ID của domain trên Cloudflare"
    )

    cloudflare_api_token = fields.Char(
        string="Cloudflare API Token",
        help="API Token có quyền Edit Email Routing Rules"
    )

    git_current_version = fields.Char(
        string="Phiên bản hiện tại",
        readonly=True
    )
    git_has_update = fields.Boolean(
        string="Có bản cập nhật mới",
        readonly=True
    )
    git_behind_count = fields.Integer(
        string="Số commit mới",
        readonly=True
    )
    git_latest_version = fields.Char(
        string="Phiên bản mới nhất trên GitHub",
        readonly=True
    )
    git_last_checked = fields.Char(
        string="Kiểm tra lần cuối",
        readonly=True
    )
    git_changelog = fields.Text(
        string="Nhật ký commit mới",
        readonly=True
    )

    @api.model
    def get_values(self):
        res = super(ResConfigSettings, self).get_values()
        ICP = self.env['ir.config_parameter'].sudo()
        res.update(
            auto_create_user=ICP.get_param('wint_hr.auto_create_user', 'True') == 'True',
            enable_cloudflare_sync=ICP.get_param('wint_hr.enable_cloudflare_sync', 'True') == 'True',
            company_email_domain=ICP.get_param('wint_hr.email_domain', 'wint.io.vn'),
            cloudflare_zone_id=ICP.get_param('wint_hr.cloudflare_zone_id', ''),
            cloudflare_api_token=ICP.get_param('wint_hr.cloudflare_api_token', ''),
            git_current_version=ICP.get_param('wint_hr.git_current_version', 'Chưa kiểm tra (Bấm nút Kiểm tra bên dưới)'),
            git_has_update=ICP.get_param('wint_hr.git_has_update', 'False') == 'True',
            git_behind_count=int(ICP.get_param('wint_hr.git_behind_count', '0')),
            git_latest_version=ICP.get_param('wint_hr.git_latest_version', ''),
            git_last_checked=ICP.get_param('wint_hr.git_last_checked', ''),
            git_changelog=ICP.get_param('wint_hr.git_changelog', ''),
        )
        return res

    def set_values(self):
        super(ResConfigSettings, self).set_values()
        ICP = self.env['ir.config_parameter'].sudo()
        # Lưu rõ ràng thành chuỗi 'True' hoặc 'False' để không bị Odoo tự động xóa tham số khi bỏ tích
        ICP.set_param('wint_hr.auto_create_user', 'True' if self.auto_create_user else 'False')
        ICP.set_param('wint_hr.enable_cloudflare_sync', 'True' if self.enable_cloudflare_sync else 'False')
        ICP.set_param('wint_hr.email_domain', self.company_email_domain or 'wint.io.vn')
        ICP.set_param('wint_hr.cloudflare_zone_id', self.cloudflare_zone_id or '')
        ICP.set_param('wint_hr.cloudflare_api_token', self.cloudflare_api_token or '')

    def action_check_system_update(self):
        """Gui lenh kiem tra ban cap nhat moi tren GitHub toi Updater Service"""
        ICP = self.env['ir.config_parameter'].sudo()
        updater_token = ICP.get_param('wint_hr.updater_token', '')
        urls = [
            "http://host.docker.internal:9999/check-update",
            "http://172.17.0.1:9999/check-update",
        ]

        data = None
        errors = []

        for url in urls:
            try:
                res = requests.get(url, headers={"X-Update-Token": updater_token}, timeout=15)
                if res.status_code == 200:
                    data = res.json()
                    break
                elif res.status_code == 403:
                    raise UserError(_("Loi xac thuc (403): Token bao mat cua Updater khong chinh xac."))
                else:
                    errors.append(f"{url}: HTTP {res.status_code} - {res.text}")
            except requests.exceptions.RequestException as e:
                errors.append(f"{url}: {e}")
                continue

        if not data or not data.get('success'):
            err_detail = data.get('error') if data else "; ".join(errors)
            raise UserError(_(
                "Khong the kiem tra ban cap nhat tu may chu VPS!\n\n"
                "Chi tiet loi: %s\n\n"
                "Hay dam bao dich vu Updater da duoc cai dat va kich hoat tren VPS bang lenh:\n"
                "bash /home/odoo/scripts/install_updater.sh"
            ) % err_detail)

        ICP = self.env['ir.config_parameter'].sudo()
        has_update = data.get('has_update', False)
        behind_count = data.get('behind_count', 0)
        current_ver = data.get('current_version', '')
        latest_ver = data.get('latest_version', '')
        last_checked = data.get('last_checked', '')
        changelog = data.get('changelog', '')

        ICP.set_param('wint_hr.git_current_version', current_ver)
        ICP.set_param('wint_hr.git_latest_version', latest_ver)
        ICP.set_param('wint_hr.git_has_update', 'True' if has_update else 'False')
        ICP.set_param('wint_hr.git_behind_count', str(behind_count))
        ICP.set_param('wint_hr.git_last_checked', last_checked)
        ICP.set_param('wint_hr.git_changelog', changelog or '')

        # Cap nhat truc tiep len ban ghi form hien tai
        self.write({
            'git_current_version': current_ver,
            'git_latest_version': latest_ver,
            'git_has_update': has_update,
            'git_behind_count': behind_count,
            'git_last_checked': last_checked,
            'git_changelog': changelog or '',
        })

        if has_update:
            msg = _(
                "Phat hien %s ban cap nhat moi tren GitHub!\n\n"
                "- Phien ban moi nhat: %s\n"
                "Ban co the bam nut 'Cap nhat ngay tu GitHub' de nang cap he thong."
            ) % (behind_count, latest_ver)
            notif_type = 'warning'
            title = _('Co ban cap nhat moi!')
        else:
            msg = _("He thong dang o phien ban moi nhat (%s). Khong co cap nhat nao moi!") % current_ver
            notif_type = 'success'
            title = _('Da o ban moi nhat')

        return {
            'type': 'ir.actions.client',
            'tag': 'display_notification',
            'params': {
                'title': title,
                'message': msg,
                'type': notif_type,
                'sticky': False,
                'next': {
                    'type': 'ir.actions.act_window',
                    'res_model': 'res.config.settings',
                    'views': [[False, 'form']],
                    'target': 'inline',
                }
            }
        }

    def action_update_system_from_github(self):
        """Gui lenh cap nhat code tu GitHub toi Updater Service tren may chu VPS"""
        ICP = self.env['ir.config_parameter'].sudo()
        updater_token = ICP.get_param('wint_hr.updater_token', '')
        urls = [
            "http://host.docker.internal:9999/update",
            "http://172.17.0.1:9999/update",
        ]

        success = False
        errors = []

        for url in urls:
            try:
                res = requests.post(url, headers={"X-Update-Token": updater_token}, timeout=15)
                if res.status_code == 200:
                    success = True
                    break
                elif res.status_code == 403:
                    raise UserError(_("Loi xac thuc (403): Token bao mat cua Updater khong chinh xac."))
                else:
                    errors.append(f"{url}: HTTP {res.status_code} - {res.text}")
            except requests.exceptions.RequestException as e:
                errors.append(f"{url}: {e}")
                continue

        if not success:
            raise UserError(_(
                "Khong the ket noi den dich vu Odoo Updater tren may chu VPS!\n\n"
                "Chi tiet loi: %s\n\n"
                "Hay dam bao dich vu Updater da duoc cai dat va kich hoat tren VPS bang lenh:\n"
                "bash /home/odoo/scripts/install_updater.sh"
            ) % "; ".join(errors))

        return {
            'type': 'ir.actions.client',
            'tag': 'display_notification',
            'params': {
                'title': _('Dang cap nhat tu GitHub!'),
                'message': _('He thong dang tien hanh keo code moi nhat va nap lai Odoo. Qua trinh mat khoang 10-15 giay, vui long doi roi F5 (tai lai trang).'),
                'type': 'success',
                'sticky': True,
            }
        }

