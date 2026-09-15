#!/usr/bin/env bash

gateway_select_target() {
  local target=test seen="" requested
  for argument in "$@"; do
    case "$argument" in
      --test|--production)
        requested="${argument#--}"
        if [[ -n "$seen" && "$seen" != "$requested" ]]; then
          echo '[gateway] --test and --production cannot be combined.' >&2
          return 2
        fi
        target="$requested"
        seen="$requested"
        ;;
    esac
  done
  GATEWAY_TARGET="$target"
  export GATEWAY_TARGET
}

gateway_strip_target_arguments() {
  GATEWAY_REMAINING_ARGS=()
  while (($#)); do
    case "$1" in
      --test|--production) shift ;;
      *) GATEWAY_REMAINING_ARGS+=("$1"); shift ;;
    esac
  done
}

gateway_require_root() {
  [[ "$EUID" -eq 0 ]] || {
    echo '[gateway] Run this command with sudo.' >&2
    return 1
  }
}

gateway_require_installed_target() {
  local marker=/etc/vps-gateway/environment installed
  [[ -f "$marker" && ! -L "$marker" ]] || {
    echo "[gateway:$GATEWAY_TARGET] Run scripts/setup --$GATEWAY_TARGET first." >&2
    return 1
  }
  installed="$(<"$marker")"
  [[ "$installed" == "$GATEWAY_TARGET" ]] || {
    echo "[gateway] This server is '$installed'; explicitly select --$installed." >&2
    return 2
  }
}
