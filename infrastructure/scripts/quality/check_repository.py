#!/usr/bin/env python3
from __future__ import annotations

import os
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
MAX_EXECUTABLE_LINES = 420
EXECUTABLE_SUFFIXES = {".py", ".sh"}
REQUIRED = (
    ".agents/ONBOARDING.md",
    ".agents/PROJECT_CACHE.md",
    ".agents/MODULE_CACHE.md",
    ".agents/DEBUGGING_CACHE.md",
    "docs/README.md",
    "docs/architecture/ARCHITECTURE.md",
    "docs/deployment/DEPLOYMENT.md",
    "docs/deployment/OPERATIONS.md",
    "docs/development/QUALITY_STANDARDS.md",
    "docs/development/TESTING.md",
    "docs/ROUTE_INTEGRATION.md",
)


def main() -> int:
    failures: list[str] = []
    for relative in REQUIRED:
        if not (ROOT / relative).is_file():
            failures.append(f"required file is missing: {relative}")
    ignored_parts = {".git", "release", "__pycache__"}
    for path in ROOT.rglob("*"):
        if not path.is_file() or any(part in ignored_parts for part in path.parts):
            continue
        relative = path.relative_to(ROOT)
        if path.name in {".env.test", ".env.production", ".env.origin.test", ".env.origin.production"}:
            failures.append(f"private profile must not be versioned: {relative}")
        if path.suffix in EXECUTABLE_SUFFIXES:
            lines = len(path.read_text(encoding="utf-8").splitlines())
            if lines > MAX_EXECUTABLE_LINES:
                failures.append(f"executable file exceeds {MAX_EXECUTABLE_LINES} lines: {relative} ({lines})")
        if path.suffix == ".sh" or path.parent.name == "scripts" or path.name in {"deploy.sh", "update.sh"}:
            if not os.access(path, os.X_OK):
                failures.append(f"script is not executable: {relative}")
    if failures:
        print("\n".join(f"[repository] {failure}" for failure in failures), file=sys.stderr)
        return 1
    print("repository structure: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
