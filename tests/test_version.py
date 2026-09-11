import re
import unittest
from pathlib import Path

from vps_gateway import __version__


class VersionTest(unittest.TestCase):
    def test_version_is_synchronized(self):
        root = Path(__file__).resolve().parents[1]
        version = (root / "VERSION").read_text(encoding="utf-8").strip()
        self.assertRegex(version, r"^\d+\.\d+\.\d+$")
        self.assertEqual(version, __version__)
        openapi = (root / "openapi.yaml").read_text(encoding="utf-8")
        self.assertRegex(openapi, rf"(?m)^  version: {re.escape(version)}$")


if __name__ == "__main__":
    unittest.main()
