# Debugging cache

## Fast classification

| Symptom | First checks | Likely boundary |
| --- | --- | --- |
| Public 404/421/444 | DNS, requested Host/SNI, `gatewayctl list` | hostname declaration/default server |
| 502/504 | application container, internal ingress network alias, upstream port | central -> application gateway |
| Redirect or secure-cookie loop | forwarded scheme/port in downstream gateway | trusted proxy contract |
| Route API 401 | selected target/profile, token mismatch | origin/target profile selection |
| Route API 409 | gateway logs, certificate expiry/SANs, paths, `nginx -t` | render/reload transaction |
| Route API 422 | request versus `openapi.yaml` | model validation |
| ACME failure | DNS A/AAAA, port 80, selected staging/production endpoint | public HTTP challenge path |
| Container unhealthy | both API and NGINX logs/processes | supervised container runtime |
| Deploy selects wrong host | explicit flags and `.env.origin.<target>` | origin selector |

## Safe commands

```bash
bash .agents/scripts/project-context.sh
docker compose --env-file .env.test ps
docker compose --env-file .env.test logs --tail=200 gateway
./scripts/gatewayctl --test list
docker compose --env-file .env.test exec gateway nginx -t -c /etc/nginx/nginx.conf
```

Add `--production` only after confirming the incident is on production. Never
print a profile, bearer token, private key, or full certificate archive. Do not
delete volumes as a diagnostic step. An NGINX reload failure should leave the old
workers and prior generated configuration active; verify logs before retrying.
