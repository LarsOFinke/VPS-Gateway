# Architecture

## Runtime topology

```text
DNS name A/AAAA
      |
      v
host :80/:443
      |
project-local edge network
      |
VPS Gateway NGINX ---- loopback management API ---- route state JSON
      |
target-specific external, Docker-internal ingress network
      |
upstream gateway -> private service runtime/storage
```

DNS selects the VPS address; TLS SNI and HTTP `Host` select the route. A
project-local edge network supports published ports and Certbot connectivity.
The central gateway terminates TLS once and forwards application traffic only
across the Docker-internal ingress network. Upstream declarations accept a single
DNS-compatible network alias, not IP addresses or external DNS names. Upstream
databases and backend-only services never join that shared network.

## Data plane

`config/nginx.conf` defines closed default listeners, JSON access logging,
Docker DNS resolution, timeouts, and protocol maps. `nginx.py` deterministically
renders enabled routes. It overwrites all client forwarding headers at the
public trust boundary. Unknown HTTP hosts close with 444; unknown TLS hosts get
421 after the fallback TLS handshake.

## Control plane

The standard-library Python API is intentionally small and dependency-free. It
binds inside the container to port 9080, which Compose exposes only at host
`127.0.0.1`. Automation uses constant-time bearer-token authentication. The
browser panel uses an HttpOnly SameSite session cookie and CSRF token; its
PBKDF2-hashed password persists in the state volume. Bootstrap credentials must
be rotated before the session can manage routes. It has no Docker socket and
executes only fixed NGINX, certificate, and bounded upstream-check operations.

A mutation is serialized under a process lock, validates every route and
domain conflict, renders the complete candidate, persists desired state
atomically, tests NGINX, installs and reloads it, and restores both state and
configuration if activation fails. Startup always rebuilds generated config from
persistent state.

TLS route activation checks that the certificate is unexpired and covers every
declared hostname before NGINX verifies the matching private key and complete
configuration.

Disabled routes remain rendered and retain domain ownership. Their HTTP and,
when configured, HTTPS server blocks return a repository-owned 503 maintenance
page rather than proxying or falling through to the unknown-host server.

## Environment isolation

Target selection changes the Compose project, host ports, management port,
ingress network, ACME directory, install root, and private profiles. Test is the
default; production is never derived implicitly. This permits separate servers
and also prevents collisions if both environments temporarily share one host.
