#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"
bash tests/test_target_selection.sh
bash tests/test_routes.sh
bash -n scripts/setup scripts/connect-route scripts/remove-route scripts/list-routes scripts/renew-certificates
