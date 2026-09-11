FROM python:3.13-alpine

RUN apk add --no-cache nginx openssl \
    && addgroup -S gateway \
    && adduser -S -G gateway -h /nonexistent gateway \
    && mkdir -p /etc/vps-gateway /var/lib/vps-gateway /var/www/acme /tmp/nginx \
    && chown -R gateway:gateway /tmp/nginx /var/lib/nginx

WORKDIR /opt/vps-gateway
COPY src ./src
COPY config/nginx.conf /etc/nginx/nginx.conf
COPY scripts/entrypoint.sh /usr/local/bin/vps-gateway-entrypoint

ENV PYTHONPATH=/opt/vps-gateway/src \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

EXPOSE 8080 8443 9080
ENTRYPOINT ["/usr/local/bin/vps-gateway-entrypoint"]
