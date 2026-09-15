# Deployment

This repository is copied or cloned onto the selected VPS and run there. There
is no gateway image or application release.

Requirements on Debian/Ubuntu:

```bash
sudo apt-get update
sudo apt-get install nginx certbot
```

Configure a test server:

```bash
sudo ./scripts/setup --test --email admin@example.org
```

Configure the production server:

```bash
sudo ./scripts/setup --production --email admin@example.org
```

Test is the command default. A production server records `production` under
`/etc/vps-gateway/environment`, so later commands without `--production` fail
instead of changing production accidentally. Test and production should be
separate VPS instances because both use public ports 80/443.

Before setup, stop any container or old proxy that publishes host ports 80/443.
Application containers continue running through their new loopback bindings.
Setup preserves an existing VPS-Gateway site directory and verifies the complete
NGINX configuration before activation.
