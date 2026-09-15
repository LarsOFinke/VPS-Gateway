# Project cache

> Reviewed 2026-09-15. Source and primary docs take precedence.

## Overview

- Product: VPS-wide hostname routing and public TLS.
- Runtime: one NGINX process on container ports 8080/8443.
- State: persistent, human-readable route fragments plus Certbot volumes.
- Connectivity: NGINX joins a target-specific external Docker-internal ingress
  network and a project-local edge network. Only selected application gateways
  join ingress; all other application services remain private.
- Resolution: Docker DNS aliases with variable `proxy_pass`, so application
  restarts do not prevent NGINX startup or reload.

There is intentionally no control API, browser panel, JSON store, or Docker
socket. Host scripts are the scriptable interface.

## Targets

| Concern | Test | Production |
| --- | --- | --- |
| Flag | default / `--test` | explicit `--production` |
| Runtime profile | `.env.test` | `.env.production` |
| Host ports | 18080/18443 | 80/443 |
| Ingress network | `vps-ingress-test` | `vps-ingress` |
| ACME | Let's Encrypt staging | Let's Encrypt production |
| Install root | `/srv/vps-gateway-test` | `/srv/vps-gateway` |

## Flows

- `scripts/setup`: profile and route-dir initialization, internal-network
  verification, Compose build/start, and `nginx -t`.
- `scripts/connect-route`: validated ACME-only HTTP fragment, certificate enrollment, validated
  HTTPS fragment, and reload with restoration on failure.
- `scripts/list-routes` / `remove-route`: transparent route operations.
- `scripts/renew-certificates`: Certbot renewal, syntax check, reload.
- `deploy.sh` / `update.sh`: signed immutable origin-to-target releases;
  `shared/.env` and `shared/routes` persist between versions.

## Security

Unknown hosts fail closed. Forwarding headers are overwritten. The container is
read-only and has no Docker socket. Route inputs accept only lowercase DNS-safe
identifiers and numeric ports. Test/production selectors reject ambiguity and
private profiles require mode 0600.
