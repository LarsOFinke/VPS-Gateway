# Debugging cache

| Symptom | Check |
| --- | --- |
| 421/444 | requested hostname and `scripts/list-routes` |
| 502/504 | `curl 127.0.0.1:<project-port>` and project container status |
| ACME failure | DNS A/AAAA, firewall, and port 80 ownership |
| redirect loop | application trusted-proxy/forwarded-header settings |
| NGINX failure | `sudo nginx -t` and bounded service journal |
| target refusal | `/etc/vps-gateway/environment` and explicit flag |

Safe starting commands:

```bash
sudo nginx -t
systemctl status nginx
journalctl -u nginx --since '30 minutes ago'
./scripts/list-routes --test
```

Do not delete certificates or installed routes as a diagnostic shortcut. Adding
`--production` is appropriate only after confirming the production server.
