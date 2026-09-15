# Agent onboarding – VPS Gateway

## Start

```bash
bash .agents/scripts/project-context.sh
sed -n '1,240p' .agents/PROJECT_CACHE.md
sed -n '1,220p' .agents/MODULE_CACHE.md
bash .agents/scripts/check-changes.sh
```

For failures, also read `.agents/DEBUGGING_CACHE.md`. Inspect the affected flow,
callers, tests, configuration, and primary docs before editing.

## Fixed boundaries

- Runtime: `Internet -> VPS Gateway NGINX -> application gateway`.
- Only VPS-Gateway binds production ports 80/443.
- Runtime is NGINX-only. No API, UI, route database, or Docker socket.
- Each application stays in its Compose project. Only its selected HTTP service
  joins the external Docker-internal ingress network under a unique alias.
- Route changes are validated, serialized, syntax-tested, and reversible.
- Public TLS and ACME live here.
- Test is default; production requires explicit `--production`.
- Private profiles, certificates, and route files are never printed or versioned.

## Entry points

| Task | Start with |
| --- | --- |
| Architecture | `docs/architecture/ARCHITECTURE.md`, `compose.yml` |
| Route rendering | `scripts/lib/routes.sh`, `tests/test_routes.sh` |
| Application connection | `docs/ROUTE_INTEGRATION.md`, `scripts/connect-route` |
| Target setup | `scripts/setup`, `scripts/lib/target.sh` |
| Remote release | `infrastructure/scripts/release/` |
| Operations | `docs/deployment/OPERATIONS.md` |
| Full verification | `make validate` |

Do not commit or push unless requested.
