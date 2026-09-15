# Module cache

| Module | Responsibility | Check |
| --- | --- | --- |
| `config/vps-gateway.conf` | maps, closed defaults, installed site include | test-VPS smoke |
| `scripts/lib/target.sh` | target and root safety | `test_target_selection.sh` |
| `scripts/lib/routes.sh` | render and transactional reload | `test_routes.sh` |
| `scripts/setup` | host NGINX installation | shell gate/test VPS |
| `scripts/connect-route` | HTTP challenge to HTTPS route | ACME staging rehearsal |
| `scripts/remove-route` | checked site removal | shell gate |
| `scripts/renew-certificates` | manual renewal and reload | test VPS |

Application Compose files own loopback port publishing. This repository never
edits project files or interacts with Docker.
