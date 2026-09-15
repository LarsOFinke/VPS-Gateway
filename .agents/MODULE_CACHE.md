# Module cache

| Module | Responsibility | Check |
| --- | --- | --- |
| `config/nginx.conf` | listeners, defaults, Docker DNS, logs | image smoke |
| `compose.yml` | ports, volumes, edge/ingress attachment | Compose render |
| `scripts/lib/routes.sh` | validation, rendering, activation/rollback | `test_routes.sh` |
| `scripts/lib/target.sh` | target selection and profile safety | `test_target_selection.sh` |
| `scripts/setup` | profile, route dir, network, NGINX health | `test_setup_network.sh` |
| `scripts/connect-route` | HTTP -> ACME -> HTTPS workflow | route test/staging rehearsal |
| `scripts/remove-route` | validated route removal with restoration | shell gate |
| `scripts/renew-certificates` | renewal and checked reload | staging rehearsal |
| `infrastructure/scripts/release` | signed immutable releases | artifact test |

Keep target policy in `target.sh` and route policy in `routes.sh`. Application
repos own their Compose internals; this repository only documents the narrow
shared-network attachment.
