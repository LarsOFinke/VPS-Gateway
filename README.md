# VPS Gateway

Small host-level NGINX configuration for routing a few containerized projects on
one VPS. It is configuration, not another application.

```text
DNS A/AAAA records
        ↓
host NGINX :80/:443
        ├── site-a.example → 127.0.0.1:18081 → Project A container
        └── site-b.example → 127.0.0.1:18082 → Project B container
```

Every project keeps its own Compose networks, database, and deployment. Its
public HTTP service publishes one unique loopback-only port. Nothing else is
exposed and no shared Docker network is required.

## Server setup

On a Debian/Ubuntu test server:

```bash
sudo apt-get install nginx certbot
sudo ./scripts/setup --test --email admin@example.org
```

On production, selection must be explicit:

```bash
sudo ./scripts/setup --production --email admin@example.org
```

Setup installs one base file under `/etc/nginx/conf.d/`, creates the private site
directory and fallback certificate, disables only the conventional distribution
default-site symlink, validates NGINX, and reloads it. Test and production are
expected to be different servers; the installed marker prevents accidental
cross-target commands.

## Add a project

Publish its HTTP entry point on a unique localhost port:

```yaml
services:
  web:
    ports:
      - "127.0.0.1:18081:8080"
```

Then, after DNS points to the VPS:

```bash
sudo ./scripts/connect-route --production storefront storefront.example.org 18081
```

This writes an ACME-only HTTP site, obtains the certificate, writes the HTTPS
proxy site, runs `nginx -t`, and reloads NGINX. It never rebuilds or redeploys
NGINX.

```bash
./scripts/list-routes --production
sudo ./scripts/remove-route --production storefront
sudo ./scripts/renew-certificates --production
```

See [project integration](docs/ROUTE_INTEGRATION.md) and
[operations](docs/deployment/OPERATIONS.md).
