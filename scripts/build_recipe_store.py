#!/usr/bin/env python3
"""Build the Based-Cooking recipe store used by the iOS app.

Keeps cookbook / based.cooking recipes only (no Cadence web scrape).
Scrapes https://based.cooking/ and copies SQLite into the app bundle.
"""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "backend" / "based-cooking" / "src"
sys.path.insert(0, str(BACKEND))

from based_cooking.store import RecipeStore  # noqa: E402

LEGACY_WEB_SOURCES = {
    "budgetbytes",
    "cookieandkate",
    "loveandlemons",
    "foodnetwork",
}


def scrape_based_cooking(limit: int = 0) -> list:
    from based_cooking.sources.based_cooking_web import BasedCookingWebSource

    src = BasedCookingWebSource(delay_seconds=0.12, limit=limit)
    return src.extract()


def is_legacy_web(recipe) -> bool:
    if (recipe.id or "").startswith("legacy-"):
        return True
    return (recipe.source or "").lower() in LEGACY_WEB_SOURCES


def main() -> int:
    data_dir = ROOT / "data"
    data_dir.mkdir(exist_ok=True)
    store = RecipeStore(data_dir)

    merged = {}
    kept, dropped = 0, 0
    for recipe in store.load_all():
        if is_legacy_web(recipe):
            dropped += 1
            continue
        merged[recipe.id] = recipe
        kept += 1
    print(f"existing store: kept {kept}, dropped {dropped} legacy web recipes")

    web = scrape_based_cooking()
    print(f"based.cooking: {len(web)}")
    for recipe in web:
        merged[recipe.id] = recipe

    recipes = list(merged.values())
    if not recipes:
        print("No recipes found.", file=sys.stderr)
        return 1

    store.replace_all(recipes)
    print(f"store: {len(recipes)} recipes → {store.db_path}")

    dest_dir = ROOT / "Cadence" / "Cadence" / "Resources"
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest = dest_dir / "recipes.sqlite3"
    shutil.copy2(store.db_path, dest)
    print(f"copied → {dest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
