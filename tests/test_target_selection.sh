#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/lib/target.sh"
source "$ROOT_DIR/infrastructure/scripts/lib/origin-target.sh"

gateway_select_runtime_target "$ROOT_DIR"
[[ "$GATEWAY_TARGET" == test && "$GATEWAY_RUNTIME_CONFIG_FILE" == "$ROOT_DIR/.env.test" ]]
gateway_select_runtime_target "$ROOT_DIR" --production
[[ "$GATEWAY_TARGET" == production && "$GATEWAY_RUNTIME_CONFIG_FILE" == "$ROOT_DIR/.env.production" ]]
if gateway_select_runtime_target "$ROOT_DIR" --test --production >/dev/null 2>&1; then
  echo 'mixed runtime targets were accepted' >&2
  exit 1
fi

gateway_origin_select_target "$ROOT_DIR"
[[ "$GATEWAY_ORIGIN_TARGET" == test && "$GATEWAY_ORIGIN_CONFIG_FILE" == "$ROOT_DIR/.env.origin.test" ]]
gateway_origin_select_target "$ROOT_DIR" --production
[[ "$GATEWAY_ORIGIN_TARGET" == production && "$GATEWAY_ORIGIN_CONFIG_FILE" == "$ROOT_DIR/.env.origin.production" ]]
if gateway_origin_select_target "$ROOT_DIR" --test --production >/dev/null 2>&1; then
  echo 'mixed origin targets were accepted' >&2
  exit 1
fi

temporary="$(mktemp)"
trap 'rm -f "$temporary"' EXIT
cat >"$temporary" <<'EOF'
GATEWAY_ENVIRONMENT=test
GATEWAY_API_TOKEN=0123456789abcdef0123456789abcdef
GATEWAY_ADMIN_PASSWORD_HASH=pbkdf2_sha256:test
EOF
chmod 0600 "$temporary"
gateway_load_runtime_config "$ROOT_DIR" "$temporary" test
symlink="$temporary.link"
ln -s "$temporary" "$symlink"
if gateway_load_runtime_config "$ROOT_DIR" "$symlink" test >/dev/null 2>&1; then
  echo 'a symlink runtime profile was accepted' >&2
  exit 1
fi
if gateway_load_runtime_config "$ROOT_DIR" "$temporary" production >/dev/null 2>&1; then
  echo 'a test profile was accepted for production' >&2
  exit 1
fi
echo 'target selection: OK'
