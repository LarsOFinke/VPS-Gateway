#!/usr/bin/env bash
set -Eeuo pipefail

[[ "$EUID" -eq 0 ]] || {
  echo 'Run this one-time server setup with sudo.' >&2
  exit 1
}
command -v apt-get >/dev/null || {
  echo 'This setup supports Debian/Ubuntu servers with apt-get.' >&2
  exit 1
}

apt-get update
apt-get install -y nginx certbot python3-certbot-nginx
nginx -t
systemctl enable nginx
if systemctl is-active --quiet nginx; then
  systemctl reload nginx
else
  systemctl start nginx
fi

cat <<'EOF'
NGINX and Certbot are ready in their standard locations:
  /etc/nginx/sites-available
  /etc/nginx/sites-enabled
  /etc/letsencrypt

Projects can now install and enable their own NGINX site files.
EOF
