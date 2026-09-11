import http.client
import json
import tempfile
import threading
import unittest
from pathlib import Path
from unittest.mock import patch

from vps_gateway.app import ApiServer, Controller, Handler, Settings
from vps_gateway.auth import AdminAuth, hash_password


class ApiTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        root = Path(self.directory.name)
        settings = Settings()
        settings.state_file = root / "routes.json"
        settings.nginx_file = root / "routes.conf"
        settings.nginx_config = root / "nginx.conf"
        settings.cert_root = root / "certs"
        self.install = patch("vps_gateway.app.install_candidate").start()
        self.log = patch.object(Handler, "log_message").start()
        self.addCleanup(patch.stopall)
        self.token = "a" * 32
        self.password = "bootstrap-password"
        admin = AdminAuth(root / "admin.json", hash_password(self.password))
        try:
            self.server = ApiServer(("127.0.0.1", 0), Controller(settings), self.token, admin)
        except PermissionError:
            self.directory.cleanup()
            self.skipTest("loopback sockets are unavailable in this environment")
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)
        self.directory.cleanup()

    def request(
        self,
        method,
        path,
        body=None,
        authenticated=False,
        content_type="application/json",
        cookie="",
        csrf="",
    ):
        connection = http.client.HTTPConnection(*self.server.server_address, timeout=2)
        headers = {}
        if authenticated:
            headers["Authorization"] = f"Bearer {self.token}"
        if body is not None:
            headers["Content-Type"] = content_type
        if cookie:
            headers["Cookie"] = cookie
        if csrf:
            headers["X-CSRF-Token"] = csrf
        connection.request(method, path, body=body, headers=headers)
        response = connection.getresponse()
        payload = response.read()
        self.last_headers = dict(response.getheaders())
        connection.close()
        return response.status, payload, response.getheader("Connection"), response.getheader("Set-Cookie")

    def test_health_is_public_but_routes_require_authentication(self):
        status, body, _, _ = self.request("GET", "/v1/health")
        self.assertEqual(200, status)
        self.assertEqual("ok", json.loads(body)["status"])
        status, _, connection, _ = self.request("GET", "/v1/routes")
        self.assertEqual(401, status)
        self.assertEqual("close", connection)

    def test_serves_admin_panel_with_browser_security_headers(self):
        status, body, _, _ = self.request("GET", "/admin/")
        self.assertEqual(200, status)
        self.assertIn(b"VPS Gateway Admin", body)
        self.assertIn("frame-ancestors 'none'", self.last_headers["Content-Security-Policy"])

    def test_checks_route_accessibility_through_api(self):
        result = {"accessible": True, "status": 200, "latency_ms": 4}
        with patch.object(self.server.controller, "check", return_value=result):
            status, body, _, _ = self.request(
                "POST", "/v1/routes/app/check", authenticated=True
            )
        self.assertEqual(200, status)
        self.assertEqual(result, json.loads(body))

    def test_route_round_trip_over_http(self):
        route = json.dumps({"domains": ["app.example.net"], "upstream": "http://app-gateway:8080"})
        status, body, _, _ = self.request("PUT", "/v1/routes/app", route, authenticated=True)
        self.assertEqual(201, status)
        self.assertEqual("app", json.loads(body)["id"])
        status, body, _, _ = self.request("GET", "/v1/routes/app", authenticated=True)
        self.assertEqual(200, status)
        self.assertEqual("http://app-gateway:8080", json.loads(body)["upstream"])

    def test_rejects_invalid_content_type_and_external_upstream(self):
        body = json.dumps({"domains": ["app.example.net"], "upstream": "http://example.net"})
        status, _, connection, _ = self.request(
            "PUT",
            "/v1/routes/app",
            body,
            authenticated=True,
            content_type="text/plain",
        )
        self.assertEqual(422, status)
        self.assertEqual("close", connection)
        status, response, _, _ = self.request("PUT", "/v1/routes/app", body, authenticated=True)
        self.assertEqual(422, status)
        self.assertIn("Docker network alias", json.loads(response)["error"]["message"])

    def test_admin_login_forces_password_change_and_checks_csrf(self):
        login = json.dumps({"password": self.password})
        status, body, _, cookie = self.request("POST", "/v1/admin/login", login)
        self.assertEqual(200, status)
        session = json.loads(body)
        self.assertTrue(session["must_change_password"])
        cookie = cookie.split(";", 1)[0]
        status, _, _, _ = self.request("GET", "/v1/routes", cookie=cookie)
        self.assertEqual(403, status)
        change = json.dumps({"current_password": self.password, "new_password": "a-new-secure-password"})
        status, _, _, _ = self.request("POST", "/v1/admin/password", change, cookie=cookie)
        self.assertEqual(403, status)
        status, _, _, _ = self.request(
            "POST", "/v1/admin/password", change, cookie=cookie, csrf=session["csrf"]
        )
        self.assertEqual(204, status)
        status, _, _, _ = self.request("GET", "/v1/routes", cookie=cookie)
        self.assertEqual(200, status)


if __name__ == "__main__":
    unittest.main()
