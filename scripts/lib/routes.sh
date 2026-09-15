#!/usr/bin/env bash
# shellcheck disable=SC2016 # NGINX variables must stay literal in generated files.

gateway_validate_route_id() { [[ "$1" =~ ^[a-z][a-z0-9-]{0,62}$ ]]; }

gateway_validate_domain() {
  local domain="$1" label
  [[ ${#domain} -le 253 && "$domain" == *.* && "$domain" != *..* ]] || return 1
  IFS=. read -r -a labels <<<"$domain"
  for label in "${labels[@]}"; do
    [[ "$label" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]] || return 1
  done
}

gateway_validate_port() {
  [[ "$1" =~ ^[0-9]+$ ]] && ((10#$1 >= 1024 && 10#$1 <= 65535))
}

gateway_render_proxy() {
  local port="$1"
  printf '    location / {\n'
  printf '        proxy_pass http://127.0.0.1:%s;\n' "$port"
  printf '        proxy_http_version 1.1;\n'
  printf '        proxy_set_header Host $host;\n'
  printf '        proxy_set_header X-Real-IP $remote_addr;\n'
  printf '        proxy_set_header X-Forwarded-For $remote_addr;\n'
  printf '        proxy_set_header X-Forwarded-Host $host;\n'
  printf '        proxy_set_header X-Forwarded-Proto $scheme;\n'
  printf '        proxy_set_header X-Forwarded-Port $vps_gateway_forwarded_port;\n'
  printf '        proxy_set_header Upgrade $http_upgrade;\n'
  printf '        proxy_set_header Connection $vps_gateway_connection;\n'
  printf '    }\n'
}

gateway_render_route() {
  local destination="$1" route_id="$2" domain="$3" port="$4" tls="$5"
  {
    printf '# Managed by VPS-Gateway: %s -> 127.0.0.1:%s\n' "$route_id" "$port"
    printf 'server {\n    listen 80;\n    listen [::]:80;\n    server_name %s;\n\n' "$domain"
    printf '    location ^~ /.well-known/acme-challenge/ {\n'
    printf '        root /var/www/letsencrypt;\n        default_type text/plain;\n    }\n\n'
    if [[ "$tls" == true ]]; then
      printf '    location / { return 308 https://$host$request_uri; }\n'
    else
      printf '    location / { add_header Retry-After 60 always; return 503; }\n'
    fi
    printf '}\n'
    if [[ "$tls" == true ]]; then
      printf '\nserver {\n    listen 443 ssl;\n    listen [::]:443 ssl;\n'
      printf '    server_name %s;\n' "$domain"
      printf '    ssl_certificate /etc/letsencrypt/live/vps-%s/fullchain.pem;\n' "$route_id"
      printf '    ssl_certificate_key /etc/letsencrypt/live/vps-%s/privkey.pem;\n' "$route_id"
      printf '    ssl_protocols TLSv1.2 TLSv1.3;\n    client_max_body_size 25m;\n'
      gateway_render_proxy "$port"
      printf '}\n'
    fi
  } >"$destination"
}

gateway_reload() {
  nginx -t
  systemctl reload nginx
}

gateway_apply_route() {
  local candidate="$1" route_id="$2" destination pending backup=""
  destination="/etc/vps-gateway/sites/$route_id.conf"
  pending="/etc/vps-gateway/sites/.$route_id.next"
  [[ ! -L "$destination" ]] || { echo '[gateway] Refusing to replace a symlink route.' >&2; return 1; }
  if [[ -f "$destination" ]]; then backup="$(mktemp)"; cp "$destination" "$backup"; fi
  install -m 0644 -o root -g root "$candidate" "$pending"
  mv -f "$pending" "$destination"
  if ! gateway_reload; then
    if [[ -n "$backup" ]]; then
      install -m 0644 -o root -g root "$backup" "$pending"; mv -f "$pending" "$destination"
    else
      rm -f -- "$destination"
    fi
    nginx -t >/dev/null && systemctl reload nginx >/dev/null || true
    rm -f -- "$backup"
    echo '[gateway] Activation failed; the previous route was restored.' >&2
    return 1
  fi
  rm -f -- "$backup"
}
