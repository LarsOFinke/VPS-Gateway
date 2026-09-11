from __future__ import annotations

import argparse
import hmac
import json
import os
import threading
from http.cookies import SimpleCookie
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlsplit

from . import __version__
from .auth import AdminAuth, Session
from .checks import check_accessibility
from .models import Route, ValidationError, validate_route_id
from .nginx import install_candidate, render
from .store import load, save


class Settings:
    def __init__(self) -> None:
        self.api_host = os.getenv("GATEWAY_API_HOST", "127.0.0.1")
        self.api_port = int(os.getenv("GATEWAY_API_PORT", "9080"))
        self.api_token = os.getenv("GATEWAY_API_TOKEN", "")
        self.state_file = Path(os.getenv("GATEWAY_STATE_FILE", "/var/lib/vps-gateway/routes.json"))
        self.admin_file = Path(os.getenv("GATEWAY_ADMIN_FILE", "/var/lib/vps-gateway/admin.json"))
        self.admin_password_hash = os.getenv("GATEWAY_ADMIN_PASSWORD_HASH", "")
        self.nginx_file = Path(os.getenv("GATEWAY_NGINX_FILE", "/etc/vps-gateway/routes.conf"))
        self.nginx_config = Path(os.getenv("GATEWAY_NGINX_CONFIG", "/etc/nginx/nginx.conf"))
        self.cert_root = Path(os.getenv("GATEWAY_CERT_ROOT", "/etc/letsencrypt/live"))


class Controller:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.lock = threading.RLock()
        self.routes = load(settings.state_file)

    def initialize(self) -> None:
        with self.lock:
            content = render(self.routes, self.settings.cert_root)
            install_candidate(content, self.settings.nginx_file, self.settings.nginx_config, False)

    def list(self) -> list[dict[str, object]]:
        with self.lock:
            return [self.routes[key].as_dict() for key in sorted(self.routes)]

    def get(self, route_id: str) -> Route | None:
        with self.lock:
            return self.routes.get(route_id)

    def put(self, route: Route) -> None:
        with self.lock:
            candidate = dict(self.routes)
            candidate[route.id] = route
            self._apply(candidate)

    def delete(self, route_id: str) -> bool:
        with self.lock:
            if route_id not in self.routes:
                return False
            candidate = dict(self.routes)
            del candidate[route_id]
            self._apply(candidate)
            return True

    def reload(self) -> None:
        with self.lock:
            content = render(self.routes, self.settings.cert_root)
            install_candidate(content, self.settings.nginx_file, self.settings.nginx_config, True)

    def check(self, route_id: str) -> dict[str, object] | None:
        with self.lock:
            route = self.routes.get(route_id)
        return None if route is None else check_accessibility(route)

    def _apply(self, candidate: dict[str, Route]) -> None:
        content = render(candidate, self.settings.cert_root)
        save(self.settings.state_file, candidate)
        try:
            install_candidate(content, self.settings.nginx_file, self.settings.nginx_config, True)
        except RuntimeError:
            save(self.settings.state_file, self.routes)
            raise
        self.routes = candidate


class ApiServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address: tuple[str, int], controller: Controller, token: str, admin: AdminAuth) -> None:
        super().__init__(address, Handler)
        self.controller = controller
        self.token = token
        self.admin = admin


class Handler(BaseHTTPRequestHandler):
    server: ApiServer
    protocol_version = "HTTP/1.1"

    def do_GET(self) -> None:
        path = urlsplit(self.path).path
        if path in {"/admin", "/admin/", "/admin/app.js", "/admin/styles.css"}:
            self._admin_asset(path)
            return
        if path == "/v1/health":
            self._json(HTTPStatus.OK, {"status": "ok", "version": __version__})
            return
        if path == "/v1/admin/session":
            session = self._admin_session()
            if session is None:
                self._error(HTTPStatus.UNAUTHORIZED, "admin login required")
            else:
                self._json(
                    HTTPStatus.OK,
                    {"authenticated": True, "csrf": session.csrf, "must_change_password": self.server.admin.must_change},
                )
            return
        if not self._authorized():
            return
        if path == "/v1/routes":
            self._json(HTTPStatus.OK, {"routes": self.server.controller.list()})
            return
        route_id = self._route_id(path)
        if route_id is not None:
            route = self.server.controller.get(route_id)
            if route is None:
                self._error(HTTPStatus.NOT_FOUND, "route not found")
            else:
                self._json(HTTPStatus.OK, route.as_dict())
            return
        self._error(HTTPStatus.NOT_FOUND, "endpoint not found")

    def do_PUT(self) -> None:
        if not self._authorized(mutation=True):
            return
        route_id = self._route_id(urlsplit(self.path).path)
        if route_id is None:
            self._error(HTTPStatus.NOT_FOUND, "endpoint not found")
            return
        try:
            route = Route.from_dict(route_id, self._read_json())
            created = self.server.controller.get(route_id) is None
            self.server.controller.put(route)
        except ValidationError as error:
            self._error(HTTPStatus.UNPROCESSABLE_ENTITY, str(error))
            return
        except RuntimeError as error:
            self._error(HTTPStatus.CONFLICT, str(error))
            return
        self._json(HTTPStatus.CREATED if created else HTTPStatus.OK, route.as_dict())

    def do_DELETE(self) -> None:
        if not self._authorized(mutation=True):
            return
        route_id = self._route_id(urlsplit(self.path).path)
        if route_id is None:
            self._error(HTTPStatus.NOT_FOUND, "endpoint not found")
            return
        try:
            deleted = self.server.controller.delete(route_id)
        except RuntimeError as error:
            self._error(HTTPStatus.CONFLICT, str(error))
            return
        if deleted:
            self._empty(HTTPStatus.NO_CONTENT)
        else:
            self._error(HTTPStatus.NOT_FOUND, "route not found")

    def do_POST(self) -> None:
        path = urlsplit(self.path).path
        if path == "/v1/admin/login":
            self._admin_login()
            return
        if path == "/v1/admin/logout":
            if self._authorized(mutation=True, allow_password_change=True):
                self.server.admin.logout(self._session_token())
                self._empty(HTTPStatus.NO_CONTENT, {"Set-Cookie": self._expired_cookie()})
            return
        if path == "/v1/admin/password":
            self._admin_password()
            return
        route_id = self._check_route_id(path)
        if route_id is not None:
            if not self._authorized(mutation=True):
                return
            result = self.server.controller.check(route_id)
            if result is None:
                self._error(HTTPStatus.NOT_FOUND, "route not found")
            else:
                self._json(HTTPStatus.OK, result)
            return
        if not self._authorized(mutation=True):
            return
        if path != "/v1/reload":
            self._error(HTTPStatus.NOT_FOUND, "endpoint not found")
            return
        try:
            self.server.controller.reload()
        except (RuntimeError, ValidationError) as error:
            self._error(HTTPStatus.CONFLICT, str(error))
            return
        self._empty(HTTPStatus.NO_CONTENT)

    def log_message(self, fmt: str, *args: object) -> None:
        print(json.dumps({"component": "api", "client": self.client_address[0], "message": fmt % args}), flush=True)

    def _authorized(self, mutation: bool = False, allow_password_change: bool = False) -> bool:
        supplied = self.headers.get("Authorization", "")
        expected = f"Bearer {self.server.token}"
        if self.server.token and hmac.compare_digest(supplied, expected):
            return True
        session = self._admin_session()
        if session is None:
            self._error(HTTPStatus.UNAUTHORIZED, "valid bearer token or admin login required")
            return False
        if self.server.admin.must_change and not allow_password_change:
            self._error(HTTPStatus.FORBIDDEN, "change the bootstrap password before managing projects")
            return False
        if mutation and not hmac.compare_digest(self.headers.get("X-CSRF-Token", ""), session.csrf):
            self._error(HTTPStatus.FORBIDDEN, "valid CSRF token required")
            return False
        return True

    def _admin_login(self) -> None:
        try:
            value = self._read_json()
            if not isinstance(value, dict) or set(value) != {"password"} or not isinstance(value["password"], str):
                raise ValidationError("password is required")
            session = self.server.admin.login(value["password"])
        except ValidationError as error:
            self._error(HTTPStatus.UNPROCESSABLE_ENTITY, str(error))
            return
        if session is None:
            self._error(HTTPStatus.UNAUTHORIZED, "invalid admin password")
            return
        self._json(
            HTTPStatus.OK,
            {"authenticated": True, "csrf": session.csrf, "must_change_password": self.server.admin.must_change},
            {"Set-Cookie": self._session_cookie(session)},
        )

    def _admin_password(self) -> None:
        if not self._authorized(mutation=True, allow_password_change=True):
            return
        try:
            value = self._read_json()
            if not isinstance(value, dict) or set(value) != {"current_password", "new_password"}:
                raise ValidationError("current_password and new_password are required")
            current, new = value["current_password"], value["new_password"]
            if not isinstance(current, str) or not isinstance(new, str):
                raise ValidationError("password values must be strings")
            self.server.admin.change_password(current, new, self._session_token())
        except ValidationError as error:
            self._error(HTTPStatus.UNPROCESSABLE_ENTITY, str(error))
            return
        self._empty(HTTPStatus.NO_CONTENT)

    def _admin_session(self) -> Session | None:
        token = self._session_token()
        return self.server.admin.authenticate(token) if token else None

    def _session_token(self) -> str:
        try:
            cookie = SimpleCookie(self.headers.get("Cookie", ""))
            return cookie["gateway_admin"].value if "gateway_admin" in cookie else ""
        except Exception:
            return ""

    def _session_cookie(self, session: Session) -> str:
        return f"gateway_admin={session.token}; Path=/; HttpOnly; SameSite=Strict; Max-Age=28800"

    def _expired_cookie(self) -> str:
        return "gateway_admin=; Path=/; HttpOnly; SameSite=Strict; Max-Age=0"

    def _route_id(self, path: str) -> str | None:
        prefix = "/v1/routes/"
        if not path.startswith(prefix) or "/" in path[len(prefix) :]:
            return None
        try:
            return validate_route_id(unquote(path[len(prefix) :]))
        except ValidationError:
            return None

    def _check_route_id(self, path: str) -> str | None:
        prefix, suffix = "/v1/routes/", "/check"
        if not path.startswith(prefix) or not path.endswith(suffix):
            return None
        return self._route_id(path[: -len(suffix)])

    def _read_json(self) -> object:
        content_type = self.headers.get("Content-Type", "").split(";", 1)[0].strip()
        if content_type != "application/json":
            raise ValidationError("Content-Type must be application/json")
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError as error:
            raise ValidationError("Content-Length is invalid") from error
        if not 1 <= length <= 65536:
            raise ValidationError("request body must contain 1 to 65536 bytes")
        try:
            return json.loads(self.rfile.read(length))
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            raise ValidationError("request body is not valid JSON") from error

    def _error(self, status: HTTPStatus, message: str) -> None:
        self.close_connection = True
        self._json(status, {"error": {"status": status.value, "message": message}})

    def _json(self, status: HTTPStatus, payload: object, headers: dict[str, str] | None = None) -> None:
        body = json.dumps(payload, separators=(",", ":")).encode()
        self.send_response(status.value)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        for key, value in (headers or {}).items():
            self.send_header(key, value)
        if self.close_connection:
            self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)

    def _empty(self, status: HTTPStatus, headers: dict[str, str] | None = None) -> None:
        self.send_response(status.value)
        self.send_header("Content-Length", "0")
        for key, value in (headers or {}).items():
            self.send_header(key, value)
        self.end_headers()

    def _admin_asset(self, path: str) -> None:
        name = "index.html" if path in {"/admin", "/admin/"} else path.rsplit("/", 1)[-1]
        content_types = {"index.html": "text/html; charset=utf-8", "app.js": "text/javascript; charset=utf-8", "styles.css": "text/css; charset=utf-8"}
        asset = Path(__file__).with_name("static") / name
        try:
            body = asset.read_bytes()
        except OSError:
            self._error(HTTPStatus.NOT_FOUND, "admin asset not found")
            return
        self.send_response(HTTPStatus.OK.value)
        self.send_header("Content-Type", content_types[name])
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("Content-Security-Policy", "default-src 'self'; style-src 'self'; script-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'")
        self.end_headers()
        self.wfile.write(body)


def main() -> None:
    parser = argparse.ArgumentParser(description="VPS Gateway control plane")
    parser.add_argument("command", choices=("init", "serve"), nargs="?", default="serve")
    args = parser.parse_args()
    settings = Settings()
    controller = Controller(settings)
    if args.command == "init":
        controller.initialize()
        return
    if len(settings.api_token) < 32:
        raise SystemExit("GATEWAY_API_TOKEN must contain at least 32 characters")
    admin = AdminAuth(settings.admin_file, settings.admin_password_hash)
    server = ApiServer((settings.api_host, settings.api_port), controller, settings.api_token, admin)
    print(f"control API listening on {settings.api_host}:{settings.api_port}", flush=True)
    server.serve_forever()
