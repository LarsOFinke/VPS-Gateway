from __future__ import annotations

import json
import os
from pathlib import Path

from .models import Route, ValidationError


def load(path: Path) -> dict[str, Route]:
    if not path.exists():
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise RuntimeError(f"cannot load state file {path}: {error}") from error
    if not isinstance(value, dict) or value.get("version") != 1 or not isinstance(value.get("routes"), list):
        raise RuntimeError(f"state file {path} has an unsupported format")
    routes: dict[str, Route] = {}
    try:
        for item in value["routes"]:
            if not isinstance(item, dict) or not isinstance(item.get("id"), str):
                raise ValidationError("stored route is invalid")
            route_id = item["id"]
            body = {key: content for key, content in item.items() if key != "id"}
            routes[route_id] = Route.from_dict(route_id, body)
    except ValidationError as error:
        raise RuntimeError(f"state file {path} is invalid: {error}") from error
    return routes


def save(path: Path, routes: dict[str, Route]) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "version": 1,
            "routes": [routes[key].as_dict() for key in sorted(routes)],
        }
        with temporary.open("w", encoding="utf-8") as handle:
            json.dump(payload, handle, indent=2)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    except OSError as error:
        temporary.unlink(missing_ok=True)
        raise RuntimeError(f"cannot save state file {path}: {error}") from error
