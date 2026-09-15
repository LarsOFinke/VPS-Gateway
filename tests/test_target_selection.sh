#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/lib/target.sh"

gateway_select_target
[[ "$GATEWAY_TARGET" == test ]]
gateway_select_target --production
[[ "$GATEWAY_TARGET" == production ]]
gateway_select_target --test
[[ "$GATEWAY_TARGET" == test ]]
if gateway_select_target --test --production >/dev/null 2>&1; then
  echo 'mixed targets were accepted' >&2
  exit 1
fi

gateway_strip_target_arguments --production route example.org 18081
[[ "${GATEWAY_REMAINING_ARGS[*]}" == 'route example.org 18081' ]]
echo 'target selection: OK'
