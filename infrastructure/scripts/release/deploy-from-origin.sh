#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# shellcheck source=../lib/origin-target.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/origin-target.sh"
gateway_origin_select_target "$ROOT_DIR" "$@"
target="$GATEWAY_ORIGIN_TARGET"
config_file="$GATEWAY_ORIGIN_CONFIG_FILE"
configure=false
artifact=""

usage() {
  echo 'usage: deploy.sh [--test|--production] [--configure] [--config FILE] [--artifact FILE]' >&2
  exit 2
}
while (($#)); do
  case "$1" in
    --test|--production) shift ;;
    --configure) configure=true; shift ;;
    --config) [[ $# -ge 2 ]] || usage; shift 2 ;;
    --artifact) [[ $# -ge 2 ]] || usage; artifact="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
done

configure_profile() {
  [[ -t 0 && -t 1 ]] || { echo '[origin] --configure requires an interactive terminal.' >&2; exit 2; }
  local default_root default_remote answer host user port remote install_root identity signing_key
  if [[ "$target" == production ]]; then
    default_root=/srv/vps-gateway; default_remote=/var/lib/vps-gateway-deploy/production
  else
    default_root=/srv/vps-gateway-test; default_remote=/var/lib/vps-gateway-deploy/test
  fi
  read -r -p "[$target] SSH host: " host
  read -r -p "[$target] SSH user [gateway-admin]: " answer; user="${answer:-gateway-admin}"
  read -r -p "[$target] SSH port [22]: " answer; port="${answer:-22}"
  read -r -p "[$target] External SSH identity (blank = SSH agent/config): " identity
  if [[ -n "$identity" && "$identity" != /* ]]; then
    identity="$HOME/.ssh/$identity"
  fi
  signing_key="$HOME/.ssh/vps-gateway-release-ed25519.pem"
  read -r -p "[$target] Release signing key [$signing_key]: " answer; signing_key="${answer:-$signing_key}"
  if [[ ! -f "$signing_key" ]]; then
    install -d -m 0700 "$(dirname "$signing_key")"
    openssl genpkey -algorithm Ed25519 -out "$signing_key"
    chmod 0600 "$signing_key"
    openssl pkey -in "$signing_key" -pubout -out "$signing_key.pub.pem"
    chmod 0644 "$signing_key.pub.pem"
    echo "[origin:$target] Generated signing key; provision $signing_key.pub.pem on the target."
  fi
  read -r -p "[$target] Remote staging directory [$default_remote]: " answer; remote="${answer:-$default_remote}"
  read -r -p "[$target] Installation root [$default_root]: " answer; install_root="${answer:-$default_root}"
  [[ -n "$host" ]] || { echo '[origin] SSH host is required.' >&2; exit 2; }
  gateway_require_external_identity "$ROOT_DIR" "$identity"
  gateway_require_external_identity "$ROOT_DIR" "$signing_key"
  umask 077
  mkdir -p "$(dirname "$config_file")"
  {
    printf 'GATEWAY_DEPLOY_ENVIRONMENT=%q\n' "$target"
    printf 'GATEWAY_DEPLOY_HOST=%q\n' "$host"
    printf 'GATEWAY_DEPLOY_USER=%q\n' "$user"
    printf 'GATEWAY_DEPLOY_PORT=%q\n' "$port"
    printf 'GATEWAY_DEPLOY_REMOTE_DIR=%q\n' "$remote"
    printf 'GATEWAY_DEPLOY_IDENTITY_FILE=%q\n' "$identity"
    printf 'GATEWAY_RELEASE_SIGNING_KEY=%q\n' "$signing_key"
    printf 'GATEWAY_DEPLOY_INSTALL_ROOT=%q\n' "$install_root"
  } >"$config_file.tmp"
  mv "$config_file.tmp" "$config_file"
  chmod 0600 "$config_file"
  echo "[origin:$target] Saved private profile $config_file"
}

if [[ "$configure" == true ]]; then
  configure_profile
elif [[ ! -f "$config_file" ]]; then
  if [[ "$target" == test && -t 0 && -t 1 ]]; then
    configure_profile
  else
    echo "[origin:$target] Missing profile: $config_file" >&2
    echo "[origin:$target] Run ./deploy.sh --$target --configure." >&2
    exit 1
  fi
fi
[[ -f "$config_file" && ! -L "$config_file" ]] || { echo '[origin] Profile must be a regular non-symlink file.' >&2; exit 1; }
[[ "$(stat -c '%a' "$config_file")" == 600 ]] || { echo '[origin] Profile must have mode 600.' >&2; exit 1; }
[[ "$(stat -c '%u' "$config_file")" == "$(id -u)" ]] || { echo '[origin] Profile must be owned by the invoking user.' >&2; exit 1; }
# shellcheck disable=SC1090
source "$config_file"
[[ "${GATEWAY_DEPLOY_ENVIRONMENT:-}" == "$target" ]] || {
  echo "[origin] Profile environment '${GATEWAY_DEPLOY_ENVIRONMENT:-unset}' does not match target '$target'." >&2
  exit 2
}
host="${GATEWAY_DEPLOY_HOST:-}"
user="${GATEWAY_DEPLOY_USER:-gateway-admin}"
port="${GATEWAY_DEPLOY_PORT:-22}"
remote_dir="${GATEWAY_DEPLOY_REMOTE_DIR:-}"
identity="${GATEWAY_DEPLOY_IDENTITY_FILE:-}"
signing_key="${GATEWAY_RELEASE_SIGNING_KEY:-}"
install_root="${GATEWAY_DEPLOY_INSTALL_ROOT:-}"
[[ -n "$host" && "$user" =~ ^[A-Za-z_][A-Za-z0-9_.-]{2,39}$ ]] || { echo '[origin] Invalid host or SSH user.' >&2; exit 2; }
[[ "$port" =~ ^[0-9]+$ && "$port" -ge 1 && "$port" -le 65535 ]] || { echo '[origin] Invalid SSH port.' >&2; exit 2; }
[[ "$remote_dir" == /* && "$remote_dir" != / && "$install_root" == /* && "$install_root" != / ]] || {
  echo '[origin] Remote and install directories must be non-root absolute paths.' >&2
  exit 2
}
gateway_require_external_identity "$ROOT_DIR" "$identity"
gateway_require_external_identity "$ROOT_DIR" "$signing_key"
[[ -z "$identity" || -f "$identity" ]] || { echo "[origin] SSH identity is missing: $identity" >&2; exit 1; }
[[ -f "$signing_key" ]] || { echo "[origin] Release signing key is missing: $signing_key" >&2; exit 1; }

if [[ -z "$artifact" ]]; then
  artifact="$("$SCRIPT_DIR/build-artifact.sh" "$ROOT_DIR/release" "$signing_key")"
fi
artifact="$(realpath "$artifact")"
checksum="$artifact.sha256"
signature="$checksum.sig"
[[ -f "$artifact" && -f "$checksum" && -f "$signature" ]] || { echo '[origin] Artifact, checksum, and signature are required.' >&2; exit 1; }
ssh_args=(-o BatchMode=yes -o IdentitiesOnly=yes -p "$port")
scp_args=(-o BatchMode=yes -o IdentitiesOnly=yes -P "$port")
if [[ -n "$identity" ]]; then
  ssh_args+=(-i "$identity"); scp_args+=(-i "$identity")
fi
echo "[origin:$target] Deploying $(basename "$artifact") to $user@$host:$install_root"
[[ "$target" != production ]] || echo '[origin:production] PRODUCTION target explicitly selected.'
remote_artifact="$remote_dir/$(basename "$artifact")"
remote_checksum="$remote_dir/$(basename "$checksum")"
remote_signature="$remote_dir/$(basename "$signature")"
# Remote command strings are deliberately quoted on the origin before transfer.
# shellcheck disable=SC2029
ssh "${ssh_args[@]}" "$user@$host" "mkdir -p -- $(printf '%q' "$remote_dir")"
scp "${scp_args[@]}" "$artifact" "$checksum" "$signature" "$user@$host:$remote_dir/"
command=(sudo /usr/local/sbin/vps-gateway-run-release "$target" "$install_root" "$remote_artifact" "$remote_checksum" "$remote_signature")
command_line=""
for word in "${command[@]}"; do printf -v quoted ' %q' "$word"; command_line+="$quoted"; done
set +e
# shellcheck disable=SC2029
ssh "${ssh_args[@]}" "$user@$host" "$command_line"
status=$?
set -e
# shellcheck disable=SC2029
ssh "${ssh_args[@]}" "$user@$host" "rm -f -- $(printf '%q' "$remote_artifact") $(printf '%q' "$remote_checksum") $(printf '%q' "$remote_signature")" || true
if [[ $status -eq 3 ]]; then
  echo "[origin:$target] Target runtime profile was initialized at $install_root/shared/.env." >&2
  echo '[origin] Review it securely on the target and rerun this deployment.' >&2
fi
exit "$status"
