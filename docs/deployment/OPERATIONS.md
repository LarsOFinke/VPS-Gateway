# Operations

## Status and routing

```bash
docker compose --env-file .env.test ps
./scripts/gatewayctl --test list
./scripts/gatewayctl --production list
```

The API always runs locally on the selected server. For remote administration,
run `gatewayctl` over SSH or use an SSH loopback tunnel; never publish port 9080.

## Logs and validation

```bash
docker compose --env-file .env.test logs --tail=200 gateway
docker compose --env-file .env.production exec gateway nginx -t -c /etc/nginx/nginx.conf
```

Keep output bounded. Access logs exclude request bodies, query payloads, cookies,
and authorization values. Treat hostnames and client addresses according to the
operational privacy policy of the hosted applications.

If setup reports that the ingress network is not internal, first disconnect any
attached containers, remove that unused network, and let `scripts/setup` recreate
it. Never remove an in-use network as a diagnostic shortcut.

## Renewal

`scripts/renew-certificates --<target>` invokes Certbot with the selected ACME
directory and reloads only after a successful renewal run. Install separate
systemd service/timer instances on each server or environment.

## Backup and recovery

Back up the target's Compose volumes for `gateway-state` and `letsencrypt` plus
`shared/.env`. The bearer token and certificate private keys require encrypted,
access-controlled backup storage. Never restore test material into production.

To recover, restore those three assets, deploy the exact corresponding release,
run `scripts/setup --<target>`, validate NGINX, and test every hostname over both
available IP families. Do not delete volumes to troubleshoot a route or ACME
failure.

An activation error normally restores the preceding release. A `CRITICAL`
rollback message means automation could not confirm that recovery; inspect the
`current` link and Compose service state before attempting another deployment.
