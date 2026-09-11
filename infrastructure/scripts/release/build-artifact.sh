#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
output_dir="${1:-$ROOT_DIR/release}"
signing_key="${2:-}"
version="$(<"$ROOT_DIR/VERSION")"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo '[release] VERSION must be SemVer.' >&2; exit 1; }
mkdir -p "$output_dir"
artifact="$output_dir/vps-gateway-$version.tar.gz"
files=(.dockerignore AGENTS.md Dockerfile README.md VERSION compose.yml openapi.yaml config deploy docs infrastructure scripts src)
tar --create --gzip --file "$artifact" --directory "$ROOT_DIR" \
  --exclude='__pycache__' --exclude='*.pyc' "${files[@]}"
sha256sum "$artifact" >"$artifact.sha256"
if [[ -n "$signing_key" ]]; then
  [[ -f "$signing_key" ]] || { echo "[release] Signing key is missing: $signing_key" >&2; exit 1; }
  openssl pkeyutl -sign -rawin -inkey "$signing_key" \
    -in "$artifact.sha256" -out "$artifact.sha256.sig"
fi
echo "$artifact"
