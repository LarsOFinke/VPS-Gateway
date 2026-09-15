# Debugging cache

```bash
sudo nginx -t
systemctl status nginx
journalctl -u nginx --since '30 minutes ago'
ls -l /etc/nginx/sites-enabled
sudo certbot certificates
```

For 502/504, test the relevant application’s loopback port. For the wrong site,
check DNS, `server_name`, and the enabled symlink. Project-specific failures are
owned by the project repository; this repository has no route state to inspect.
