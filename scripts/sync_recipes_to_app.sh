#!/usr/bin/env bash
# Copy the Based-Cooking SQLite store into the iOS app bundle.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/data/recipes.sqlite3"
DST="$ROOT/Cadence/Cadence/Resources/recipes.sqlite3"
if [[ ! -f "$SRC" ]]; then
  echo "Missing $SRC — run: python3 scripts/build_recipe_store.py"
  exit 1
fi
mkdir -p "$(dirname "$DST")"
cp -f "$SRC" "$DST"
echo "Copied $(python3 - <<PY
import sqlite3
print(sqlite3.connect('$SRC').execute('select count(*) from recipes').fetchone()[0])
PY
) recipes → $DST"
