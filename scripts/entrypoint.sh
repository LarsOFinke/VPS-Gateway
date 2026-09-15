#!/bin/sh
set -eu

mkdir -p /tmp/nginx/client_body /tmp/nginx/proxy /tmp/nginx/fastcgi \
    /tmp/nginx/uwsgi /tmp/nginx/scgi
chown -R nginx:nginx /tmp/nginx

certificate=/var/lib/vps-gateway/default.crt
private_key=/var/lib/vps-gateway/default.key
if [ ! -s "$certificate" ] || [ ! -s "$private_key" ]; then
    openssl req -x509 -newkey rsa:2048 -nodes -days 7 \
        -subj '/CN=unconfigured.invalid' \
        -keyout "$private_key" -out "$certificate" >/dev/null 2>&1
    chmod 0600 "$private_key"
fi

nginx -t -c /etc/nginx/nginx.conf
exec nginx -g 'daemon off;' -c /etc/nginx/nginx.conf
