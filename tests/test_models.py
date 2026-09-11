import unittest

from vps_gateway.models import Route, ValidationError, validate_domain, validate_upstream


class ModelTest(unittest.TestCase):
    def test_normalizes_route(self):
        route = Route.from_dict(
            "app",
            {"domains": ["App.Example.NET."], "upstream": "http://app-gateway:8080/"},
        )
        self.assertEqual(("app.example.net",), route.domains)
        self.assertEqual("http://app-gateway:8080", route.upstream)
        self.assertEqual(2, route.max_body_mb)

    def test_rejects_nginx_injection(self):
        invalid = (
            "example.com; return 200",
            "exa_mple.com",
            "localhost",
        )
        for domain in invalid:
            with self.subTest(domain=domain), self.assertRaises(ValidationError):
                validate_domain(domain)
        with self.assertRaises(ValidationError):
            validate_upstream("http://backend;return:8080")
        with self.assertRaisesRegex(ValidationError, "private ingress network"):
            validate_upstream("https://backend:8443")

    def test_upstream_requires_single_docker_alias(self):
        self.assertEqual("http://app-gateway:8080", validate_upstream("http://APP-GATEWAY:8080/"))
        invalid = (
            "http://127.0.0.1:9080",
            "http://169.254.169.254",
            "http://backend.example.net:8080",
            "http://backend_alias:8080",
        )
        for upstream in invalid:
            with self.subTest(upstream=upstream), self.assertRaisesRegex(
                ValidationError, "Docker network alias"
            ):
                validate_upstream(upstream)

    def test_rejects_unknown_fields_and_wrong_types(self):
        with self.assertRaisesRegex(ValidationError, "unknown fields"):
            Route.from_dict("app", {"domains": ["app.example"], "upstream": "http://app", "oops": 1})
        with self.assertRaisesRegex(ValidationError, "tls must be a boolean"):
            Route.from_dict("app", {"domains": ["app.example"], "upstream": "http://app", "tls": "yes"})


if __name__ == "__main__":
    unittest.main()
