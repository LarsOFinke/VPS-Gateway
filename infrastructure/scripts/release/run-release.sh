#!/usr/bin/env bash
set -Eeuo pipefail

[[ "$EUID" -eq 0 ]] || { echo '[runner] Root execution through sudo is required.' >&2; exit 1; }
[[ $# -eq 5 ]] || { echo 'usage: vps-gateway-run-release TARGET INSTALL_ROOT ARTIFACT CHECKSUM SIGNATURE' >&2; exit 2; }
target="$1"; requested_root="$2"; artifact="$3"; checksum="$4"; signature="$5"
config=/etc/vps-gateway/deploy.conf
[[ -f "$config" && ! -L "$config" && "$(stat -c '%U:%G:%a' "$config")" == root:root:600 ]] || {
  echo '[runner] Root-owned deployment configuration is missing or unsafe.' >&2
  exit 1
}
# shellcheck disable=SC1090
source "$config"
[[ "${SUDO_USER:-}" == "$GATEWAY_DEPLOY_USER" ]] || { echo '[runner] Unexpected invoking user.' >&2; exit 1; }
case "$target" in
  test) allowed_root="$GATEWAY_TEST_INSTALL_ROOT"; allowed_stage="$GATEWAY_TEST_STAGE" ;;
  production) allowed_root="$GATEWAY_PRODUCTION_INSTALL_ROOT"; allowed_stage="$GATEWAY_PRODUCTION_STAGE" ;;
  *) echo '[runner] Invalid target.' >&2; exit 2 ;;
esac
[[ "$requested_root" == "$allowed_root" ]] || { echo '[runner] Install root is not authorized for this target.' >&2; exit 1; }
for file in "$artifact" "$checksum" "$signature"; do
  [[ -f "$file" && ! -L "$file" ]] || { echo "[runner] Input is missing or unsafe: $file" >&2; exit 1; }
  [[ "$(dirname "$(realpath -m "$file")")" == "$allowed_stage" ]] || { echo '[runner] Input is outside the authorized stage.' >&2; exit 1; }
  [[ "$(stat -c '%U' "$file")" == "$GATEWAY_DEPLOY_USER" ]] || { echo '[runner] Input owner is not authorized.' >&2; exit 1; }
done
[[ "$(basename "$artifact")" =~ ^vps-gateway-[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz$ ]] || { echo '[runner] Artifact name is invalid.' >&2; exit 1; }
[[ "$checksum" == "$artifact.sha256" && "$signature" == "$checksum.sig" ]] || { echo '[runner] Manifest filenames do not match.' >&2; exit 1; }
openssl pkeyutl -verify -pubin -inkey /etc/vps-gateway/release-signing-key.pem \
  -rawin -in "$checksum" -sigfile "$signature" >/dev/null \
  || { echo '[runner] Release signature verification failed.' >&2; exit 1; }
exec /usr/local/lib/vps-gateway/install-release.sh "$target" "$allowed_root" "$artifact" "$checksum"
