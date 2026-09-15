# Architecture

The VPS runs one ordinary host NGINX installation. DNS for multiple domains may
point to the same IPv4 and IPv6; TLS SNI and HTTP `Host` select the site file.
Each route proxies to a unique high port bound only on `127.0.0.1`.

Docker is deliberately outside the routing layer. Container IP addresses,
Compose project names, and Docker DNS are irrelevant because Docker publishes a
stable loopback port. Recreating an application container does not change NGINX.

Each application remains isolated:

- private application/database networks stay inside its Compose project;
- only its chosen HTTP service publishes a host port;
- the binding is `127.0.0.1`, never a public interface;
- projects receive different host ports, avoiding collisions.

NGINX and Certbot own ports 80/443 and public TLS. Unknown hosts fail closed.
The gateway overwrites forwarding headers before proxying. Adding a route changes
one file under `/etc/vps-gateway/sites`, then runs `nginx -t` and a graceful
reload. It does not rebuild or restart NGINX.
