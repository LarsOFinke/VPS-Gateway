# VPS server configuration guide

This repository performs one task: install the distribution-provided NGINX and
Certbot packages on a Debian/Ubuntu VPS. It does not own project site files.

- Projects install their own configuration in `/etc/nginx/sites-available/`,
  enable it in `/etc/nginx/sites-enabled/`, test, and reload NGINX.
- Project containers publish only a unique `127.0.0.1` host port.
- Do not add route registration, custom NGINX directories, target profiles,
  gateway containers, APIs, state, or deployment orchestration.
- Keep `setup.sh` idempotent and preserve existing NGINX configuration.
- Do not commit project names, domains, certificates, or secrets.
- Executable files may not exceed 420 lines.

Run `make validate` before handoff. Do not commit or push unless requested.
