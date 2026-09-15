# Agent onboarding – VPS Gateway

Start with:

```bash
bash .agents/scripts/project-context.sh
sed -n '1,220p' .agents/PROJECT_CACHE.md
sed -n '1,200p' .agents/MODULE_CACHE.md
bash .agents/scripts/check-changes.sh
```

## Fixed boundary

- Runtime: `Internet -> host NGINX -> 127.0.0.1 port -> application container`.
- This repository is server configuration, not a deployed service.
- Projects remain independent and publish only one loopback HTTP port.
- No gateway container, shared Docker network, API, UI, or state service.
- Test is default; production requires `--production` and an installed marker.
- NGINX/Certbot own public ports and certificates.
- Route changes validate, syntax-test, gracefully reload, and restore on failure.

| Task | Start with |
| --- | --- |
| Architecture | `docs/architecture/ARCHITECTURE.md` |
| Project connection | `docs/ROUTE_INTEGRATION.md` |
| Installation | `scripts/setup`, `docs/deployment/DEPLOYMENT.md` |
| Route generation | `scripts/lib/routes.sh`, `tests/test_routes.sh` |
| Operations | `docs/deployment/OPERATIONS.md` |
| Verification | `make validate` |

Do not commit or push unless requested.
