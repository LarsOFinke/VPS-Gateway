#!/usr/bin/env bash

gateway_select_runtime_target() {
  local root_dir="$1"
  shift
  local target="test" seen="" config="" index requested
  local args=("$@")
  for ((index = 0; index < ${#args[@]}; index++)); do
    case "${args[$index]}" in
      --test|--production)
        requested="${args[$index]#--}"
        if [[ -n "$seen" && "$seen" != "$requested" ]]; then
          echo '[gateway] --test and --production cannot be combined.' >&2
          return 2
        fi
        target="$requested"
        seen="$requested"
        ;;
      --config)
        ((index + 1 < ${#args[@]})) || { echo '[gateway] --config requires a file.' >&2; return 2; }
        config="${args[$((index + 1))]}"
        ((index += 1))
        ;;
    esac
  done
  [[ -n "$config" ]] || config="${GATEWAY_RUNTIME_CONFIG:-$root_dir/.env.$target}"
  GATEWAY_TARGET="$target"
  GATEWAY_RUNTIME_CONFIG_FILE="$config"
  export GATEWAY_TARGET GATEWAY_RUNTIME_CONFIG_FILE
}

gateway_load_runtime_config() {
  local root_dir="$1" config_file="$2" expected_target="$3"
  [[ -f "$config_file" && ! -L "$config_file" ]] || {
    echo "[gateway:$expected_target] Runtime configuration is missing or is a symlink: $config_file" >&2
    echo "[gateway:$expected_target] Run ./scripts/setup --$expected_target first." >&2
    return 1
  }
  local mode owner
  mode="$(stat -c '%a' "$config_file")"
  owner="$(stat -c '%u' "$config_file")"
  [[ "$mode" == 600 ]] || { echo "[gateway] Unsafe runtime configuration mode $mode; expected 600: $config_file" >&2; return 1; }
  [[ "$owner" == "$(id -u)" ]] || {
    echo "[gateway] Runtime configuration is not owned by the invoking user: $config_file" >&2
    return 1
  }
  set -a
  # shellcheck disable=SC1090
  source "$config_file"
  set +a
  [[ "${GATEWAY_ENVIRONMENT:-}" == "$expected_target" ]] || {
    echo "[gateway] Profile environment '${GATEWAY_ENVIRONMENT:-unset}' does not match target '$expected_target'." >&2
    return 1
  }
  if [[ "${GATEWAY_ROUTES_DIR:-}" == "./.runtime/$expected_target/routes" ]]; then
    GATEWAY_ROUTES_DIR="$root_dir/.runtime/$expected_target/routes"
    export GATEWAY_ROUTES_DIR
  elif [[ "${GATEWAY_ROUTES_DIR:-}" != /* || "$GATEWAY_ROUTES_DIR" == / ]]; then
    echo '[gateway] GATEWAY_ROUTES_DIR must be the target default or a non-root absolute path.' >&2
    return 1
  fi
  GATEWAY_ROOT_DIR="$root_dir"
  export GATEWAY_ROOT_DIR
}

gateway_strip_target_arguments() {
  GATEWAY_REMAINING_ARGS=()
  while (($#)); do
    case "$1" in
      --test|--production) shift ;;
      --config) (($# >= 2)) || return 2; shift 2 ;;
      *) GATEWAY_REMAINING_ARGS+=("$1"); shift ;;
    esac
  done
}
