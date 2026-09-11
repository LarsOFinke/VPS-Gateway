#!/bin/sh
set -eu

cert=/var/lib/vps-gateway/default.crt
key=/var/lib/vps-gateway/default.key

mkdir -p /tmp/nginx/client_body /tmp/nginx/proxy /tmp/nginx/fastcgi /tmp/nginx/uwsgi /tmp/nginx/scgi
chmod -R 0777 /tmp/nginx

if [ ! -s "$cert" ] || [ ! -s "$key" ]; then
    openssl req -x509 -newkey rsa:2048 -nodes -days 30 \
        -subj '/CN=unconfigured.invalid' \
        -keyout "$key" -out "$cert" >/dev/null 2>&1
fi

python -m vps_gateway init
python -m vps_gateway serve &
api_pid=$!
nginx -e /dev/stderr -g 'daemon off;' &
nginx_pid=$!

terminate() {
    kill -TERM "$api_pid" "$nginx_pid" 2>/dev/null || true
}
trap terminate HUP INT TERM

# The container is healthy only while both the control and data planes live.
# POSIX sh has no portable `wait -n`, so supervise both with a bounded poll.
while kill -0 "$api_pid" 2>/dev/null && kill -0 "$nginx_pid" 2>/dev/null; do
    sleep 2 &
    wait "$!" || true
done
status=1
terminate
wait "$api_pid" "$nginx_pid" 2>/dev/null || true
exit "$status"
