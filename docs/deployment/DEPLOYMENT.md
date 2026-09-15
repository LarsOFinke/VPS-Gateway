# Deployment

## Targets

Every command defaults to test. Production must be explicit:

```bash
./scripts/setup
./scripts/setup --production
./deploy.sh
./deploy.sh --production
```

Runtime profiles are `.env.test` and `.env.production`; origin SSH profiles are
`.env.origin.test` and `.env.origin.production`. Profiles must be mode 0600,
must match the selected target, and must not be committed. Test and production
have separate Compose projects, ports, networks, certificates, and route dirs.

`scripts/setup` creates or verifies the Docker-internal ingress network, builds
NGINX, and runs `nginx -t`. An existing non-internal network is rejected.

## Signed remote releases

Every immutable release needs a higher version:

```bash
./set-version.sh minor
./deploy.sh --configure
./deploy.sh --production --configure
```

The release workflow signs a checksum, transfers it over SSH, and invokes a
root-owned constrained runner. Provision that boundary once:

```bash
sudo infrastructure/scripts/release/provision-deploy-user.sh \
  gateway-admin /tmp/gateway-admin.pub /tmp/release-signing-key.pub.pem
```

Deployments use `releases/<version>`, a `current` symlink, and persistent
`shared/.env` plus `shared/routes`. The first deployment initializes the profile
and stops for review. Later activation failures restore the previous release.

An upgrade from the former control-service design keeps certificate volumes but
replaces API-managed state with transparent route files. Reconnect each hostname
once with `scripts/connect-route`; obsolete API variables in an existing private
profile are ignored and may be removed after successful migration.
