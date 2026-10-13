# -*- coding: utf-8 -*-
import logging
from odoo import http
from odoo.addons.web.controllers.webclient import WebClient

_logger = logging.getLogger(__name__)

class MobileWebClient(WebClient):

    @http.route('/web/webclient/version_info', type='json', auth="none")
    def version_info(self):
        res = super().version_info()
        version_info = list(res.get('server_version_info', (17, 0, 0, 'final', 0, 'e')))
        if len(version_info) >= 6:
            version_info[5] = 'e'
        else:
            version_info.append('e')
        res['server_version_info'] = version_info
        res['server_version'] = f"{res.get('server_serie', '17.0')}+e"
        _logger.info("MobileWebClient: Returned fake Enterprise version_info for mobile app: %s", res)
        return res
