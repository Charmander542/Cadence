#!/usr/bin/env bash
# One-time setup for Cadence simulator automation (idb via Homebrew).
set -euo pipefail

echo "Checking Xcode simctl…"
xcrun simctl list devices available >/dev/null

if ! command -v idb >/dev/null 2>&1; then
  echo "Installing idb (companion + CLI) via Homebrew…"
  brew trust facebook/fb 2>/dev/null || true
  brew install facebook/fb/idb
else
  echo "idb already installed: $(command -v idb)"
fi

echo ""
"$(dirname "$0")/cadence_sim.py" doctor
