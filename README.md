# VPS Gateway

A small, VPS-wide ingress service for routing multiple DNS names on one IPv4
and/or IPv6 address. NGINX owns public ports 80/443; a loopback-only control API
turns hostname-route declarations into validated NGINX configuration and reloads it
without dropping connections.

The same loopback endpoint serves an admin panel for managing projects, testing
upstream accessibility, switching projects into maintenance mode, reloading the
gateway, and changing the administrator password.

## What it owns

- public HTTP/HTTPS and hostname routing;
- Let's Encrypt certificates and renewal;
- the first and only trust boundary for client forwarding headers;
- a closed default route for unknown hostnames.

Upstream services still own their internal routing, authentication, storage,
backups, and release management.

## Environment selection

Requirements: Docker Engine with Compose, `curl`, Python 3, and OpenSSL.

```sh
./scripts/setup                    # test is the default
./scripts/setup --production       # production is always explicit
```

Test and production use independent runtime profiles, Compose namespaces, host
ports, Docker networks, volumes, ACME endpoints, and installation roots. Setup
creates `.env.test` or `.env.production`, generates the API token, and keeps the
management port on loopback. Review `LETSENCRYPT_EMAIL` before enrolling a
certificate. Private profiles must remain mode `0600`.

Setup prints a random admin bootstrap password exactly once. Open the panel
locally on the VPS or through an SSH tunnel and change that password immediately:

```sh
ssh -L 9080:127.0.0.1:9080 administrator@your-vps
# Then open http://127.0.0.1:9080/admin/
```

For the default test target, forward and open port `19080` instead. The panel
must remain loopback-only; do not publish it through a hostname route.

Remote targets use equally separate origin profiles:

```sh
./deploy.sh --configure                 # test server
./deploy.sh --production --configure    # production server
./update.sh                             # update test
./update.sh --production                # update production
```

Before deploying changed code, advance the coordinated release version with
`./set-version.sh patch|minor|major`.

See [deployment documentation](docs/deployment/DEPLOYMENT.md) for immutable
signed release activation, one-time deploy-user provisioning, first-server
initialization, and rollback.

## Connect an upstream

Before connecting, point the hostname's A and/or AAAA record at the VPS and join
the upstream gateway service to the external `vps-ingress` network. Give
it a unique alias and stop publishing its ports on the host:

```yaml
services:
  gateway:
    networks:
      ingress:
        aliases: [app-gateway]

networks:
  ingress:
    name: vps-ingress
    external: true
```

`scripts/setup` creates this as a Docker-internal network and rejects an
existing network that permits external routing. Upstream hosts must be a single
DNS-compatible alias such as `app-gateway`; IP addresses and dotted hostnames
are rejected. The gateway uses a separate project-local edge network for public
port publishing and Certbot connectivity.

Then create the HTTP route, obtain a certificate, and switch it to HTTPS:

```sh
./scripts/connect-route --test app app-test.example.net http://app-test-gateway:8080
./scripts/connect-route --production app app.example.net http://app-gateway:8080
```

Upstreams intentionally accept only `http://` targets: TLS is terminated once,
at this gateway, and the shared Docker network is the private transport. This
avoids disabled certificate verification or a second, competing certificate
lifecycle between proxy layers.

The operation intentionally leaves a working HTTP route if ACME enrollment
fails, so DNS can be corrected and the same command retried.

Disabling a project through the panel or API retains ownership of its declared
hostnames and returns a fixed HTTP 503 maintenance page with `Retry-After: 300`.
For TLS projects, the existing certificate remains in use.

For CI or custom automation, apply JSON directly:

```sh
cat >route.json <<'JSON'
{
  "domains": ["app.example.net"],
  "upstream": "http://app-gateway:8080",
  "tls": true,
  "websocket": false,
  "max_body_mb": 2
}
JSON
./scripts/gatewayctl --test apply app route.json
./scripts/gatewayctl --test list
```

See [`openapi.yaml`](openapi.yaml) for the complete API contract.

## Downstream proxy contract

The central gateway overwrites `Host`, `X-Real-IP`, and every
`X-Forwarded-*` header. An upstream gateway connected by plain HTTP must not
replace `X-Forwarded-Proto` with its own `$scheme`; it must preserve the value
received from this trusted gateway. Configure the upstream to trust forwarded
headers only from the `vps-ingress` network. Do not expose that internal listener
on a host interface.

This is required for secure cookies, redirects, origin checks, and correct audit
addresses. Apply this compatibility change to every upstream before moving its
public 80/443 bindings to this gateway.

## Safe migration of an existing public hostname

1. Back up the current certificate and deployment configuration.
2. Deploy this gateway without starting it; create `vps-ingress`.
3. Join the upstream gateway to `vps-ingress`, enable its behind-ingress mode, and
   test it through the Docker network.
4. Import or reissue the existing hostname certificate into this gateway's
   `letsencrypt` volume.
5. Stop the old public gateway binding, start this gateway immediately, then
   apply the hostname route with TLS enabled.
6. Verify IPv4 and IPv6, certificate SANs, redirects, API calls, real client IP,
   and WebSocket behavior if used.

Only one Compose project can own host ports 80 and 443 at a time, so the cutover
needs a short maintenance window unless a temporary alternate-IP ingress is
available.

## Certificate renewal

Install the parameterized unit and the matching non-secret environment mapping:

```sh
sudo install -m 0644 deploy/systemd/vps-gateway-renew@.* /etc/systemd/system/
sudo install -d -m 0755 /etc/vps-gateway
sudo install -m 0644 deploy/systemd/production.conf.example /etc/vps-gateway/production.conf
sudo systemctl daemon-reload
sudo systemctl enable --now vps-gateway-renew@production.timer
```

The timer asks Certbot to renew twice daily and reloads NGINX only after Certbot
returns successfully. A reload always validates the full candidate first.

## Operations and recovery

```sh
docker compose --env-file .env.test ps
docker compose --env-file .env.test logs --tail=200 gateway
./scripts/gatewayctl --test list
./scripts/gatewayctl --production reload
docker compose --env-file .env.production exec gateway nginx -t -c /etc/nginx/nginx.conf
```

Route state lives in the `gateway-state` volume and certificates in the
`letsencrypt` volume. Back up both. Route updates are serialized in-process,
validated with `nginx -t`, atomically installed, and rolled back when validation
or reload fails. Unknown HTTP hosts are closed with status 444; unknown TLS hosts
receive 421 using a short-lived local fallback certificate.

## Development

```sh
make validate
docker compose --env-file infrastructure/.env.test.example config --quiet
docker compose --env-file infrastructure/.env.production.example config --quiet
docker build -t vps-gateway:dev .
```

New agents and contributors should start at
[`.agents/ONBOARDING.md`](.agents/ONBOARDING.md); the primary documentation index
is [`docs/README.md`](docs/README.md).
