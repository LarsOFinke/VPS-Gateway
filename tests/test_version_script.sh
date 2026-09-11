#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf -- "$temporary"' EXIT
mkdir -p "$temporary/src/vps_gateway" "$temporary/tests"
cp "$ROOT_DIR/set-version.sh" "$ROOT_DIR/VERSION" "$ROOT_DIR/openapi.yaml" "$temporary/"
cp "$ROOT_DIR/src/vps_gateway/__init__.py" "$temporary/src/vps_gateway/"
cp "$ROOT_DIR/tests/test_version.py" "$temporary/tests/"
current="$(<"$temporary/VERSION")"
expected="$(python3 -c 'import sys; a,b,c=map(int,sys.argv[1].split(".")); print(f"{a}.{b}.{c+1}")' "$current")"
"$temporary/set-version.sh" patch >/dev/null
[[ "$(<"$temporary/VERSION")" == "$expected" ]]
grep -q "__version__ = \"$expected\"" "$temporary/src/vps_gateway/__init__.py"
grep -q "^  version: $expected$" "$temporary/openapi.yaml"
echo 'version update: OK'
