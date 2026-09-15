# Quality standards

- Keep this repository a one-time package bootstrap, not a gateway application.
- Preserve standard Debian/Ubuntu NGINX paths and existing configuration.
- Project repositories own their site files, domains, ports, and TLS onboarding.
- Application ports bind to `127.0.0.1`, never a public interface.
- Site changes run `nginx -t` before a graceful reload.
- Do not add route APIs, registration scripts, custom state, Docker integration,
  server target profiles, or project-specific data.
- Executable files stay at or below 420 lines.
- Documentation and validation change with behavior.
