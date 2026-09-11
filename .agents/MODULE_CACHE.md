# Module cache

| Module | Responsibility | Primary tests/checks |
| --- | --- | --- |
| `app.py` | HTTP transport, bearer auth, controller serialization | controller tests, container smoke |
| `models.py` | Strict route/domain/upstream validation | `test_models.py` |
| `nginx.py` | Deterministic rendering and atomic test/reload/rollback | `test_nginx.py` |
| `store.py` | Atomic versioned JSON state | `test_store.py`, controller rollback tests |
| `config/nginx.conf` | Static listeners, closed defaults, logs, DNS, protocol maps | Compose render, image smoke |
| `scripts/lib/target.sh` | Runtime test/production selection and private profile loading | `test_target_selection.sh` |
| `scripts/setup` | Target-local Compose/network bootstrap and health | shell gates, deployment smoke |
| `gatewayctl` | Scriptable authenticated API client | API container smoke |
| `connect-route` | HTTP route -> ACME -> TLS transition | shell gates, staging-server rehearsal |
| `infrastructure/scripts/release` | Artifact, SSH transfer, immutable activation/rollback | artifact contract, test deployment |

Keep HTTP parsing in `app.py`, model rules in `models.py`, filesystem and process
concerns in their owning modules, and target-selection policy in the shared shell
libraries. Do not make API handlers render NGINX directly or let shell scripts edit
generated NGINX configuration.
