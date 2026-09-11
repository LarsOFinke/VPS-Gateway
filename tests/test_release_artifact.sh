#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf -- "$temporary"' EXIT
private_key="$temporary/release-key.pem"
public_key="$temporary/release-key.pub.pem"
openssl genpkey -algorithm Ed25519 -out "$private_key" >/dev/null 2>&1
openssl pkey -in "$private_key" -pubout -out "$public_key" >/dev/null 2>&1
artifact="$("$ROOT_DIR/infrastructure/scripts/release/build-artifact.sh" "$temporary" "$private_key")"
sha256sum --check "$artifact.sha256" >/dev/null
openssl pkeyutl -verify -pubin -inkey "$public_key" -rawin \
  -in "$artifact.sha256" -sigfile "$artifact.sha256.sig" >/dev/null
contents="$temporary/contents.txt"
tar -tzf "$artifact" >"$contents"
grep -qx 'VERSION' "$contents"
grep -qx '.dockerignore' "$contents"
grep -qx 'scripts/setup' "$contents"
if grep -Eq '(^|/)\.env\.(test|production)$|(^|/)__pycache__/|^release/' "$contents"; then
  echo 'release contains private or generated files' >&2
  exit 1
fi
echo 'release artifact: OK'
