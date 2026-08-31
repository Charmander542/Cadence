"""SQLite persistence + JSON export."""

from __future__ import annotations

import json
import sqlite3
from pathlib import Path
from typing import Any, Iterable, Optional

from scraper.parse import ParsedRecipe

SCHEMA = """
CREATE TABLE IF NOT EXISTS recipes (
  id INTEGER PRIMARY KEY,
  source_url TEXT UNIQUE,
  title TEXT,
  base_servings INTEGER,
  image_url TEXT,
  tags TEXT,
  equipment TEXT,
  protein_g_per_serving REAL,
  calories_per_serving REAL
);

CREATE TABLE IF NOT EXISTS steps (
  id INTEGER PRIMARY KEY,
  recipe_id INTEGER REFERENCES recipes(id) ON DELETE CASCADE,
  step_number INTEGER,
  instruction TEXT
);

CREATE TABLE IF NOT EXISTS ingredients (
  id INTEGER PRIMARY KEY,
  recipe_id INTEGER REFERENCES recipes(id) ON DELETE CASCADE,
  raw_text TEXT,
  quantity REAL,
  unit TEXT,
  ingredient_name TEXT,
  category TEXT,
  is_approximate BOOLEAN,
  note TEXT
);

CREATE INDEX IF NOT EXISTS idx_ingredients_name ON ingredients(ingredient_name);
CREATE INDEX IF NOT EXISTS idx_recipes_title ON recipes(title);
"""


class RecipeDB:
    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.conn = sqlite3.connect(self.path)
        self.conn.row_factory = sqlite3.Row
        self.conn.execute("PRAGMA foreign_keys = ON")
        self.conn.executescript(SCHEMA)
        self._migrate()
        self.conn.commit()

    def _migrate(self) -> None:
        cols = {row[1] for row in self.conn.execute("PRAGMA table_info(recipes)")}
        if "equipment" not in cols:
            self.conn.execute("ALTER TABLE recipes ADD COLUMN equipment TEXT")

    def close(self) -> None:
        self.conn.close()

    def has_url(self, url: str) -> bool:
        cur = self.conn.execute("SELECT 1 FROM recipes WHERE source_url = ?", (url,))
        return cur.fetchone() is not None

    def upsert_recipe(
        self,
        recipe: ParsedRecipe,
        normalized_ingredients: list[dict[str, Any]],
    ) -> int:
        cur = self.conn.execute(
            """
            INSERT INTO recipes (source_url, title, base_servings, image_url, tags, equipment,
                                 protein_g_per_serving, calories_per_serving)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(source_url) DO UPDATE SET
              title=excluded.title,
              base_servings=excluded.base_servings,
              image_url=excluded.image_url,
              tags=excluded.tags,
              equipment=excluded.equipment,
              protein_g_per_serving=excluded.protein_g_per_serving,
              calories_per_serving=excluded.calories_per_serving
            """,
            (
                recipe.source_url,
                recipe.title,
                recipe.base_servings,
                recipe.image_url,
                ",".join(recipe.tags),
                ",".join(recipe.equipment),
                recipe.protein_g_per_serving,
                recipe.calories_per_serving,
            ),
        )
        if cur.lastrowid:
            recipe_id = int(cur.lastrowid)
        else:
            recipe_id = int(
                self.conn.execute(
                    "SELECT id FROM recipes WHERE source_url = ?", (recipe.source_url,)
                ).fetchone()["id"]
            )

        self.conn.execute("DELETE FROM steps WHERE recipe_id = ?", (recipe_id,))
        self.conn.execute("DELETE FROM ingredients WHERE recipe_id = ?", (recipe_id,))

        self.conn.executemany(
            "INSERT INTO steps (recipe_id, step_number, instruction) VALUES (?, ?, ?)",
            [(recipe_id, i + 1, step) for i, step in enumerate(recipe.steps)],
        )
        rows = []
        for raw, norm in zip(recipe.ingredients, normalized_ingredients):
            rows.append(
                (
                    recipe_id,
                    raw,
                    norm.get("quantity"),
                    norm.get("unit"),
                    norm.get("ingredient"),
                    norm.get("category"),
                    1 if norm.get("is_approximate") else 0,
                    norm.get("note") or "",
                )
            )
        self.conn.executemany(
            """
            INSERT INTO ingredients
              (recipe_id, raw_text, quantity, unit, ingredient_name, category, is_approximate, note)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            rows,
        )
        self.conn.commit()
        return recipe_id

    def count_recipes(self) -> int:
        return int(self.conn.execute("SELECT COUNT(*) AS c FROM recipes").fetchone()["c"])

    def export_json(self, path: str | Path) -> None:
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        recipes = []
        for row in self.conn.execute("SELECT * FROM recipes ORDER BY id"):
            rid = row["id"]
            steps = [
                dict(s)
                for s in self.conn.execute(
                    "SELECT step_number, instruction FROM steps WHERE recipe_id=? ORDER BY step_number",
                    (rid,),
                )
            ]
            ings = [
                dict(i)
                for i in self.conn.execute(
                    """
                    SELECT raw_text, quantity, unit, ingredient_name, category, is_approximate, note
                    FROM ingredients WHERE recipe_id=? ORDER BY id
                    """,
                    (rid,),
                )
            ]
            recipes.append(
                {
                    "id": rid,
                    "source_url": row["source_url"],
                    "title": row["title"],
                    "base_servings": row["base_servings"],
                    "image_url": row["image_url"],
                    "tags": (row["tags"] or "").split(",") if row["tags"] else [],
                    "equipment": (row["equipment"] or "").split(",") if row["equipment"] else [],
                    "protein_g_per_serving": row["protein_g_per_serving"],
                    "calories_per_serving": row["calories_per_serving"],
                    "steps": steps,
                    "ingredients": ings,
                }
            )
        path.write_text(json.dumps(recipes, indent=2, ensure_ascii=False), encoding="utf-8")
