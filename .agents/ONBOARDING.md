# Agent onboarding

This repository only installs standard Debian/Ubuntu NGINX and Certbot packages.
Read `README.md`, `setup.sh`, and the relevant documentation before changes.

Fixed rules:

- no route registration or central project configuration;
- no gateway container, API, database, target profile, or custom NGINX tree;
- projects own files in `sites-available` and `sites-enabled`;
- projects expose a unique loopback-only port;
- setup preserves existing configuration;
- `make validate` is the completion gate.

Do not commit or push unless requested.
