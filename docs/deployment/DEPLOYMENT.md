# Server setup

Run once on each Debian/Ubuntu VPS:

```bash
sudo ./setup.sh
```

The script installs `nginx`, `certbot`, and `python3-certbot-nginx`, validates the
existing NGINX configuration, enables the service, and starts or gracefully
reloads it. It does not install project sites or replace distribution defaults.

Test versus production selection belongs to the caller: connect to the intended
server and deploy that environment’s project site file. The base NGINX server has
no environment-specific state and therefore needs no target profiles.

Before installation, ensure no container already publishes host ports 80 or 443.
Project containers should be migrated to unique loopback ports first.
