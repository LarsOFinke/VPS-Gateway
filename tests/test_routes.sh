#!/usr/bin/env bash
# shellcheck disable=SC2016 # Assertions intentionally match literal NGINX variables.
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/lib/routes.sh"
temporary="$(mktemp -d)"
trap 'rm -rf -- "$temporary"' EXIT

assert_invalid() {
  if "$@"; then
    echo "unexpectedly accepted invalid input: $*" >&2
    exit 1
  fi
}

gateway_validate_route_id storefront
assert_invalid gateway_validate_route_id 'Storefront'
gateway_validate_domain storefront.example.org
assert_invalid gateway_validate_domain 'https://storefront.example.org'
gateway_validate_alias storefront-web
assert_invalid gateway_validate_alias 'storefront_web'
gateway_validate_port 8080
assert_invalid gateway_validate_port 70000

gateway_render_route "$temporary/http.conf" storefront storefront.example.org storefront-web 8080 false
grep -Fqx '    server_name storefront.example.org;' "$temporary/http.conf"
grep -Fqx '        return 503;' "$temporary/http.conf"
if grep -q 'proxy_pass' "$temporary/http.conf"; then
  echo 'HTTP bootstrap route unexpectedly exposes the upstream' >&2
  exit 1
fi
if grep -q 'ssl_certificate' "$temporary/http.conf"; then
  echo 'HTTP bootstrap route unexpectedly references a certificate' >&2
  exit 1
fi

gateway_render_route "$temporary/tls.conf" storefront storefront.example.org storefront-web 8080 true
grep -Fqx '    ssl_certificate /etc/letsencrypt/live/storefront/fullchain.pem;' "$temporary/tls.conf"
grep -Fqx '    location / { return 308 https://$host$request_uri; }' "$temporary/tls.conf"
grep -Fqx '        set $gateway_upstream http://storefront-web:8080;' "$temporary/tls.conf"
grep -Fqx '        proxy_set_header X-Forwarded-For $remote_addr;' "$temporary/tls.conf"
grep -Fqx '        proxy_set_header X-Forwarded-Port $gateway_forwarded_port;' "$temporary/tls.conf"

GATEWAY_ROUTES_DIR="$temporary/routes"
mkdir "$GATEWAY_ROUTES_DIR"
printf '%s\n' '# old route' >"$GATEWAY_ROUTES_DIR/storefront.conf"
GATEWAY_ROOT_DIR="$ROOT_DIR"
GATEWAY_RUNTIME_CONFIG_FILE="$temporary/runtime.env"
gateway_compose() { return 1; }
if gateway_apply_route_file "$temporary/tls.conf" storefront >/dev/null 2>&1; then
  echo 'invalid NGINX candidate was accepted' >&2
  exit 1
fi
grep -Fqx '# old route' "$GATEWAY_ROUTES_DIR/storefront.conf"
if gateway_apply_route_file "$temporary/tls.conf" second-route >/dev/null 2>&1; then
  echo 'invalid new NGINX route was accepted' >&2
  exit 1
fi
[[ ! -e "$GATEWAY_ROUTES_DIR/second-route.conf" ]]
[[ ! -e "$GATEWAY_ROUTES_DIR/.second-route.next" ]]
echo 'routes: OK'
