# -*- coding: utf-8 -*-
{
    'name': 'Wint HR Auto Onboarding & Email Provisioning',
    'version': '17.0.1.4.0',
    'summary': 'Tu dong tao email cong ty, tai khoan Odoo User va ho tro Odoo Mobile App',
    'description': """
        Module tu dong hoa cho nhan su & he thong:
        1. Chuan hoa ten tieng Viet va tao email cong ty
        2. Tu dong tao tai khoan Odoo User lien ket voi Employee
        3. Tu dong goi API Cloudflare Email Routing tao hom thu chuyen tiep
        4. Ho tro mo khoa Odoo Mobile App tren iOS/Android cho ban Community
    """,
    'category': 'Human Resources',
    'author': 'WinT Group',
    'depends': ['base', 'hr', 'web'],
    'data': [
        'views/res_config_settings_views.xml',
        'views/hr_employee_views.xml',
    ],
    'installable': True,
    'application': False,
    'license': 'LGPL-3',
}
