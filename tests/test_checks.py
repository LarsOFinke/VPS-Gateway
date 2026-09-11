import unittest
from unittest.mock import MagicMock, patch

from vps_gateway.checks import check_accessibility
from vps_gateway.models import Route


class AccessibilityTest(unittest.TestCase):
    def setUp(self):
        self.route = Route.from_dict(
            "app", {"domains": ["app.example.net"], "upstream": "http://app-gateway:8080"}
        )

    @patch("vps_gateway.checks.http.client.HTTPConnection")
    def test_reports_http_status_and_latency(self, connection_class):
        response = MagicMock(status=204)
        connection_class.return_value.getresponse.return_value = response
        with patch("vps_gateway.checks.time.monotonic", side_effect=[10.0, 10.042]):
            result = check_accessibility(self.route)
        self.assertEqual({"accessible": True, "status": 204, "latency_ms": 42}, result)
        connection_class.assert_called_once_with("app-gateway", 8080, timeout=5.0)
        connection_class.return_value.request.assert_called_once_with(
            "HEAD",
            "/",
            headers={"Host": "app.example.net", "User-Agent": "VPS-Gateway-Admin/1"},
        )

    @patch("vps_gateway.checks.http.client.HTTPConnection")
    def test_reports_connection_failure(self, connection_class):
        connection_class.return_value.request.side_effect = OSError("connection refused")
        result = check_accessibility(self.route)
        self.assertFalse(result["accessible"])
        self.assertEqual("connection refused", result["error"])


if __name__ == "__main__":
    unittest.main()
