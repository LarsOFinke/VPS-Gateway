#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf -- "$temporary"' EXIT
mkdir -p "$temporary/bin"
cp "$ROOT_DIR/tests/fixtures/fake-docker.sh" "$temporary/bin/docker"
chmod +x "$temporary/bin/docker"
export PATH="$temporary/bin:$PATH"
export FAKE_DOCKER_LOG="$temporary/docker.log"
export FAKE_NETWORK_EXISTS=true FAKE_NETWORK_INTERNAL=true
config="$temporary/runtime.env"

"$ROOT_DIR/scripts/setup" --test --config "$config" >"$temporary/first-output"
grep -q 'One-time admin password:' "$temporary/first-output"
grep -q '^GATEWAY_ADMIN_PASSWORD_HASH=pbkdf2_sha256:' "$config"
if grep -q 'replace-with-generated-admin-password-hash' "$config"; then
  echo 'setup retained the admin password placeholder' >&2
  exit 1
fi

"$ROOT_DIR/scripts/setup" --test --config "$config" >"$temporary/second-output"
if grep -q 'One-time admin password:' "$temporary/second-output"; then
  echo 'setup printed the bootstrap password more than once' >&2
  exit 1
fi

legacy="$temporary/legacy.env"
grep -v '^GATEWAY_ADMIN_PASSWORD_HASH=' "$config" >"$legacy"
chmod 0600 "$legacy"
"$ROOT_DIR/scripts/setup" --test --config "$legacy" >"$temporary/legacy-output"
grep -q 'One-time admin password:' "$temporary/legacy-output"
grep -q '^GATEWAY_ADMIN_PASSWORD_HASH=pbkdf2_sha256:' "$legacy"
echo 'setup admin: OK'
