#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"
bash tests/test_target_selection.sh
bash tests/test_setup_network.sh
bash tests/test_release_artifact.sh
docker compose --env-file infrastructure/.env.test.example config --quiet
docker compose --env-file infrastructure/.env.production.example config --quiet
