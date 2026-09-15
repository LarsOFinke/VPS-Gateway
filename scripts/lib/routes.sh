#!/usr/bin/env bash
# shellcheck disable=SC2016 # NGINX variables must remain literal in generated files.

gateway_validate_route_id() { [[ "$1" =~ ^[a-z][a-z0-9-]{0,62}$ ]]; }

gateway_validate_domain() {
  local domain="$1" label
  [[ ${#domain} -le 253 && "$domain" == *.* && "$domain" != *..* ]] || return 1
  IFS=. read -r -a labels <<<"$domain"
  for label in "${labels[@]}"; do
    [[ "$label" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]] || return 1
  done
}

gateway_validate_alias() { [[ "$1" =~ ^[a-z][a-z0-9-]{0,62}$ ]]; }

gateway_validate_port() {
  [[ "$1" =~ ^[0-9]+$ ]] && ((10#$1 >= 1 && 10#$1 <= 65535))
}

gateway_render_proxy_location() {
  local alias="$1" port="$2"
  printf '    location / {\n'
  printf '        set $gateway_upstream http://%s:%s;\n' "$alias" "$port"
  printf '        proxy_pass $gateway_upstream;\n'
  printf '        proxy_http_version 1.1;\n'
  printf '        proxy_set_header Host $host;\n'
  printf '        proxy_set_header X-Real-IP $remote_addr;\n'
  printf '        proxy_set_header X-Forwarded-For $remote_addr;\n'
  printf '        proxy_set_header X-Forwarded-Host $host;\n'
  printf '        proxy_set_header X-Forwarded-Proto $scheme;\n'
  printf '        proxy_set_header X-Forwarded-Port $gateway_forwarded_port;\n'
  printf '        proxy_set_header Upgrade $http_upgrade;\n'
  printf '        proxy_set_header Connection $gateway_connection;\n'
  printf '    }\n'
}

gateway_render_route() {
  local destination="$1" route_id="$2" domain="$3" alias="$4" port="$5" tls="$6"
  {
    printf '# Managed by VPS-Gateway: %s -> %s:%s\n' "$route_id" "$alias" "$port"
    printf 'server {\n    listen 8080;\n    server_name %s;\n\n' "$domain"
    printf '    location ^~ /.well-known/acme-challenge/ {\n'
    printf '        root /var/www/acme;\n        default_type text/plain;\n    }\n\n'
    if [[ "$tls" == true ]]; then
      printf '    location / { return 308 https://$host$request_uri; }\n'
    else
      printf '    location / {\n'
      printf '        add_header Retry-After 60 always;\n'
      printf '        return 503;\n'
      printf '    }\n'
    fi
    printf '}\n'
    if [[ "$tls" == true ]]; then
      printf '\nserver {\n    listen 8443 ssl;\n    server_name %s;\n' "$domain"
      printf '    ssl_certificate /etc/letsencrypt/live/%s/fullchain.pem;\n' "$route_id"
      printf '    ssl_certificate_key /etc/letsencrypt/live/%s/privkey.pem;\n' "$route_id"
      printf '    ssl_protocols TLSv1.2 TLSv1.3;\n'
      gateway_render_proxy_location "$alias" "$port"
      printf '}\n'
    fi
  } >"$destination"
}

gateway_compose() {
  docker compose --project-directory "$GATEWAY_ROOT_DIR" \
    --env-file "$GATEWAY_RUNTIME_CONFIG_FILE" "$@"
}

gateway_apply_route_file() {
  local candidate="$1" route_id="$2" destination pending backup=""
  destination="$GATEWAY_ROUTES_DIR/$route_id.conf"
  pending="$GATEWAY_ROUTES_DIR/.$route_id.next"
  [[ ! -L "$destination" ]] || { echo '[gateway] Refusing to replace a symlink route.' >&2; return 1; }
  if [[ -f "$destination" ]]; then backup="$(mktemp)"; cp "$destination" "$backup"; fi
  install -m 0644 "$candidate" "$pending"
  mv -f "$pending" "$destination"
  if ! gateway_compose exec -T gateway nginx -t -c /etc/nginx/nginx.conf; then
    if [[ -n "$backup" ]]; then
      install -m 0644 "$backup" "$pending"; mv -f "$pending" "$destination"
    else
      rm -f -- "$destination"
    fi
    rm -f -- "$backup"
    echo '[gateway] Candidate rejected; the previous route was restored.' >&2
    return 1
  fi
  if ! gateway_compose exec -T gateway nginx -s reload; then
    if [[ -n "$backup" ]]; then
      install -m 0644 "$backup" "$pending"; mv -f "$pending" "$destination"
    else
      rm -f -- "$destination"
    fi
    gateway_compose exec -T gateway nginx -s reload >/dev/null || true
    rm -f -- "$backup"
    echo '[gateway] Reload failed; the previous route was restored.' >&2
    return 1
  fi
  rm -f -- "$backup"
}
