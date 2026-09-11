from __future__ import annotations

import http.client
import time
from urllib.parse import urlsplit

from .models import Route


def check_accessibility(route: Route, timeout: float = 5.0) -> dict[str, object]:
    parsed = urlsplit(route.upstream)
    started = time.monotonic()
    connection = http.client.HTTPConnection(parsed.hostname, parsed.port or 80, timeout=timeout)
    try:
        connection.request(
            "HEAD",
            "/",
            headers={"Host": route.domains[0], "User-Agent": "VPS-Gateway-Admin/1"},
        )
        response = connection.getresponse()
        response.read()
        return {
            "accessible": True,
            "status": response.status,
            "latency_ms": round((time.monotonic() - started) * 1000),
        }
    except (OSError, http.client.HTTPException) as error:
        return {
            "accessible": False,
            "error": str(error),
            "latency_ms": round((time.monotonic() - started) * 1000),
        }
    finally:
        connection.close()
