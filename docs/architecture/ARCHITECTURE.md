# Architecture

## Responsibilities

VPS-Gateway owns only public ingress: ports 80/443, hostname selection,
forwarding-header normalization, ACME challenges, and public certificates. It
does not deploy applications, inspect Docker, or understand their internals.

NGINX is the only long-running process. Routes are individual `.conf` files in a
persistent bind-mounted directory. Operator scripts validate constrained values,
render a candidate, run `nginx -t`, reload without dropping connections, and
restore the previous file if activation fails.

## Container isolation

The target has one external Docker network (`vps-ingress` in production). It is
created with `--internal`, so it provides container-to-container connectivity but
no route to the internet. VPS-Gateway also joins its own edge network for public
ports and Certbot connectivity.

An application keeps its default/private networks and attaches only its chosen
HTTP gateway to the shared network. A unique alias such as `storefront-web`
becomes the upstream address. Databases and backend services never join the
shared network. Applications do not publish 80/443 on the host.

NGINX uses Docker's embedded resolver and a variable `proxy_pass`, so it can
start or reload while an application is absent and follows container address
changes automatically.

## Hostname and trust handling

DNS for many domains may resolve to the same IPv4 and IPv6. TLS SNI selects the
certificate/server block; HTTP `Host` selects the route. Unknown HTTP hosts close
with 444 and unknown TLS hosts receive 421 from a fallback certificate.

The public gateway overwrites `X-Real-IP` and all `X-Forwarded-*` headers.
Applications may trust those values only on the listener reachable through the
internal ingress network. Public application listeners must not preserve
client-supplied forwarding headers.

No Docker socket is mounted. Route scripts operate through narrowly scoped
Compose commands rather than a privileged daemon.
