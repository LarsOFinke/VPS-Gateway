# Route integration

## Attach one application service

Add the selected frontend or application gateway to its existing Compose file.
Keep all current private networks; add only the shared ingress attachment:

```yaml
services:
  web:
    # No public `ports:` entry in production.
    expose:
      - "8080"
    networks:
      default: {}
      vps_ingress:
        aliases:
          - storefront-web

networks:
  vps_ingress:
    external: true
    name: vps-ingress
```

Use `vps-ingress-test` and a different alias for a test deployment. Aliases must
be unique across all projects on that network. Do not attach databases, queues,
or private APIs. The selected service must listen on `0.0.0.0` inside its
container; `127.0.0.1` is not reachable from NGINX.

## Connect the hostname

Point the domain's A/AAAA records at the VPS, confirm ports 80/443 reach this
gateway, then run:

```bash
./scripts/connect-route --production ROUTE_ID DOMAIN NETWORK_ALIAS CONTAINER_PORT
```

Example:

```bash
./scripts/connect-route --production storefront storefront.example.org storefront-web 8080
```

Route IDs, domains, and aliases are lowercase. One route owns one hostname and
one Certbot certificate name. Reuse the route ID to update its upstream.

Applications should allow the public hostname and enable their framework's
trusted-proxy support only for traffic from the ingress listener. Secure cookies
and absolute redirects should use the forwarded HTTPS scheme.

## Safe ordering

1. Set up VPS-Gateway and the shared network.
2. Deploy the application's ingress attachment without public host ports.
3. Verify the alias and container port from the gateway network.
4. Point DNS to the VPS.
5. Rehearse through test, then explicitly connect production.
6. Verify HTTP redirect, HTTPS, API calls, uploads, and WebSockets.
