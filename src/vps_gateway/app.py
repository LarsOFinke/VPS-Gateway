from __future__ import annotations

import argparse
import hmac
import json
import os
import threading
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlsplit

from . import __version__
from .models import Route, ValidationError, validate_route_id
from .nginx import install_candidate, render
from .store import load, save


class Settings:
    def __init__(self) -> None:
        self.api_host = os.getenv("GATEWAY_API_HOST", "127.0.0.1")
        self.api_port = int(os.getenv("GATEWAY_API_PORT", "9080"))
        self.api_token = os.getenv("GATEWAY_API_TOKEN", "")
        self.state_file = Path(os.getenv("GATEWAY_STATE_FILE", "/var/lib/vps-gateway/routes.json"))
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

    def __init__(self, address: tuple[str, int], controller: Controller, token: str) -> None:
        super().__init__(address, Handler)
        self.controller = controller
        self.token = token


class Handler(BaseHTTPRequestHandler):
    server: ApiServer
    protocol_version = "HTTP/1.1"

    def do_GET(self) -> None:
        path = urlsplit(self.path).path
        if path == "/v1/health":
            self._json(HTTPStatus.OK, {"status": "ok", "version": __version__})
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
        if not self._authorized():
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
        if not self._authorized():
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
        if not self._authorized():
            return
        if urlsplit(self.path).path != "/v1/reload":
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

    def _authorized(self) -> bool:
        supplied = self.headers.get("Authorization", "")
        expected = f"Bearer {self.server.token}"
        if not self.server.token or not hmac.compare_digest(supplied, expected):
            self._error(HTTPStatus.UNAUTHORIZED, "valid bearer token required")
            return False
        return True

    def _route_id(self, path: str) -> str | None:
        prefix = "/v1/routes/"
        if not path.startswith(prefix) or "/" in path[len(prefix) :]:
            return None
        try:
            return validate_route_id(unquote(path[len(prefix) :]))
        except ValidationError:
            return None

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

    def _json(self, status: HTTPStatus, payload: object) -> None:
        body = json.dumps(payload, separators=(",", ":")).encode()
        self.send_response(status.value)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        if self.close_connection:
            self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)

    def _empty(self, status: HTTPStatus) -> None:
        self.send_response(status.value)
        self.send_header("Content-Length", "0")
        self.end_headers()


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
    server = ApiServer((settings.api_host, settings.api_port), controller, settings.api_token)
    print(f"control API listening on {settings.api_host}:{settings.api_port}", flush=True)
    server.serve_forever()
