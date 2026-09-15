# Debugging cache

| Symptom | First checks | Boundary |
| --- | --- | --- |
| 421/444 | DNS, Host/SNI, `list-routes` | hostname route |
| 502/504 | app status, alias, port, network membership | gateway -> app |
| redirect/cookie loop | forwarded-scheme trust in app | application gateway |
| ACME failure | A/AAAA, public port 80, target endpoint | DNS/public ingress |
| unhealthy gateway | bounded logs and `nginx -t` | NGINX/config/cert |
| wrong deployment host | explicit flag and origin profile | target selection |

```bash
bash .agents/scripts/project-context.sh
docker compose --env-file .env.test ps
docker compose --env-file .env.test logs --tail=200 gateway
./scripts/list-routes --test
docker compose --env-file .env.test exec gateway nginx -t -c /etc/nginx/nginx.conf
docker network inspect vps-ingress-test
```

Use production only after confirming the target. Do not print profiles or
private keys, and do not delete networks or volumes as a diagnostic shortcut.
Failed route activation should restore the preceding file; verify NGINX before
retrying.
