#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf -- "$temporary"' EXIT
mkdir -p "$temporary/scripts/lib" "$temporary/infrastructure" "$temporary/bin"
cp "$ROOT_DIR/scripts/setup" "$temporary/scripts/setup"
cp "$ROOT_DIR/scripts/lib/target.sh" "$temporary/scripts/lib/target.sh"

config="$temporary/.env.test"
printf '%s\n' \
  'GATEWAY_ENVIRONMENT=test' \
  'COMPOSE_PROJECT_NAME=vps-gateway-test' \
  'GATEWAY_API_TOKEN=0123456789abcdef0123456789abcdef' \
  'GATEWAY_API_PORT=19080' \
  'GATEWAY_HTTP_PORT=18080' \
  'GATEWAY_HTTPS_PORT=18443' \
  'GATEWAY_INGRESS_NETWORK=vps-ingress-test' >"$config"
chmod 0600 "$config"

cp "$ROOT_DIR/tests/fixtures/fake-docker.sh" "$temporary/bin/docker"
chmod +x "$temporary/bin/docker"
export PATH="$temporary/bin:$PATH" FAKE_DOCKER_LOG="$temporary/docker.log"

export FAKE_NETWORK_EXISTS=true FAKE_NETWORK_INTERNAL=false
if "$temporary/scripts/setup" --test --config "$config" >"$temporary/output" 2>&1; then
  echo 'setup accepted a non-internal ingress network' >&2
  exit 1
fi
grep -q 'Ingress network must be internal' "$temporary/output"
if grep -q '^compose ' "$FAKE_DOCKER_LOG"; then
  echo 'setup started Compose after rejecting the network' >&2
  exit 1
fi

: >"$FAKE_DOCKER_LOG"
export FAKE_NETWORK_EXISTS=false FAKE_NETWORK_INTERNAL=true
"$temporary/scripts/setup" --test --config "$config" >/dev/null
grep -q '^network create --driver bridge --internal vps-ingress-test$' "$FAKE_DOCKER_LOG"
grep -q '^compose .* up -d --build gateway$' "$FAKE_DOCKER_LOG"
echo 'setup network: OK'
