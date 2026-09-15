#!/usr/bin/env bash
# shellcheck disable=SC2016 # Assertions match literal NGINX variables.
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/lib/routes.sh"
temporary="$(mktemp -d)"
trap 'rm -rf -- "$temporary"' EXIT

assert_invalid() {
  if "$@"; then echo "unexpectedly accepted invalid input: $*" >&2; exit 1; fi
}

gateway_validate_route_id storefront
assert_invalid gateway_validate_route_id Storefront
gateway_validate_domain storefront.example.org
assert_invalid gateway_validate_domain 'https://storefront.example.org'
gateway_validate_port 18081
assert_invalid gateway_validate_port 443
assert_invalid gateway_validate_port 70000

gateway_render_route "$temporary/bootstrap.conf" storefront storefront.example.org 18081 false
grep -Fqx '    server_name storefront.example.org;' "$temporary/bootstrap.conf"
grep -Fqx '    location / { add_header Retry-After 60 always; return 503; }' "$temporary/bootstrap.conf"
if grep -q 'proxy_pass\|ssl_certificate' "$temporary/bootstrap.conf"; then
  echo 'bootstrap route exposes an upstream or missing certificate' >&2
  exit 1
fi

gateway_render_route "$temporary/tls.conf" storefront storefront.example.org 18081 true
grep -Fqx '        proxy_pass http://127.0.0.1:18081;' "$temporary/tls.conf"
grep -Fqx '    ssl_certificate /etc/letsencrypt/live/vps-storefront/fullchain.pem;' "$temporary/tls.conf"
grep -Fqx '        proxy_set_header X-Forwarded-For $remote_addr;' "$temporary/tls.conf"
grep -Fqx '        proxy_set_header X-Forwarded-Port $vps_gateway_forwarded_port;' "$temporary/tls.conf"
echo 'routes: OK'
