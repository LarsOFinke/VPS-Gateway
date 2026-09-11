from __future__ import annotations

import re
from dataclasses import dataclass
from urllib.parse import urlsplit

ROUTE_ID = re.compile(r"^[a-z][a-z0-9-]{0,62}$")
DNS_LABEL = re.compile(r"^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$")
DOCKER_ALIAS = re.compile(r"^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$")


class ValidationError(ValueError):
    pass


def validate_domain(value: str) -> str:
    domain = value.strip().lower().rstrip(".")
    if len(domain) > 253 or "." not in domain:
        raise ValidationError("domain must be a fully qualified DNS name")
    if any(not DNS_LABEL.fullmatch(label) for label in domain.split(".")):
        raise ValidationError("domain contains an invalid DNS label")
    return domain


def validate_route_id(value: str) -> str:
    if not ROUTE_ID.fullmatch(value):
        raise ValidationError("route id must match ^[a-z][a-z0-9-]{0,62}$")
    return value


def validate_upstream(value: str) -> str:
    parsed = urlsplit(value)
    if parsed.scheme != "http" or not parsed.hostname:
        raise ValidationError("upstream must be an http URL on the private ingress network")
    if parsed.username or parsed.password or parsed.query or parsed.fragment:
        raise ValidationError("upstream credentials, query, and fragment are not allowed")
    if parsed.path not in {"", "/"}:
        raise ValidationError("upstream path must be empty")
    try:
        port = parsed.port
    except ValueError as error:
        raise ValidationError("upstream port is invalid") from error
    if port is not None and not 1 <= port <= 65535:
        raise ValidationError("upstream port is invalid")
    host = parsed.hostname.lower()
    if not DOCKER_ALIAS.fullmatch(host):
        raise ValidationError("upstream host must be a single Docker network alias")
    authority = host
    if port is not None:
        authority += f":{port}"
    return f"{parsed.scheme}://{authority}"


@dataclass(frozen=True)
class Route:
    id: str
    domains: tuple[str, ...]
    upstream: str
    tls: bool = False
    websocket: bool = False
    max_body_mb: int = 2
    enabled: bool = True

    @classmethod
    def from_dict(cls, route_id: str, value: object) -> "Route":
        if not isinstance(value, dict):
            raise ValidationError("request body must be a JSON object")
        allowed = {"domains", "upstream", "tls", "websocket", "max_body_mb", "enabled"}
        unknown = set(value) - allowed
        if unknown:
            raise ValidationError(f"unknown fields: {', '.join(sorted(unknown))}")
        domains_value = value.get("domains")
        if not isinstance(domains_value, list) or not domains_value:
            raise ValidationError("domains must be a non-empty array")
        domains = tuple(dict.fromkeys(validate_domain(item) if isinstance(item, str) else _invalid_domain() for item in domains_value))
        if len(domains) > 20:
            raise ValidationError("a route may have at most 20 domains")
        upstream_value = value.get("upstream")
        if not isinstance(upstream_value, str):
            raise ValidationError("upstream must be a string")
        tls = _boolean(value, "tls", False)
        websocket = _boolean(value, "websocket", False)
        enabled = _boolean(value, "enabled", True)
        max_body_mb = value.get("max_body_mb", 2)
        if isinstance(max_body_mb, bool) or not isinstance(max_body_mb, int) or not 1 <= max_body_mb <= 100:
            raise ValidationError("max_body_mb must be an integer from 1 to 100")
        return cls(
            id=validate_route_id(route_id),
            domains=domains,
            upstream=validate_upstream(upstream_value),
            tls=tls,
            websocket=websocket,
            max_body_mb=max_body_mb,
            enabled=enabled,
        )

    def as_dict(self) -> dict[str, object]:
        return {
            "id": self.id,
            "domains": list(self.domains),
            "upstream": self.upstream,
            "tls": self.tls,
            "websocket": self.websocket,
            "max_body_mb": self.max_body_mb,
            "enabled": self.enabled,
        }


def _invalid_domain() -> str:
    raise ValidationError("every domain must be a string")


def _boolean(value: dict[str, object], key: str, default: bool) -> bool:
    result = value.get(key, default)
    if not isinstance(result, bool):
        raise ValidationError(f"{key} must be a boolean")
    return result
