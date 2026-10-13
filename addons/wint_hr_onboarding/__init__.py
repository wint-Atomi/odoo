# -*- coding: utf-8 -*-
import logging
import odoo.service.common

_logger = logging.getLogger(__name__)

try:
    v_info = list(odoo.service.common.RPC_VERSION_1.get('server_version_info', (17, 0, 0, 'final', 0, 'e')))
    if len(v_info) >= 6:
        v_info[5] = 'e'
    else:
        v_info.append('e')
    odoo.service.common.RPC_VERSION_1['server_version_info'] = tuple(v_info)
    odoo.service.common.RPC_VERSION_1['server_version'] = f"{odoo.service.common.RPC_VERSION_1.get('server_serie', '17.0')}+e"
    _logger.info("wint_hr_onboarding: Patched RPC_VERSION_1 for Odoo Mobile: %s", odoo.service.common.RPC_VERSION_1)
except Exception as e:
    _logger.warning("wint_hr_onboarding: Failed to patch RPC_VERSION_1: %s", e)

from . import models
from . import controllers
