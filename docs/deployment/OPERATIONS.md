# Operations

```bash
systemctl status nginx
sudo nginx -t
journalctl -u nginx --since '30 minutes ago'
./scripts/list-routes --production
```

Adding or updating a site runs a graceful NGINX reload; it does not rebuild or
restart a gateway deployment. Installed route files live under
`/etc/vps-gateway/sites/` and should be changed through the scripts.

Common failures:

- 421/444: no route owns the requested hostname.
- 502/504: the project container is stopped or its loopback port changed.
- ACME failure: DNS A/AAAA or public port 80 does not reach host NGINX.
- redirect/cookie loop: the application does not honor forwarded HTTPS headers.

Certbot's packaged systemd timer performs renewal automatically. Setup installs
the standard deploy hook that validates and reloads NGINX after a renewed
certificate. `scripts/renew-certificates` remains available for a manual run.

Back up `/etc/vps-gateway` and `/etc/letsencrypt` with restricted access. The
latter contains private keys. Recovery is: install NGINX/Certbot, restore those
directories, install `config/vps-gateway.conf`, run `nginx -t`, then reload.
