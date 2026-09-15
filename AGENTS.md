# VPS Gateway contributor guide

Read `.agents/ONBOARDING.md` before broad work and run
`bash .agents/scripts/project-context.sh`.

## Purpose and invariants

This repository owns the VPS-wide public NGINX ingress and is the only service
that binds production ports 80 and 443. Applications keep independent Compose
projects and private networks. Only their selected HTTP gateway joins the shared
external ingress network, under a unique DNS alias.

- Keep the runtime NGINX-only. Do not add an API, UI, route database, Docker
  socket, or project-specific knowledge.
- Routes are validated NGINX fragments in the target's persistent route
  directory. Syntax-test, reload, and restore on failure.
- Overwrite client forwarding headers at this trust boundary.
- Keep unknown hosts closed and application containers off public ports.
- NGINX and Certbot here are the sole owners of public TLS.
- Test is the default. Production always requires explicit `--production`.
- Never version runtime profiles, certificates, route state, or release output.
- Executable Python and shell files may not exceed 420 lines.

Run focused checks first and `make validate` before handing off broad work. Do
not commit or push unless explicitly requested.
