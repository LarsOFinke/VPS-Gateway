#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf -- "$temporary"' EXIT
cp "$ROOT_DIR/set-version.sh" "$ROOT_DIR/VERSION" "$temporary/"
current="$(<"$temporary/VERSION")"
expected="$(python3 -c 'import sys; a,b,c=map(int,sys.argv[1].split(".")); print(f"{a}.{b}.{c+1}")' "$current")"
"$temporary/set-version.sh" patch >/dev/null
[[ "$(<"$temporary/VERSION")" == "$expected" ]]
echo 'version update: OK'
