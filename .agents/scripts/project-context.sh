#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"
echo "project=VPS-Gateway version=$(<VERSION)"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "revision=$(git branch --show-current)@$(git rev-parse --short HEAD 2>/dev/null || echo unborn)"
  git status --short
fi
for target in test production; do
  runtime=missing; origin=missing
  [[ -f ".env.$target" ]] && runtime=present
  [[ -f ".env.origin.$target" ]] && origin=present
  echo "target=$target runtime_profile=$runtime origin_profile=$origin"
done
echo "python=$(python3 --version 2>&1)"
docker --version 2>/dev/null || true
