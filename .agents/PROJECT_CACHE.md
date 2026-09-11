# Project cache for repository agents

> Reviewed 2026-09-11. This is a navigation cache, not an implementation source.
> Source, tests, and primary documentation take precedence.

## Project overview

- Product: VPS-wide hostname-routing and TLS gateway. Read `VERSION` live.
- Data plane: NGINX on container ports 8080/8443, published to target-specific
  host ports.
- Control plane: Python 3 standard-library HTTP API on container port 9080,
  published only to `127.0.0.1`.
- State: versioned JSON route declarations in the Compose `gateway-state`
  volume; generated NGINX configuration is ephemeral and rebuilt at startup.
- TLS: Certbot writes the shared `letsencrypt` and `acme-webroot` volumes.
- Connectivity: only application gateway services join the external,
  target-specific Docker-internal ingress network. Route upstreams are limited
  to single DNS-compatible aliases on that network. A separate project-local
  edge network carries published ports and Certbot connectivity.

## Repository map

```text
src/vps_gateway/          API, validation, persistence, NGINX rendering
config/                   static NGINX base configuration
scripts/                  target-side setup, API client, ACME workflows
infrastructure/scripts/   quality and origin/release automation
tests/                    Python and shell contract tests
deploy/systemd/           certificate renewal service/timer templates
docs/                     architecture, development, integration, operations
.agents/                  navigation, debugging cache, scope-aware gates
```

## Environment model

| Concern | Test | Production |
| --- | --- | --- |
| Explicit flag | optional/default | required `--production` |
| Runtime profile | `.env.test` | `.env.production` |
| Origin profile | `.env.origin.test` | `.env.origin.production` |
| Compose project | `vps-gateway-test` | `vps-gateway` |
| Host ports | 18080/18443 by default | 80/443 |
| Control API | loopback 19080 | loopback 9080 |
| Ingress network | `vps-ingress-test` | `vps-ingress` |
| ACME | Let's Encrypt staging | Let's Encrypt production |
| Install root | `/srv/vps-gateway-test` | `/srv/vps-gateway` |

The runtime profile declares `GATEWAY_ENVIRONMENT`; loaders reject a mismatch
with the selected target. Both selectors reject combined `--test --production`.
Private profiles require mode 0600.

## Operational flow

- Local/target setup: `scripts/setup` selects the target, generates a strong API
  token when the profile is new, creates or verifies the exact internal ingress
  network, starts the correct Compose project, and runs the health check.
- Route connection: `scripts/connect-route` creates an HTTP route, runs
  Certbot against the selected ACME server, then enables HTTPS only after the
  certificate exists.
- API automation: `scripts/gatewayctl` selects the same target and calls the
  loopback API with the profile bearer token.
- Origin deployment: `deploy.sh` and `update.sh` default to test, build a signed,
  checksummed artifact, transfer it over SSH, and invoke the root-owned target
  runner constrained to the selected stage and install root.
- Target release: `releases/<version>`, `current` symlink, and `shared/.env`.
  Activation restores and verifies the prior service when startup fails, or
  stops the failed project when no prior release exists.
- First remote deployment initializes `shared/.env` but deliberately stops so an
  operator can review it before activation.

## Security invariants

- Unknown HTTP hosts close with 444; unknown TLS hosts receive 421 using a local
  fallback certificate.
- The central gateway overwrites forwarded headers. Downstream applications may
  preserve those values only on listeners reachable exclusively from the trusted
  ingress network.
- Route IDs, DNS labels, upstreams, boolean fields, and size limits are strictly
  validated before rendering. Upstreams are `http://` Docker aliases, and the
  internal ingress network isolates the application path from external routing.
- TLS routes require an unexpired certificate covering every declared domain;
  NGINX then verifies the key and complete candidate configuration.
- The gateway container is read-only, lacks a Docker socket, and retains only the
  CHOWN/SETUID/SETGID capabilities needed for NGINX worker privilege drop.
- Release artifacts explicitly exclude secrets, caches, and generated output.

## Verification

`make validate` runs Python tests, target-selection and artifact contracts,
repository structure checks, shell syntax/ShellCheck when available, and Compose
rendering against both example targets. Container smoke checks are documented in
`docs/development/TESTING.md` because they require Docker daemon access.
