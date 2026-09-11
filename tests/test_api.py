import http.client
import json
import tempfile
import threading
import unittest
from pathlib import Path
from unittest.mock import patch

from vps_gateway.app import ApiServer, Controller, Handler, Settings


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
        try:
            self.server = ApiServer(("127.0.0.1", 0), Controller(settings), self.token)
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
    ):
        connection = http.client.HTTPConnection(*self.server.server_address, timeout=2)
        headers = {}
        if authenticated:
            headers["Authorization"] = f"Bearer {self.token}"
        if body is not None:
            headers["Content-Type"] = content_type
        connection.request(method, path, body=body, headers=headers)
        response = connection.getresponse()
        payload = response.read()
        connection.close()
        return response.status, payload, response.getheader("Connection")

    def test_health_is_public_but_routes_require_authentication(self):
        status, body, _ = self.request("GET", "/v1/health")
        self.assertEqual(200, status)
        self.assertEqual("ok", json.loads(body)["status"])
        status, _, connection = self.request("GET", "/v1/routes")
        self.assertEqual(401, status)
        self.assertEqual("close", connection)

    def test_route_round_trip_over_http(self):
        route = json.dumps({"domains": ["app.example.net"], "upstream": "http://app-gateway:8080"})
        status, body, _ = self.request("PUT", "/v1/routes/app", route, authenticated=True)
        self.assertEqual(201, status)
        self.assertEqual("app", json.loads(body)["id"])
        status, body, _ = self.request("GET", "/v1/routes/app", authenticated=True)
        self.assertEqual(200, status)
        self.assertEqual("http://app-gateway:8080", json.loads(body)["upstream"])

    def test_rejects_invalid_content_type_and_external_upstream(self):
        body = json.dumps({"domains": ["app.example.net"], "upstream": "http://example.net"})
        status, _, connection = self.request(
            "PUT",
            "/v1/routes/app",
            body,
            authenticated=True,
            content_type="text/plain",
        )
        self.assertEqual(422, status)
        self.assertEqual("close", connection)
        status, response, _ = self.request("PUT", "/v1/routes/app", body, authenticated=True)
        self.assertEqual(422, status)
        self.assertIn("Docker network alias", json.loads(response)["error"]["message"])


if __name__ == "__main__":
    unittest.main()
