# VPS Gateway contributor guide

> For broad work, first read [`.agents/ONBOARDING.md`](.agents/ONBOARDING.md)
> and run `bash .agents/scripts/project-context.sh`.

## Purpose

This repository owns the VPS-wide public ingress. It is the only deployment
allowed to bind host ports 80 and 443. Application repositories retain their
own application gateways, databases, release processes, and security policies.

## Invariants

- Never expose the control API beyond loopback without adding a stronger
  authentication and network policy layer.
- Treat route changes transactionally: validate the complete NGINX candidate,
  atomically replace it, reload, and roll back on failure.
- Never interpolate unvalidated user input into NGINX configuration.
- Overwrite forwarding headers at this trust boundary; do not pass through
  client-supplied `X-Forwarded-*` values.
- Keep unknown hosts closed and keep application containers off public ports.
- NGINX and Certbot in this repository are the sole owners of public TLS.
- Test is always the default target. Production actions require an explicit
  `--production`; target loaders must fail on mixed flags or profile mismatch.
- Keep `.env.<target>` and `.env.origin.<target>` private with mode 0600. Never
  inspect or print their secrets as routine project analysis.

## Structure

- `src/vps_gateway/` owns API, validation, persistence, and rendering.
- `scripts/` owns target-local setup and operations.
- `infrastructure/scripts/release/` owns origin transfer and release activation.
- `.agents/` is a maintained navigation cache, not an implementation source.
- Executable Python and shell files must remain at or below 420 lines.

## Validation

Run focused checks first and `make validate` before handing off a broad change.
Update `README.md`, the OpenAPI contract, `.agents` cache, and primary operational
documentation whenever their behavior or entry points change. Do not commit or
push unless explicitly requested.
