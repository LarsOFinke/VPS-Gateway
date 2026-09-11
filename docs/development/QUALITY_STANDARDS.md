# Quality standards

These rules are binding for the repository.

- Preserve the boundary `Internet -> central NGINX -> application gateway`.
- Validate and normalize every API value before it reaches NGINX text. Do not
  add escape-based acceptance for names that can instead be rejected.
- Keep route mutations serialized, deterministic, atomic, and reversible.
- Test and production remain independent. Test is default; production requires
  `--production`; mixed target flags and mismatched profiles fail closed.
- The management API remains host-loopback-only and authenticated. Never mount
  the Docker socket or add generic command execution.
- The gateway is the sole public TLS/ACME owner. Use private-network HTTP
  upstreams and do not disable upstream certificate verification as a shortcut.
- Runtime and origin profiles, certificates, tokens, state, diagnostics, and
  release outputs are not versioned or printed in logs.
- Remote root activation accepts only a signed manifest through the installed,
  root-owned constrained runner. Never execute a staging-user-owned installer
  with sudo.
- Shell scripts use Bash strict mode, quote expansions, validate destructive
  targets, and report actionable failures. Critical writes use staging and
  atomic rename.
- Executable Python and shell files remain at or below 420 lines and own one
  clear responsibility.
- Behavior, API contract, environment examples, tests, primary docs, and agent
  caches change together.
