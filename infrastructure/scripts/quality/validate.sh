#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"
export PYTHONDONTWRITEBYTECODE=1
PYTHONPATH=src python3 -m unittest discover -s tests -p 'test_*.py' -v
bash tests/test_target_selection.sh
bash tests/test_setup_network.sh
bash tests/test_setup_admin.sh
bash tests/test_release_artifact.sh
bash tests/test_version_script.sh
python3 infrastructure/scripts/quality/check_repository.py

mapfile -t shell_files < <(find . -type f -name '*.sh' -o -path './scripts/gatewayctl' -o -path './scripts/connect-route' -o -path './scripts/setup' -o -path './scripts/renew-certificates')
bash -n "${shell_files[@]}"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "${shell_files[@]}"
fi
docker compose --env-file infrastructure/.env.test.example config --quiet
docker compose --env-file infrastructure/.env.production.example config --quiet
echo 'validation: OK'
