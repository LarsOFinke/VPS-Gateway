# VPS NGINX setup

This repository only installs ordinary host-level NGINX and Certbot. It does not
register or manage projects.

## One-time server setup

On a Debian or Ubuntu VPS:

```bash
sudo ./setup.sh
```

This installs and starts the distribution packages using their standard paths:

```text
/etc/nginx/nginx.conf
/etc/nginx/sites-available/
/etc/nginx/sites-enabled/
/etc/letsencrypt/
```

It does not replace existing NGINX configuration.

## Project responsibility

Each project publishes its web container on a unique loopback port:

```yaml
services:
  web:
    ports:
      - "127.0.0.1:18081:8080"
```

The project carries its own NGINX site file and installs it directly:

```bash
sudo install -m 0644 deploy/nginx/site.conf \
  /etc/nginx/sites-available/storefront.conf
sudo ln -sfn /etc/nginx/sites-available/storefront.conf \
  /etc/nginx/sites-enabled/storefront.conf
sudo nginx -t
sudo systemctl reload nginx
```

For the first certificate, the project or operator can use Certbot’s standard
NGINX integration:

```bash
sudo certbot --nginx --redirect \
  --domain storefront.example.org \
  --email admin@example.org --agree-tos --non-interactive
```

Adding a site is therefore an ordinary NGINX file installation and graceful
reload. There is no central registration script, gateway deployment, shared
Docker network, or custom configuration store. A generic starting point is in
[`examples/project-site.conf`](examples/project-site.conf).
