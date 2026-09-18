# -*- coding: utf-8 -*-
{
    'name': 'Wint HR Auto Onboarding & Email Provisioning',
    'version': '17.0.1.3.1',
    'summary': 'Tự động tạo email công ty qua Cloudflare và tạo tài khoản User cho nhân viên mới',
    'description': """
        Module tự động hóa cho nhân sự:
        1. Chuẩn hóa tên tiếng Việt (Nguyễn Văn Thắng + 06/12 -> thangnv0612@wint.io.vn)
        2. Tự động tạo tài khoản Odoo User liên kết với Employee
        3. Tự động gọi API Cloudflare Email Routing để tạo hòm thư chuyển tiếp về Gmail cá nhân
    """,
    'category': 'Human Resources',
    'author': 'WinT Group',
    'depends': ['base', 'hr'],
    'data': [
        'views/res_config_settings_views.xml',
        'views/hr_employee_views.xml',
    ],
    'installable': True,
    'application': False,
    'license': 'LGPL-3',
}
