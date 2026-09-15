FROM nginx:1.28.0-alpine

RUN apk add --no-cache openssl \
    && mkdir -p /var/www/acme /var/lib/vps-gateway /tmp/nginx/client_body \
        /tmp/nginx/proxy /tmp/nginx/fastcgi /tmp/nginx/uwsgi /tmp/nginx/scgi

COPY config/nginx.conf /etc/nginx/nginx.conf
COPY scripts/entrypoint.sh /usr/local/bin/vps-gateway-entrypoint

EXPOSE 8080 8443
ENTRYPOINT ["/usr/local/bin/vps-gateway-entrypoint"]
