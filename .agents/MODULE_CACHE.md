# Module cache

| File | Responsibility |
| --- | --- |
| `setup.sh` | Install packages, validate, enable/start NGINX |
| `examples/project-site.conf` | Non-installed reference for project-owned sites |
| `README.md` | Complete normal workflow |
| `docs/ROUTE_INTEGRATION.md` | Compose and site-file ownership contract |
| `infrastructure/scripts/quality/` | Repository-only validation |

There is deliberately no routing module. Route implementation belongs to each
application repository.
