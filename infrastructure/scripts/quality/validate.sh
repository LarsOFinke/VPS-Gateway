#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"
export PYTHONDONTWRITEBYTECODE=1
python3 -m unittest discover -s tests -p 'test_*.py' -v
bash tests/test_target_selection.sh
bash tests/test_routes.sh
bash tests/test_version_script.sh
python3 infrastructure/scripts/quality/check_repository.py

mapfile -t shell_files < <(find . -type f \( -name '*.sh' -o -path './scripts/setup' \
  -o -path './scripts/connect-route' -o -path './scripts/remove-route' \
  -o -path './scripts/list-routes' -o -path './scripts/renew-certificates' \))
bash -n "${shell_files[@]}"
if command -v shellcheck >/dev/null 2>&1; then shellcheck "${shell_files[@]}"; fi
git diff --check
echo 'validation: OK'
