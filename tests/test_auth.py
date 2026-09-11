import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from vps_gateway.auth import AdminAuth, hash_password, verify_password
from vps_gateway.models import ValidationError


class AuthTest(unittest.TestCase):
    def test_hashes_and_verifies_password(self):
        encoded = hash_password("correct horse battery staple")
        self.assertTrue(verify_password("correct horse battery staple", encoded))
        self.assertFalse(verify_password("incorrect password", encoded))
        self.assertNotIn("correct horse", encoded)

    def test_password_change_persists_and_revokes_other_sessions(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "admin.json"
            auth = AdminAuth(path, hash_password("bootstrap-password"))
            current = auth.login("bootstrap-password")
            other = auth.login("bootstrap-password")
            self.assertTrue(auth.must_change)
            auth.change_password("bootstrap-password", "replacement-password", current.token)
            self.assertFalse(auth.must_change)
            self.assertIsNotNone(auth.authenticate(current.token))
            self.assertIsNone(auth.authenticate(other.token))
            restored = AdminAuth(path, "")
            self.assertIsNotNone(restored.login("replacement-password"))
            self.assertEqual(0o600, path.stat().st_mode & 0o777)
            self.assertNotIn("replacement-password", json.loads(path.read_text())["password_hash"])

    def test_rejects_short_password(self):
        with self.assertRaisesRegex(ValidationError, "12 to 1024"):
            hash_password("too-short")

    def test_temporarily_blocks_repeated_login_failures(self):
        with tempfile.TemporaryDirectory() as directory:
            auth = AdminAuth(Path(directory) / "admin.json", hash_password("bootstrap-password"))
            with patch("vps_gateway.auth.time.time", return_value=100.0):
                for _ in range(5):
                    self.assertIsNone(auth.login("incorrect-password"))
                self.assertIsNone(auth.login("bootstrap-password"))
            with patch("vps_gateway.auth.time.time", return_value=131.0):
                self.assertIsNotNone(auth.login("bootstrap-password"))


if __name__ == "__main__":
    unittest.main()
