# Project cache

> Reviewed 2026-09-15. Source and primary docs take precedence.

The repository contains a one-time `setup.sh` for Debian/Ubuntu VPS hosts. It
installs NGINX, Certbot, and the Certbot NGINX integration, then enables the
standard NGINX service.

It owns no runtime configuration after setup. Application repositories install
their own site files under:

```text
/etc/nginx/sites-available/
/etc/nginx/sites-enabled/
```

Applications route to unique `127.0.0.1` ports published by their Compose web
services. Environment selection happens by deploying to the intended server,
not through state or profiles in this repository.
