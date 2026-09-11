import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from vps_gateway.models import Route, ValidationError
from vps_gateway.nginx import install_candidate, render


class NginxTest(unittest.TestCase):
    def setUp(self):
        self.route = Route.from_dict(
            "app",
            {"domains": ["app.example.net"], "upstream": "http://app-gateway:8080"},
        )

    def test_renders_proxy_and_overwrites_forwarded_headers(self):
        output = render({"app": self.route}, Path("/certs"))
        self.assertIn("server_name app.example.net;", output)
        self.assertIn('set $gateway_target "http://app-gateway:8080";', output)
        self.assertIn("proxy_set_header X-Forwarded-For $remote_addr;", output)
        self.assertNotIn("listen 8443 ssl", output)

    def test_disabled_route_serves_maintenance_instead_of_disappearing(self):
        disabled = Route.from_dict(
            "app",
            {"domains": ["app.example.net"], "upstream": "http://app-gateway:8080", "enabled": False},
        )
        output = render({"app": disabled}, Path("/certs"))
        self.assertIn("server_name app.example.net;", output)
        self.assertIn('add_header Retry-After "300" always;', output)
        self.assertIn("return 503", output)
        self.assertNotIn("proxy_pass", output)

    def test_disabled_route_keeps_domain_ownership(self):
        disabled = Route.from_dict(
            "app",
            {"domains": ["app.example.net"], "upstream": "http://app-gateway:8080", "enabled": False},
        )
        other = Route.from_dict(
            "other", {"domains": ["app.example.net"], "upstream": "http://other-gateway:8080"}
        )
        with self.assertRaisesRegex(ValidationError, "already owned"):
            render({"app": disabled, "other": other}, Path("/certs"))

    def test_tls_requires_certificate_files(self):
        secure = Route.from_dict(
            "app",
            {"domains": ["app.example.net"], "upstream": "http://app-gateway:8080", "tls": True},
        )
        with tempfile.TemporaryDirectory() as directory, self.assertRaisesRegex(ValidationError, "does not exist"):
            render({"app": secure}, Path(directory))

    @patch("vps_gateway.nginx.subprocess.run")
    def test_tls_certificate_must_be_current_and_cover_every_domain(self, run):
        secure = Route.from_dict(
            "app",
            {
                "domains": ["app.example.net", "www.example.net"],
                "upstream": "http://app-gateway:8080",
                "tls": True,
            },
        )
        with tempfile.TemporaryDirectory() as directory:
            cert_dir = Path(directory) / "app.example.net"
            cert_dir.mkdir()
            certificate = cert_dir / "fullchain.pem"
            certificate.touch()
            (cert_dir / "privkey.pem").touch()
            render({"app": secure}, Path(directory))
        commands = [call.args[0] for call in run.call_args_list]
        self.assertIn(
            ["openssl", "x509", "-checkend", "0", "-noout", "-in", str(certificate)],
            commands,
        )
        self.assertIn(
            ["openssl", "x509", "-checkhost", "www.example.net", "-noout", "-in", str(certificate)],
            commands,
        )

    @patch("vps_gateway.nginx.subprocess.run")
    def test_rejects_certificate_hostname_mismatch(self, run):
        run.side_effect = [None, subprocess.CalledProcessError(1, ["openssl"], stderr="mismatch")]
        secure = Route.from_dict(
            "app", {"domains": ["app.example.net"], "upstream": "http://app-gateway:8080", "tls": True}
        )
        with tempfile.TemporaryDirectory() as directory:
            cert_dir = Path(directory) / "app.example.net"
            cert_dir.mkdir()
            (cert_dir / "fullchain.pem").touch()
            (cert_dir / "privkey.pem").touch()
            with self.assertRaisesRegex(ValidationError, "does not cover app.example.net"):
                render({"app": secure}, Path(directory))

    def test_rejects_duplicate_domain(self):
        other = Route.from_dict(
            "other",
            {"domains": ["app.example.net"], "upstream": "http://other-gateway:8080"},
        )
        with self.assertRaisesRegex(ValidationError, "already owned"):
            render({"app": self.route, "other": other}, Path("/certs"))

    @patch("vps_gateway.nginx.subprocess.run")
    def test_restores_previous_config_when_nginx_rejects_candidate(self, run):
        run.side_effect = __import__("subprocess").CalledProcessError(1, ["nginx"], stderr="bad config")
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "routes.conf"
            target.write_text("old\n", encoding="utf-8")
            with self.assertRaisesRegex(RuntimeError, "bad config"):
                install_candidate("new\n", target, Path("/nginx.conf"), True)
            self.assertEqual("old\n", target.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
