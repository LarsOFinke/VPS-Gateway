# Quality standards

- Preserve `Internet -> central NGINX -> application gateway`.
- Keep the runtime NGINX-only and project-agnostic. No management API, route
  database, admin UI, Docker socket, or direct access to application internals.
- Validate route IDs, hostnames, aliases, and ports before rendering NGINX.
- Serialize route changes, syntax-test the complete configuration, reload, and
  restore the prior route on failure.
- Keep application databases and internal services off the shared ingress
  network. Only the selected application gateway joins it.
- Test is default; production requires `--production`; mismatched profiles fail.
- The central gateway exclusively owns public TLS and ports 80/443.
- Runtime profiles, certificates, route state, and release output are private.
- Remote root activation accepts only signed artifacts through the installed,
  root-owned constrained runner.
- Shell scripts use strict mode, quote expansions, and report actionable errors.
- Executable Python and shell files stay at or below 420 lines.
- Behavior, examples, tests, primary docs, and `.agents` caches change together.
