# VPS Gateway

A deliberately small server configuration for hosting several isolated Docker
Compose projects on one VPS and one IPv4/IPv6 address. NGINX owns ports 80/443,
selects a route from TLS SNI and the HTTP `Host`, and proxies to a Docker network
alias. Certbot owns public certificates.

There is no management service, database, admin UI, or Docker socket. Persistent
state is limited to readable NGINX route files and certificate volumes.

## Boundary

```text
Internet -> VPS-Gateway NGINX -> shared ingress network -> application gateway
                                                        -> app-private network
```

Each application remains a separate Compose project. Its database and internal
services stay only on project-private networks. Exactly one HTTP-facing service
opts into the external `vps-ingress` network with a globally unique alias and no
public host port.

Multiple DNS A/AAAA records may point to the same VPS address. NGINX separates
them by hostname; separate IP addresses are unnecessary.

## Setup

Requirements: Docker Engine with Compose, Bash, OpenSSL, and `flock`.

```bash
./scripts/setup                 # test: 18080/18443 and ACME staging
./scripts/setup --production    # production: 80/443, explicit only
```

Setup creates a private target profile, a persistent route directory, and the
target's external Docker-internal ingress network. Review `LETSENCRYPT_EMAIL`
before enrolling a certificate.

## Connect an application

After its gateway container has joined the selected ingress network:

```bash
./scripts/connect-route --test storefront-test storefront.test.example.org storefront-web-test 8080
./scripts/connect-route --production storefront storefront.example.org storefront-web 8080
```

The command validates identifiers, installs an ACME-only HTTP route, obtains the
certificate through the webroot challenge, then transactionally enables HTTPS.
The command is idempotent for the same route ID; certificate retention is left
to Certbot.

```bash
./scripts/list-routes --production
./scripts/remove-route --production storefront
./scripts/renew-certificates --production
```

See [route integration](docs/ROUTE_INTEGRATION.md), [deployment](docs/deployment/DEPLOYMENT.md),
and [operations](docs/deployment/OPERATIONS.md).
