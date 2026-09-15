# Testing

## Checks

```bash
make test                 # anonymization and route rendering/rollback
make infrastructure-test # targets, network setup, releases, versioning
make compose-config       # both example profiles
make check-tree           # repository conventions
make validate             # complete gate
```

The route test covers constrained input, deterministic HTTP/TLS fragments,
trusted forwarding headers, and restoration after a failed `nginx -t`. Setup
tests reject a non-internal shared network. The complete gate also checks shell
syntax, runs ShellCheck when installed, and renders both Compose targets.

Before release, build the real image and start the test profile. Confirm:

1. `nginx -t` passes in the read-only container;
2. unknown HTTP/TLS hosts hit the closed defaults;
3. a disposable upstream alias works on the shared network;
4. removing the upstream does not stop or invalidate NGINX;
5. certificate enrollment succeeds against ACME staging;
6. a route and certificate survive container recreation.
