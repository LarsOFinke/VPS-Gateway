#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"
run=false; [[ "${1:-}" != --run ]] || run=true
changes="$(git status --short 2>/dev/null || true)"
gate=.agents/scripts/check-all.sh
if [[ -n "$changes" && "$changes" != *setup.sh* && "$changes" != *examples/* ]]; then
  if [[ "$changes" == *docs/* || "$changes" == *.agents/* ]]; then gate=.agents/scripts/check-docs.sh; fi
fi
echo "recommended_gate=$gate"
[[ "$run" == false ]] || exec bash "$gate"
