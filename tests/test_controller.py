import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from vps_gateway.app import Controller, Settings
from vps_gateway.models import Route
from vps_gateway.store import load, save


class ControllerTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        root = Path(self.directory.name)
        self.settings = Settings()
        self.settings.state_file = root / "routes.json"
        self.settings.nginx_file = root / "routes.conf"
        self.settings.nginx_config = root / "nginx.conf"
        self.settings.cert_root = root / "certs"

    def tearDown(self):
        self.directory.cleanup()

    @patch("vps_gateway.app.install_candidate")
    def test_updates_persistent_and_in_memory_state(self, install):
        controller = Controller(self.settings)
        route = Route.from_dict(
            "app", {"domains": ["app.example.net"], "upstream": "http://app-gateway:8080"}
        )
        controller.put(route)
        self.assertEqual(route, controller.get("app"))
        self.assertEqual(route, load(self.settings.state_file)["app"])
        install.assert_called_once()

    @patch("vps_gateway.app.install_candidate", side_effect=RuntimeError("reload failed"))
    def test_rolls_back_persistent_state_when_reload_fails(self, _install):
        original = Route.from_dict(
            "app", {"domains": ["app.example.net"], "upstream": "http://old-gateway:8080"}
        )
        save(self.settings.state_file, {"app": original})
        controller = Controller(self.settings)
        replacement = Route.from_dict(
            "app", {"domains": ["app.example.net"], "upstream": "http://new-gateway:8080"}
        )
        with self.assertRaisesRegex(RuntimeError, "reload failed"):
            controller.put(replacement)
        self.assertEqual(original, controller.get("app"))
        self.assertEqual(original, load(self.settings.state_file)["app"])


if __name__ == "__main__":
    unittest.main()
