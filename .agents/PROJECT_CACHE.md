# Project cache

> Reviewed 2026-09-15. Primary source and docs take precedence.

VPS-Gateway is a small host NGINX configuration. It routes several DNS names on
one VPS address to unique application ports bound on `127.0.0.1`.

There is no runtime built by this repository. Debian/Ubuntu NGINX and Certbot
run directly on the server. Docker remains entirely inside application projects;
stable host ports remove any dependency on container addresses or networks.

## State

- `/etc/nginx/conf.d/00-vps-gateway.conf`: installed base/default servers.
- `/etc/vps-gateway/sites/*.conf`: generated hostname routes.
- `/etc/vps-gateway/environment`: `test` or `production` safety marker.
- `/etc/vps-gateway/letsencrypt-email`: ACME contact.
- `/etc/letsencrypt`: certificate state and private keys.
- `/etc/letsencrypt/renewal-hooks/deploy/vps-gateway-reload`: checked NGINX reload.

## Commands

- `scripts/setup`: install base config and activate host NGINX.
- `scripts/connect-route`: ACME bootstrap, certificate, HTTPS route, reload.
- `scripts/list-routes`: display route metadata.
- `scripts/remove-route`: remove one site with restoration on failure.
- `scripts/renew-certificates`: manual Certbot renewal and checked reload.

Test is the default selector. Every production operation must state
`--production`, which must agree with the server marker.
