import tempfile
import unittest
from pathlib import Path

from vps_gateway.models import Route
from vps_gateway.store import load, save


class StoreTest(unittest.TestCase):
    def test_round_trip(self):
        route = Route.from_dict(
            "app",
            {"domains": ["app.example.net"], "upstream": "http://app-gateway:8080", "websocket": True},
        )
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "routes.json"
            save(path, {"app": route})
            restored = load(path)
        self.assertEqual(route, restored["app"])


if __name__ == "__main__":
    unittest.main()
