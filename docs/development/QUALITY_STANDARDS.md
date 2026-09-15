# Quality standards

- Preserve `Internet -> host NGINX -> loopback port -> application container`.
- Do not add a gateway container, Docker network integration, API, UI, or route
  database.
- Validate route identifiers, domains, and ports before generating NGINX.
- Route writes are atomic; activation requires `nginx -t` and restores on error.
- Bind application HTTP ports to `127.0.0.1`, never a public interface.
- Test is default and production requires explicit `--production`.
- NGINX and Certbot are the sole public port and TLS owners.
- Do not version installed routes, domains, certificates, or secrets.
- Shell scripts use strict mode, quote expansions, and produce useful failures.
- Executable files stay at or below 420 lines.
- Behavior, tests, docs, and `.agents` caches change together.
