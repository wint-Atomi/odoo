# -*- coding: utf-8 -*-
import re
import requests
import logging
from odoo import models, fields, api, _

_logger = logging.getLogger(__name__)

def remove_vietnamese_accents(text):
    if not text:
        return ''
    s1 = u'ÀÁÂÃÈÉÊÌÍÒÓÔÕÙÚÝàáâãèéêìíòóôõùúýĂăĐđĨĩŨũƠơƯưẠạẢảẤấẦầẨẩẪẫẬậẮắẰằẲẳẴẵẶặẸẹẺẻẼẽẾếỀềỂểỄễỆệỈỉỊịỌọỎỏỐốỒồỔổỖỗỘộỚớỜờỞởỠỡỢợỤụỦủỨứỪừỬửỮữỰựỲỳỴỵỶỷỸỹ'
    s0 = u'AAAAEEEIIOOOOUUYaaaaeeeiioooouuyAaDdIiUuOoUuAaAaAaAaAaAaAaAaAaAaAaAaEeEeEeEeEeEeEeEeIiIiOoOoOoOoOoOoOoOoOoOoOoOoUuUuUuUuUuUuUuYyYyYyYy'
    s = ''
    for c in text:
        if c in s1:
            s += s0[s1.index(c)]
        else:
            s += c
    s = re.sub(r'[^a-zA-Z0-9\s]', '', s)
    return s.strip().lower()

class HrEmployee(models.Model):
    _inherit = 'hr.employee'

    cloudflare_rule_id = fields.Char(string="Cloudflare Rule ID", readonly=True, copy=False)

    def _generate_work_email(self):
        self.ensure_one()
        clean_name = remove_vietnamese_accents(self.name or '')
        # Viết liền toàn bộ họ và tên không dấu: "Nguyễn Văn Anh" -> "nguyenvananh"
        username = re.sub(r'\s+', '', clean_name)
        if not username:
            username = 'user'

        # Ghép ngày tháng năm sinh (DDMMYYYY), ví dụ: 12/09/2000 -> '12092000'
        if self.birthday:
            username += self.birthday.strftime('%d%m%Y')

        domain = self.env['ir.config_parameter'].sudo().get_param('wint_hr.email_domain', 'wint.io.vn')
        base_email = f"{username}@{domain}"
        
        # Kiểm tra trùng lặp email
        final_email = base_email
        counter = 1
        while self.env['hr.employee'].search([('work_email', '=', final_email), ('id', '!=', self.id)]):
            final_email = f"{username}{counter}@{domain}"
            counter += 1
            
        return final_email

    def action_provision_email_and_user(self):
        """Hàm tạo Email nội bộ, User Odoo và (tùy chọn) đồng bộ sang Cloudflare"""
        for employee in self:
            ICP = self.env['ir.config_parameter'].sudo()
            auto_create_user = ICP.get_param('wint_hr.auto_create_user', 'True') == 'True'
            enable_cloudflare = ICP.get_param('wint_hr.enable_cloudflare_sync', 'True') == 'True'
            zone_id = ICP.get_param('wint_hr.cloudflare_zone_id')
            api_token = ICP.get_param('wint_hr.cloudflare_api_token')

            # 1. Tự sinh email công ty (username) nếu chưa có
            if not employee.work_email:
                employee.work_email = employee._generate_work_email()

            # 2. Tự động tạo hoặc gán tài khoản Odoo User
            user_msg = ""
            if auto_create_user and not employee.user_id:
                existing_user = self.env['res.users'].search([('login', '=', employee.work_email)], limit=1)
                if existing_user:
                    employee.user_id = existing_user
                    user_msg = f"<br/>• <b>Tài khoản Odoo:</b> Đã liên kết với tài khoản có sẵn ({employee.work_email})"
                else:
                    new_user = self.env['res.users'].create({
                        'name': employee.name,
                        'login': employee.work_email,
                        'email': employee.work_email,
                        'password': '6',
                        'company_id': employee.company_id.id if employee.company_id else self.env.company.id,
                        'company_ids': [(6, 0, [employee.company_id.id if employee.company_id else self.env.company.id])],
                    })
                    employee.user_id = new_user
                    user_msg = f"<br/>• <b>Tài khoản Odoo:</b> Đã tạo mới tài khoản đăng nhập (Username: <code>{employee.work_email}</code> | Password: <code>6</code>)"

            # 3. Đồng bộ sang Cloudflare Email Routing (Chỉ chạy khi bật tính năng này)
            cf_msg = ""
            if enable_cloudflare:
                target_forward_email = employee.private_email or False
                if not target_forward_email:
                    cf_msg = "<br/>• <b>Cloudflare Email Routing:</b> <i>Bỏ qua (Chưa nhập Email cá nhân đích đến)</i>"
                elif zone_id and api_token and not employee.cloudflare_rule_id:
                    try:
                        url = f"https://api.cloudflare.com/client/v4/zones/{zone_id}/email/routing/rules"
                        headers = {
                            "Authorization": f"Bearer {api_token}",
                            "Content-Type": "application/json"
                        }
                        payload = {
                            "matchers": [{"type": "literal", "field": "to", "value": employee.work_email}],
                            "actions": [{"type": "forward", "value": [target_forward_email]}],
                            "name": f"Auto Forward: {employee.name}",
                            "enabled": True,
                            "priority": 10
                        }
                        resp = requests.post(url, headers=headers, json=payload, timeout=10)
                        res_data = resp.json()
                        if res_data.get('success'):
                            rule_id = res_data.get('result', {}).get('id')
                            employee.cloudflare_rule_id = rule_id
                            cf_msg = f"<br/>• <b>Cloudflare Email Routing:</b> Đã tạo quy tắc chuyển tiếp thư về <code>{target_forward_email}</code>"
                        else:
                            err_msg = res_data.get('errors', [{}])[0].get('message', 'Lỗi không xác định')
                            cf_msg = f"<br/>• <b>Cloudflare:</b> Lỗi ({err_msg})"
                    except Exception as e:
                        cf_msg = f"<br/>• <b>Cloudflare:</b> Lỗi kết nối ({str(e)})"
            
            # Ghi log lịch sử vào khung trao đổi (Chatter)
            log_body = f"<b>Cấp phát thông tin nhân sự:</b><br/>• <b>Email công ty:</b> <code>{employee.work_email}</code>{user_msg}{cf_msg}"
            employee.message_post(body=log_body)

        return {
            'type': 'ir.actions.client',
            'tag': 'display_notification',
            'params': {
                'title': _('Thành công!'),
                'message': _('Đã cập nhật Email và tài khoản cho nhân viên: %s') % self.work_email,
                'sticky': False,
                'type': 'success',
            }
        }

    @api.model_create_multi
    def create(self, vals_list):
        employees = super(HrEmployee, self).create(vals_list)
        ICP = self.env['ir.config_parameter'].sudo()
        auto_user = ICP.get_param('wint_hr.auto_create_user', 'True') == 'True'
        enable_cf = ICP.get_param('wint_hr.enable_cloudflare_sync', 'True') == 'True'
        
        # Tự động kích hoạt khi có ít nhất 1 trong 2 tính năng được bật
        if auto_user or enable_cf:
            for emp in employees:
                try:
                    emp.action_provision_email_and_user()
                except Exception as e:
                    _logger.warning("Không thể tự động xử lý nhân viên %s: %s", emp.name, str(e))
        return employees
