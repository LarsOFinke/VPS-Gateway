#!/usr/bin/env bash
set -Eeuo pipefail

printf '%s\n' "$*" >>"$FAKE_DOCKER_LOG"
if [[ "$1 $2" == 'network inspect' ]]; then
  if [[ "${3:-}" == --format ]]; then
    printf '%s\n' "$FAKE_NETWORK_INTERNAL"
    exit 0
  fi
  [[ "$FAKE_NETWORK_EXISTS" == true ]]
fi
