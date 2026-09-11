#!/usr/bin/env bash

gateway_origin_select_target() {
  local root_dir="$1"
  shift
  local target="test" seen="" config="" index requested
  local args=("$@")
  for ((index = 0; index < ${#args[@]}; index++)); do
    case "${args[$index]}" in
      --test|--production)
        requested="${args[$index]#--}"
        if [[ -n "$seen" && "$seen" != "$requested" ]]; then
          echo '[origin] --test and --production cannot be combined.' >&2
          return 2
        fi
        target="$requested"
        seen="$requested"
        ;;
      --config)
        ((index + 1 < ${#args[@]})) || { echo '[origin] --config requires a file.' >&2; return 2; }
        config="${args[$((index + 1))]}"
        ((index += 1))
        ;;
    esac
  done
  [[ -n "$config" ]] || config="${GATEWAY_ORIGIN_CONFIG:-$root_dir/.env.origin.$target}"
  GATEWAY_ORIGIN_TARGET="$target"
  GATEWAY_ORIGIN_CONFIG_FILE="$config"
  export GATEWAY_ORIGIN_TARGET GATEWAY_ORIGIN_CONFIG_FILE
}

gateway_require_external_identity() {
  local root_dir="$1" identity="$2"
  [[ -z "$identity" ]] && return 0
  [[ "$identity" == /* ]] || { echo '[origin] SSH identity must be an absolute path.' >&2; return 2; }
  local root_real identity_real
  root_real="$(realpath -m "$root_dir")"
  identity_real="$(realpath -m "$identity")"
  case "$identity_real" in
    "$root_real"|"$root_real"/*)
      echo "[origin] SSH identity must stay outside the repository: $identity_real" >&2
      return 2
      ;;
  esac
}
