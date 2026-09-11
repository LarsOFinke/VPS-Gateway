# Agent onboarding – VPS Gateway

This is the token-efficient entry point for repository work. It supplements
`AGENTS.md`; implementation and primary operational documentation remain
authoritative.

## Start in under a minute

```bash
bash .agents/scripts/project-context.sh
sed -n '1,260p' .agents/PROJECT_CACHE.md
sed -n '1,240p' .agents/MODULE_CACHE.md
bash .agents/scripts/check-changes.sh
```

For a failure, also read `.agents/DEBUGGING_CACHE.md`. Then inspect the affected
module, direct callers, tests, configuration, and relevant primary documentation.

## Fixed boundaries

- Runtime: `Internet -> VPS Gateway NGINX -> application gateway`.
- Only VPS Gateway binds public host ports 80 and 443 in production.
- The Python control plane is standard-library-only, binds through Compose to
  host loopback, and never receives the Docker socket.
- NGINX configuration is generated only from validated route models. Updates
  are serialized, syntax-tested, atomically installed, and rolled back on error.
- Public TLS and ACME belong here; upstream services must not run competing
  certificate renewal or public listeners after integration.
- Test is the default operational target. Production requires an explicit
  `--production` flag. Never infer production from DNS names, ports, or existing
  files.
- Runtime and origin profiles are separate and private: `.env.test`,
  `.env.production`, `.env.origin.test`, and `.env.origin.production`.
- Never read, print, or version bearer tokens, SSH keys, certificates, or private
  profile contents.

## Task entry points

| Task | Read or run first |
| --- | --- |
| Architecture/routing | `.agents/PROJECT_CACHE.md`, `docs/architecture/ARCHITECTURE.md` |
| Control API | `openapi.yaml`, `src/vps_gateway/app.py`, `models.py` |
| NGINX rendering | `src/vps_gateway/nginx.py`, `config/nginx.conf` |
| Test/production setup | `docs/deployment/DEPLOYMENT.md`, `scripts/lib/target.sh` |
| Remote release | `infrastructure/scripts/release/`, `.env.origin.*.example` |
| Version bump | `set-version.sh`, `VERSION`, `test_version.py` |
| Route onboarding | `docs/ROUTE_INTEGRATION.md`, `scripts/connect-route` |
| Incident/debugging | `.agents/DEBUGGING_CACHE.md`, `docs/deployment/OPERATIONS.md` |
| Tests/gates | `docs/development/TESTING.md`, `make validate` |

## Completion

Run focused tests while working and `bash .agents/scripts/check-all.sh` for a
cross-cutting change. Update this file and `PROJECT_CACHE.md` when topology,
target selection, deployment, recovery, or central entry points change. Do not
commit or push unless explicitly requested.
