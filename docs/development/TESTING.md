# Testing

```bash
make test
make check-tree
make validate
```

The tests cover target selection, constrained route inputs, deterministic HTTP
and HTTPS site generation, forwarding-header policy, anonymization, versioning,
shell syntax, ShellCheck when installed, and repository structure.

On a disposable test VPS, also verify:

1. setup disables the conventional distribution default and `nginx -t` passes;
2. a container bound to `127.0.0.1:18081` is not externally reachable directly;
3. its hostname is reachable through NGINX;
4. ACME staging enrollment succeeds;
5. changing the container while retaining the host port needs no NGINX change;
6. an invalid route leaves the previous NGINX configuration active.
