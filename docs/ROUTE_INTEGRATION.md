# Upstream integration contract

Each upstream gateway joins the selected target's ingress network, listens on
its internal HTTP port, and has no host `ports` entry. The central gateway is the
only public listener. Production uses `vps-ingress`; test uses
`vps-ingress-test` by default. The network is Docker-internal, isolating the
application path from external routing. Route upstreams must name a single
DNS-compatible alias on this network; IP addresses and dotted hostnames are
rejected. A separate project-local edge network carries published traffic and
Certbot connectivity.

## Compose pattern

```yaml
services:
  gateway:
    expose:
      - "8080"
    networks:
      default: {}
      ingress:
        aliases:
          - app-gateway

networks:
  ingress:
    name: vps-ingress
    external: true
```

Do not attach databases or backend-only services to `vps-ingress`. The upstream
gateway should remain the only entry point for its private service network.
Do not manually replace the ingress network with a non-internal network;
`scripts/setup` checks this property before starting the gateway.

## Downstream NGINX headers

The upstream gateway receives authoritative forwarding headers from the
central gateway. For a dedicated listener reachable only on `vps-ingress`, use:

```nginx
proxy_set_header Host $host;
proxy_set_header X-Real-IP $http_x_real_ip;
proxy_set_header X-Forwarded-For $http_x_forwarded_for;
proxy_set_header X-Forwarded-Host $http_x_forwarded_host;
proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
proxy_set_header X-Forwarded-Port $http_x_forwarded_port;
```

Never use that preservation policy on a publicly reachable listener: an
internet client could forge the headers. Prefer a separate behind-ingress mode
or server block and restrict it to the Docker network.

Application frameworks should use their native forwarded-header handling and
restrict allowed hosts/origins to the route's public hostname. Browser cookies
should be host-only and Secure in production.

## Deployment ordering

1. Create the selected network with `scripts/setup` (test) or
   `scripts/setup --production`.
2. Deploy the upstream's behind-ingress listener and network alias.
3. Check reachability from the central gateway container.
4. Ensure public DNS points to the VPS.
5. Run `scripts/connect-route --test ...` and only then the explicitly selected
   production command.
6. Verify HTTPS, redirects, API calls, source address logging, and WebSockets.

For an existing live hostname, import or obtain its certificate before the
port-80/443 cutover and use a maintenance window. Do not start two gateways that
both publish those host ports.
