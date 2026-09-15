# VPS Gateway contributor guide

Read `.agents/ONBOARDING.md` before broad work.

This repository configures host-level NGINX for a small VPS. Applications remain
independent Docker Compose projects and expose exactly one HTTP service on a
unique `127.0.0.1` host port. NGINX maps public hostnames to those ports.

- Do not add a gateway container, shared Docker network, API, UI, or route store.
- Only host NGINX and Certbot own public ports and certificates.
- Route changes must validate input, run `nginx -t`, reload, and restore on error.
- Overwrite untrusted forwarding headers at the public boundary.
- Test is default; production requires explicit `--production`.
- Keep project names, domains, secrets, certificates, and installed routes out of
  this repository.
- Executable Python and shell files may not exceed 420 lines.

Run focused checks and `make validate` before handoff. Do not commit or push
unless requested.
