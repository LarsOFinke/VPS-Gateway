#!/usr/bin/env bash
set -Eeuo pipefail

[[ "$EUID" -eq 0 ]] || { echo '[provision] Run as root.' >&2; exit 1; }
[[ $# -ge 3 && $# -le 7 ]] || {
  echo 'usage: provision-deploy-user.sh USER SSH_PUBLIC_KEY RELEASE_PUBLIC_KEY [TEST_ROOT PROD_ROOT TEST_STAGE PROD_STAGE]' >&2
  exit 2
}
user="$1"; ssh_public="$2"; release_public="$3"
test_root="${4:-/srv/vps-gateway-test}"
production_root="${5:-/srv/vps-gateway}"
test_stage="${6:-/var/lib/vps-gateway-deploy/test}"
production_stage="${7:-/var/lib/vps-gateway-deploy/production}"
[[ "$user" =~ ^[A-Za-z_][A-Za-z0-9_.-]{2,39}$ ]] || { echo '[provision] Invalid username.' >&2; exit 2; }
[[ -f "$ssh_public" && -f "$release_public" ]] || { echo '[provision] Public keys are required.' >&2; exit 1; }
for path in "$test_root" "$production_root" "$test_stage" "$production_stage"; do
  [[ "$path" == /* && "$path" != / ]] || { echo "[provision] Unsafe path: $path" >&2; exit 2; }
done

id "$user" >/dev/null 2>&1 || useradd --system --create-home --home-dir "/var/lib/$user" --shell /bin/bash "$user"
home="$(getent passwd "$user" | cut -d: -f6)"
install -d -m 0700 -o "$user" -g "$user" "$home/.ssh"
install -m 0600 -o "$user" -g "$user" "$ssh_public" "$home/.ssh/authorized_keys"
install -d -m 0755 /etc/vps-gateway /usr/local/lib/vps-gateway
install -m 0644 -o root -g root "$release_public" /etc/vps-gateway/release-signing-key.pem
install -m 0755 -o root -g root "$(dirname "$0")/install-release.sh" /usr/local/lib/vps-gateway/install-release.sh
install -m 0755 -o root -g root "$(dirname "$0")/run-release.sh" /usr/local/sbin/vps-gateway-run-release
install -d -m 0755 "$test_root" "$production_root"
install -d -m 0750 -o "$user" -g "$user" "$test_stage" "$production_stage"
umask 077
{
  printf 'GATEWAY_DEPLOY_USER=%q\n' "$user"
  printf 'GATEWAY_TEST_INSTALL_ROOT=%q\n' "$test_root"
  printf 'GATEWAY_PRODUCTION_INSTALL_ROOT=%q\n' "$production_root"
  printf 'GATEWAY_TEST_STAGE=%q\n' "$test_stage"
  printf 'GATEWAY_PRODUCTION_STAGE=%q\n' "$production_stage"
} >/etc/vps-gateway/deploy.conf
chown root:root /etc/vps-gateway/deploy.conf
chmod 0600 /etc/vps-gateway/deploy.conf
printf '%s ALL=(root) NOPASSWD: /usr/local/sbin/vps-gateway-run-release *\n' "$user" >/etc/sudoers.d/vps-gateway-release
chmod 0440 /etc/sudoers.d/vps-gateway-release
visudo -cf /etc/sudoers.d/vps-gateway-release >/dev/null
echo "[provision] Configured constrained signed releases for $user."
