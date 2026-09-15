# Operations

## Status

```bash
docker compose --env-file .env.test ps
docker compose --env-file .env.test logs --tail=200 gateway
./scripts/list-routes --test
docker compose --env-file .env.test exec gateway nginx -t -c /etc/nginx/nginx.conf
```

Use `--production` only after confirming the intended target. Route files are
human-readable under `GATEWAY_ROUTES_DIR`; use the scripts for mutations so
validation and rollback remain consistent.

## Certificates

`scripts/renew-certificates --<target>` runs Certbot and reloads NGINX only after
a successful renewal and syntax check. Install the target-specific systemd timer
from `deploy/systemd/`. ACME failures usually mean DNS A/AAAA or public port 80
does not reach this gateway.

## Troubleshooting

- 421/444: unknown hostname or missing route.
- 502/504: application stopped, wrong alias/port, or missing ingress attachment.
- redirect/cookie loop: application does not trust the gateway's forwarded scheme.
- NGINX rejects a route: inspect the bounded gateway log and certificate paths.

Do not delete networks or certificate volumes as a diagnostic shortcut. If an
ingress network is not internal, first drain attached containers, recreate it as
documented, and reconnect them deliberately.

## Backup and recovery

Back up the target's `letsencrypt` volume, persistent route directory, and
`shared/.env`. Certificate private keys require encrypted, access-controlled
storage. Restore the matching release and these assets, run setup, validate
NGINX, then test every hostname over both available IP families.
