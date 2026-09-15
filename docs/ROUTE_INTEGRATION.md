# Connect a Compose project

Choose one unused high host port per project. Keep the container's existing
private networks and publish only its HTTP entry point:

```yaml
services:
  web:
    ports:
      - "127.0.0.1:18081:8080"
```

The service must listen on `0.0.0.0:8080` inside the container. Do not publish
databases, queues, or internal APIs. Confirm the loopback endpoint locally:

```bash
curl --fail --header 'Host: storefront.example.org' http://127.0.0.1:18081/
```

Point the domain's A and/or AAAA records to the VPS. Then connect it:

```bash
sudo ./scripts/connect-route --production \
  storefront storefront.example.org 18081
```

The route ID and domain are lowercase. Reusing the same ID and domain updates
the loopback port. A different route cannot claim an existing domain.

The application should allow its public hostname and trust forwarded headers
from the local NGINX proxy. Secure cookies and redirects should use the forwarded
HTTPS scheme.

For migration from a project-owned public NGINX container, first add and verify
the loopback binding. Stop publishing that project's ports 80/443 before starting
host NGINX; two processes cannot own the same host ports.
