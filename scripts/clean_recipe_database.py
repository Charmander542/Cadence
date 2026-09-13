#!/usr/bin/env python3
"""Clean every recipe in the Based-Cooking SQLite store.

Re-parses ingredients, drops junk lines, cleans Joy-of-Cooking steps, and
copies the result into the iOS app bundle.

Usage:
  python3 scripts/clean_recipe_database.py
"""
from __future__ import annotations

import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "backend" / "based-cooking" / "src"
sys.path.insert(0, str(BACKEND))

from based_cooking.course import apply_course  # noqa: E402
from based_cooking.ingredients import (  # noqa: E402
    clean_ingredient_line,
    parse_ingredients,
    recipe_allergens,
)
from based_cooking.models import Recipe, RecipeStep  # noqa: E402
from based_cooking.store import RecipeStore, _row_to_recipe  # noqa: E402

ALT_VERSION_RE = re.compile(
    r"\b(version\s*[iI1-9]|first popularized|cold-start|as for version|variation\s*[iI1-9])\b",
    re.I,
)
SERVE_DONE_RE = re.compile(r"^\s*serve (at once|immediately)\b", re.I)
DOUBLE_NUM_RE = re.compile(r"^\s*\d+[.)]\s*(?=\d+[.)])")
LEADING_NUM_RE = re.compile(r"^\s*\d+[.)]\s+")


def load_from_sqlite(store: RecipeStore) -> list[Recipe]:
    """Prefer SQLite over jsonl so restoring recipes.sqlite3 actually re-cleans."""
    import sqlite3

    if not store.db_path.exists():
        return store.load_all()
    conn = sqlite3.connect(store.db_path)
    conn.row_factory = sqlite3.Row
    try:
        rows = conn.execute("SELECT * FROM recipes ORDER BY name").fetchall()
        return [_row_to_recipe(row) for row in rows]
    finally:
        conn.close()


def clean_step_text(text: str) -> str:
    t = (text or "").replace("\xa0", " ")
    t = re.sub(r"\s+", " ", t).strip()
    # Strip duplicated numbering ("1. 1. Season…")
    t = DOUBLE_NUM_RE.sub("", t)
    t = LEADING_NUM_RE.sub("", t)
    t = re.sub(r"\s*see here(?:\s*[–—-]\s*here)?\s*", " ", t, flags=re.I)
    t = re.sub(r"\(\s*\)", "", t)  # empty cross-ref leftovers
    # Trailing page pointers from OCR/Joy ("batons, 201:")
    t = re.sub(r",\s*\d{2,4}:\s*$", "", t)
    t = re.sub(r"\s+", " ", t).strip(" ,;")
    return t


def clean_step_ingredients(lines: list[str]) -> list[str]:
    out: list[str] = []
    for line in lines:
        cleaned = clean_ingredient_line(line)
        if cleaned:
            out.append(cleaned)
    return out


def clean_steps(steps: list[RecipeStep]) -> list[RecipeStep]:
    """Drop empty/orphan steps, clean text, truncate alternate-version essays."""
    cleaned: list[RecipeStep] = []
    for step in steps:
        text = clean_step_text(step.text)
        ings = clean_step_ingredients(list(step.ingredients or []))
        if not text and not ings:
            continue
        cleaned.append(RecipeStep(text=text, ingredients=ings))

    # After an explicit "Serve at once/immediately", drop alternate-method essays.
    trim_at = None
    for i, step in enumerate(cleaned):
        if SERVE_DONE_RE.match(step.text or "") and i + 1 < len(cleaned):
            # Look ahead for version essays
            if any(ALT_VERSION_RE.search(s.text or "") for s in cleaned[i + 1 :]):
                trim_at = i + 1
                break
    if trim_at is not None:
        cleaned = cleaned[:trim_at]

    # Soften trailing "Or, use any of the suggestions for X" pointers — keep but shorten.
    out: list[RecipeStep] = []
    for step in cleaned:
        text = step.text
        if re.match(r"^\s*or,?\s+use any of the suggestions\b", text or "", re.I):
            continue
        if re.match(r"^\s*to serve,?\s+see\b", text or "", re.I):
            continue
        if re.match(r"^\s*prepare version\b", text or "", re.I):
            # Alternate assembly note — keep if it has concrete instructions > 40 chars
            if len(text) < 40 and not step.ingredients:
                continue
        out.append(step)
    return out


def clean_top_level_ingredients(lines: list[str]) -> list[str]:
    out: list[str] = []
    for line in lines:
        cleaned = clean_ingredient_line(line)
        if cleaned:
            out.append(cleaned)
    return out


def is_non_recipe(recipe: Recipe) -> bool:
    """Drop stub / variation pages that aren't cookable recipes."""
    name = (recipe.name or "").strip()
    if not name:
        return True
    if name.casefold() in {"try", "try this", "mix"}:
        return True
    if re.match(r"^additions to\b", name, re.I):
        return True
    if re.match(r"^strata combinations\b", name, re.I):
        return True
    # Empty shells with no food at all.
    if not recipe.ingredients and not recipe.steps:
        return True
    return False


def ensure_minimal_steps(recipe: Recipe) -> None:
    """Sauces/relishes often ship with ingredients only — add a usable combine step."""
    if recipe.steps:
        return
    if not recipe.ingredients:
        return
    course = (recipe.course or "").casefold()
    name = (recipe.name or "").casefold()
    # Only true sauce/condiment pages — never mains (even if course is mis-tagged).
    is_condiment = course == "sauce" or re.search(
        r"(^|\b)(vinaigrette|chimichurri|salsa verde|relish|dressing|"
        r"aioli|mayonnaise|fry sauce|kecap manis|nam pla|prik|"
        r"tonkatsu sauce|mentuyu|bibimbap sauce)\b",
        name,
    )
    if is_condiment:
        recipe.steps = [
            RecipeStep(text="Combine all ingredients until well mixed.", ingredients=[])
        ]


def clean_recipe(recipe: Recipe) -> tuple[Recipe, dict[str, int]]:
    stats = {
        "ing_dropped": 0,
        "ing_before": len(recipe.ingredients),
        "steps_before": len(recipe.steps),
        "steps_after": 0,
        "parsed_after": 0,
    }
    before = list(recipe.ingredients)
    recipe.ingredients = clean_top_level_ingredients(recipe.ingredients)
    stats["ing_dropped"] = max(0, len(before) - len(recipe.ingredients))

    recipe.steps = clean_steps(recipe.steps)
    ensure_minimal_steps(recipe)
    stats["steps_after"] = len(recipe.steps)

    # Always re-parse from cleaned lines.
    recipe.parsed_ingredients = parse_ingredients(recipe.ingredients)
    recipe.allergens = recipe_allergens(recipe.parsed_ingredients)
    apply_course(recipe)
    stats["parsed_after"] = len(recipe.parsed_ingredients)
    return recipe, stats


def main() -> int:
    data_dir = ROOT / "data"
    store = RecipeStore(data_dir)
    recipes = load_from_sqlite(store)
    if not recipes:
        print("No recipes found in", store.db_path, file=sys.stderr)
        return 1

    print(f"Cleaning {len(recipes)} recipes from {store.db_path}…")
    totals = {
        "ing_dropped": 0,
        "steps_removed": 0,
        "empty_step_recipes_fixed": 0,
        "zero_step_recipes": 0,
        "dropped_non_recipes": 0,
        "synth_steps": 0,
    }
    cleaned: list[Recipe] = []
    for i, recipe in enumerate(recipes, 1):
        if is_non_recipe(recipe):
            totals["dropped_non_recipes"] += 1
            continue
        before_steps = len(recipe.steps)
        had_empty = any(not (s.text or "").strip() and not (s.ingredients or []) for s in recipe.steps)
        recipe, stats = clean_recipe(recipe)
        # Drop again after cleaning if we stripped everything useful.
        if not recipe.ingredients and not recipe.steps:
            totals["dropped_non_recipes"] += 1
            continue
        if before_steps == 0 and recipe.steps:
            totals["synth_steps"] += 1
        totals["ing_dropped"] += stats["ing_dropped"]
        totals["steps_removed"] += max(0, before_steps - stats["steps_after"])
        if had_empty:
            totals["empty_step_recipes_fixed"] += 1
        if not recipe.steps:
            totals["zero_step_recipes"] += 1
        cleaned.append(recipe)
        if i % 500 == 0 or i == len(recipes):
            print(f"  {i}/{len(recipes)}")

    # Backup then replace
    backup = data_dir / "recipes.sqlite3.bak"
    if store.db_path.exists():
        shutil.copy2(store.db_path, backup)
        print(f"backup → {backup}")

    store.replace_all(cleaned)
    print(f"wrote {len(cleaned)} recipes → {store.db_path}")
    print("stats:", totals)

    dest = ROOT / "Cadence" / "Cadence" / "Resources" / "recipes.sqlite3"
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(store.db_path, dest)
    print(f"copied → {dest}")

    # Spot-check previously painful recipes
    by_name = {r.name.upper(): r for r in cleaned}
    for key in [
        "GOHAN (PLAIN JAPANESE RICE)",
        "FRENCH FRIES",
        "LONDON BROIL",
        "3-MINUTE CHICKEN CUTLETS",
        "CREAMED CHICKEN",
        "SWEET POTATO FRIES",
        "PAD KHANA BACON KROP",
        "CHIMICHURRI SAUCE",
        "AJITSUKE TAMAGO",
    ]:
        r = by_name.get(key)
        if not r:
            # fuzzy
            r = next((x for x in cleaned if x.name.upper().startswith(key[:12])), None)
        if not r:
            print(f"spot-check MISSING {key}")
            continue
        print(f"\nSPOT {r.name}")
        print("  ings:", r.ingredients[:6], ("…" if len(r.ingredients) > 6 else ""))
        print("  parsed:", [p.display() for p in r.parsed_ingredients[:6]])
        print("  steps:", len(r.steps))
        for i, s in enumerate(r.steps[:4], 1):
            preview = (s.text[:100] + "…") if len(s.text) > 100 else s.text
            print(f"   {i}. {preview!r} +{len(s.ingredients)} ings")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
