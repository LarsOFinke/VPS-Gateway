#!/usr/bin/env bash
set -Eeuo pipefail

[[ "$EUID" -eq 0 ]] || { echo '[release] Root execution through the constrained runner is required.' >&2; exit 1; }
usage() { echo 'usage: install-release.sh test|production INSTALL_ROOT ARTIFACT CHECKSUM' >&2; exit 2; }
[[ $# -eq 4 ]] || usage
target="$1"
install_root="$2"
artifact="$3"
checksum="$4"
[[ "$target" == test || "$target" == production ]] || usage
[[ "$install_root" == /* && "$install_root" != / ]] || {
  echo '[release] Install root must be a non-root absolute path.' >&2
  exit 2
}
[[ -f "$artifact" && -f "$checksum" ]] || { echo '[release] Artifact or checksum is missing.' >&2; exit 1; }

expected_name="$(awk '{print $2}' "$checksum")"
expected_hash="$(awk '{print $1}' "$checksum")"
actual_hash="$(sha256sum "$artifact" | awk '{print $1}')"
[[ "$expected_hash" == "$actual_hash" ]] || { echo '[release] Artifact checksum mismatch.' >&2; exit 1; }
[[ "$(basename "$artifact")" == "$(basename "$expected_name")" ]] || {
  echo '[release] Checksum filename mismatch.' >&2
  exit 1
}

version="$(tar -xOzf "$artifact" VERSION)"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo '[release] Artifact VERSION is invalid.' >&2; exit 1; }
releases="$install_root/releases"
shared="$install_root/shared"
release="$releases/$version"
install -d -m 0755 "$releases" "$shared"
[[ ! -e "$release" ]] || { echo "[release] Immutable release already exists: $release" >&2; exit 1; }
staging="$(mktemp -d "$releases/.staging-$version.XXXXXX")"
cleanup() { [[ ! -d "$staging" ]] || rm -rf -- "$staging"; }
trap cleanup EXIT
tar -xzf "$artifact" -C "$staging"
ln -s ../../shared/.env "$staging/.env.$target"
mv "$staging" "$release"

runtime_env="$shared/.env"
if [[ ! -f "$runtime_env" ]]; then
  install -m 0600 "$release/infrastructure/.env.$target.example" "$runtime_env"
  install -d -m 0755 "$shared/routes"
  sed -i "s|^GATEWAY_ROUTES_DIR=.*|GATEWAY_ROUTES_DIR=$shared/routes|" "$runtime_env"
  echo "[release:$target] Initialized $runtime_env. Review it on the target, then rerun deployment." >&2
  rm -rf -- "$release"
  exit 3
fi
install -d -m 0755 "$shared/routes"
if ! grep -q '^GATEWAY_ROUTES_DIR=' "$runtime_env"; then
  printf 'GATEWAY_ROUTES_DIR=%s\n' "$shared/routes" >>"$runtime_env"
elif grep -q '^GATEWAY_ROUTES_DIR=\./' "$runtime_env"; then
  sed -i "s|^GATEWAY_ROUTES_DIR=.*|GATEWAY_ROUTES_DIR=$shared/routes|" "$runtime_env"
fi
[[ "$(stat -c '%a' "$runtime_env")" == 600 ]] || { echo '[release] shared/.env must have mode 600.' >&2; exit 1; }
grep -qx "GATEWAY_ENVIRONMENT=$target" "$runtime_env" || {
  echo '[release] Runtime environment does not match the selected target.' >&2
  exit 1
}

previous="$(readlink "$install_root/current" 2>/dev/null || true)"
ln -s "$release" "$install_root/current.next"
mv -Tf "$install_root/current.next" "$install_root/current"
rollback() {
  if [[ -z "$previous" ]]; then
    rm -f -- "$install_root/current"
    docker compose --project-directory "$release" --env-file "$runtime_env" down
    return
  fi
  ln -s "$previous" "$install_root/current.rollback"
  mv -Tf "$install_root/current.rollback" "$install_root/current"
  "$install_root/current/scripts/setup" "--$target" --config "$runtime_env"
}
if ! "$install_root/current/scripts/setup" "--$target" --config "$runtime_env"; then
  echo '[release] Activation failed; restoring the preceding release.' >&2
  if ! rollback; then
    echo '[release] CRITICAL: automatic rollback failed; manual recovery is required.' >&2
  fi
  rm -rf -- "$release"
  exit 1
fi
echo "[release:$target] Activated VPS Gateway $version at $install_root/current"
