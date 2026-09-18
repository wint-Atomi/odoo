#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Odoo GitHub Updater & Webhook Daemon
Lắng nghe yêu cầu cập nhật để tự động chạy update.sh (kéo git pull và khởi động lại Odoo).
"""

import os
import sys
import json
import time
import subprocess
import threading
try:
    from http.server import ThreadingHTTPServer as ServerClass
except ImportError:
    from http.server import HTTPServer as ServerClass
from http.server import BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

PORT = 9999
TOKEN = os.environ.get("UPDATER_TOKEN", "")
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BASE_DIR = os.path.dirname(SCRIPT_DIR)
UPDATE_SCRIPT = os.path.join(SCRIPT_DIR, "update.sh")
LOG_FILE = os.path.join(SCRIPT_DIR, "updater.log")

_last_check_time = 0
_cached_check_result = None
_check_lock = threading.Lock()

def log(msg):
    timestamp = time.strftime('%Y-%m-%d %H:%M:%S')
    entry = f"[{timestamp}] {msg}\n"
    print(entry, end="")
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(entry)
    except Exception:
        pass

def run_update_process():
    log("=== Bắt đầu tiến trình cập nhật từ GitHub ===")
    try:
        proc = subprocess.run(
            ["/bin/bash", UPDATE_SCRIPT],
            cwd=BASE_DIR,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        log(f"Kết quả update stdout:\n{proc.stdout}")
        if proc.stderr:
            log(f"Kết quả update stderr:\n{proc.stderr}")
        log(f"=== Hoàn tất cập nhật (Exit code: {proc.returncode}) ===")
    except Exception as e:
        log(f"Lỗi khi thực thi {UPDATE_SCRIPT}: {e}")

def check_update_info():
    """Kiểm tra xem trên GitHub có commit mới hơn so với local hay không"""
    global _last_check_time, _cached_check_result
    now = time.time()
    with _check_lock:
        if _cached_check_result and (now - _last_check_time < 20):
            return _cached_check_result

    try:
        subprocess.run(
            ["git", "fetch", "origin", "main"],
            cwd=BASE_DIR,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=20
        )
        
        local_summary = subprocess.check_output(
            ["git", "log", "-1", "--format=%h - %s (%cd)", "--date=format:%d/%m/%Y %H:%M", "HEAD"],
            cwd=BASE_DIR, text=True
        ).strip()

        remote_summary = subprocess.check_output(
            ["git", "log", "-1", "--format=%h - %s (%cd)", "--date=format:%d/%m/%Y %H:%M", "origin/main"],
            cwd=BASE_DIR, text=True
        ).strip()

        behind_count_str = subprocess.check_output(
            ["git", "rev-list", "--count", "HEAD..origin/main"],
            cwd=BASE_DIR, text=True
        ).strip()
        behind_count = int(behind_count_str) if behind_count_str.isdigit() else 0

        changelog_str = ""
        if behind_count > 0:
            changelog_str = subprocess.check_output(
                ["git", "log", "--oneline", "-n", "5", "HEAD..origin/main"],
                cwd=BASE_DIR, text=True
            ).strip()

        res = {
            "success": True,
            "has_update": behind_count > 0,
            "behind_count": behind_count,
            "current_version": local_summary,
            "latest_version": remote_summary,
            "changelog": changelog_str,
            "last_checked": time.strftime('%d/%m/%Y %H:%M:%S')
        }
        with _check_lock:
            _cached_check_result = res
            _last_check_time = time.time()
        return res
    except Exception as e:
        return {
            "success": False,
            "error": str(e)
        }


class UpdateHandler(BaseHTTPRequestHandler):
    def _send_json(self, status_code, data):
        try:
            self.send_response(status_code)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps(data, ensure_ascii=False).encode('utf-8'))
        except (BrokenPipeError, ConnectionResetError):
            pass

    def _check_auth(self):
        token_header = self.headers.get('X-Update-Token')
        parsed = urlparse(self.path)
        params = parse_qs(parsed.query)
        token_query = params.get('token', [None])[0]
        return (token_header == TOKEN) or (token_query == TOKEN)

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == '/health':
            self._send_json(200, {"status": "ok", "service": "odoo-updater"})
            return

        if parsed.path in ('/check-update', '/version'):
            if not self._check_auth():
                self._send_json(403, {"error": "Forbidden", "message": "Invalid token"})
                return
            info = check_update_info()
            self._send_json(200, info)
            return

        if parsed.path in ('/update', '/webhook'):
            if not self._check_auth():
                self._send_json(403, {"error": "Forbidden", "message": "Invalid token"})
                return

            log(f"Nhận lệnh cập nhật (GET) từ {self.client_address[0]}")
            threading.Thread(target=run_update_process, daemon=True).start()
            self._send_json(200, {
                "status": "started",
                "message": "Đang kéo mã nguồn mới nhất từ GitHub và khởi động lại Odoo..."
            })
            return

        self._send_json(404, {"error": "Not Found"})

    def do_POST(self):
        parsed = urlparse(self.path)
        if parsed.path in ('/check-update', '/version'):
            if not self._check_auth():
                self._send_json(403, {"error": "Forbidden", "message": "Invalid token"})
                return
            info = check_update_info()
            self._send_json(200, info)
            return

        if parsed.path in ('/update', '/webhook'):
            if not self._check_auth():
                self._send_json(403, {"error": "Forbidden", "message": "Invalid token"})
                return

            log(f"Nhận lệnh cập nhật (POST) từ {self.client_address[0]}")
            threading.Thread(target=run_update_process, daemon=True).start()
            self._send_json(200, {
                "status": "started",
                "message": "Đang kéo mã nguồn mới nhất từ GitHub và khởi động lại Odoo..."
            })
            return

        self._send_json(404, {"error": "Not Found"})

    def log_message(self, format, *args):
        log(f"HTTP: {self.address_string()} - {format % args}")

def run():
    server_address = ('0.0.0.0', PORT)
    httpd = ServerClass(server_address, UpdateHandler)
    log(f"Odoo Updater Daemon đã khởi động trên cổng {PORT}...")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    httpd.server_close()
    log("Odoo Updater Daemon đã dừng.")

if __name__ == '__main__':
    run()
