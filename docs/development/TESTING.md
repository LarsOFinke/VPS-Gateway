# Testing

## Focused checks

```bash
make test                 # Python models, state, rendering, controller
make infrastructure-test # target selection and release artifact contracts
make compose-config       # both example environments
make check-tree           # repository/document/version conventions
```

The unit suite also verifies that upstreams are limited to Docker aliases,
runtime profile symlinks are rejected, and TLS certificates are checked for
expiry and hostname coverage before route activation.
Admin coverage includes password hashing and persistence, session revocation,
forced bootstrap rotation, CSRF rejection, login cooldown, static panel serving,
and real loopback HTTP route management where sockets are available. Accessibility
checks and maintenance rendering are tested without external network access.

Run the complete gate for cross-cutting work:

```bash
make validate
```

The gate also checks all shell syntax, runs ShellCheck when installed, verifies
the OpenAPI/package version agreement, and renders Compose independently for test
and production.

## Container smoke test

Before a release, build the real image and start it with production-equivalent
read-only filesystem and capability settings on non-public test ports. Verify:

1. `/v1/health` responds without authentication.
2. `/v1/routes` rejects missing authentication with 401.
3. a valid HTTP-only route can be applied and read back;
4. `nginx -t` passes inside the running container;
5. state survives a container recreation using the same test volumes;
6. stopping either managed process terminates the container.

Certificate enrollment should first be rehearsed against the test profile, which
uses Let's Encrypt staging by default. Production ACME is an explicit release
step after DNS and port ownership have been verified.
