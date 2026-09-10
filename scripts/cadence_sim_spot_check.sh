#!/usr/bin/env bash
# Cadence UX loop — install app and spot-check all 5 tabs (+ settings + search).
# Delegates to cadence_sim.py (screenshots land in CADENCE_SHOT_DIR).
set -euo pipefail
exec "$(dirname "$0")/cadence_sim.py" spot-check "$@"
