#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ $# -eq 1 ]] || { echo 'usage: set-version.sh patch|minor|major|X.Y.Z' >&2; exit 2; }
current="$(<"$ROOT_DIR/VERSION")"
requested="$1"
next="$(python3 - "$current" "$requested" <<'PY'
import re, sys
current = tuple(map(int, sys.argv[1].split('.')))
requested = sys.argv[2]
if requested == 'patch': candidate = (current[0], current[1], current[2] + 1)
elif requested == 'minor': candidate = (current[0], current[1] + 1, 0)
elif requested == 'major': candidate = (current[0] + 1, 0, 0)
elif re.fullmatch(r'\d+\.\d+\.\d+', requested): candidate = tuple(map(int, requested.split('.')))
else: raise SystemExit('invalid version selector')
if candidate <= current: raise SystemExit('new version must be greater than current version')
print('.'.join(map(str, candidate)))
PY
)"
temporary="$(mktemp -d)"
cp "$ROOT_DIR/VERSION" "$temporary/VERSION"
rollback() {
  cp "$temporary/VERSION" "$ROOT_DIR/VERSION"
}
trap 'rollback; rm -rf -- "$temporary"' ERR
printf '%s\n' "$next" >"$ROOT_DIR/VERSION"
trap - ERR
rm -rf -- "$temporary"
echo "Version updated: $current -> $next"
