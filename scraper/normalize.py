"""Ingredient line normalization via Claude or ChatGPT (batched) with heuristic fallback + cache."""

from __future__ import annotations

import json
import logging
import re
from pathlib import Path
from typing import Any, Optional

log = logging.getLogger(__name__)

UNITS = {"g", "kg", "ml", "l", "tsp", "tbsp", "cup", "oz", "lb", "count", "to_taste"}
CATEGORIES = {"produce", "protein", "dairy", "pantry", "spice", "frozen", "other"}

UNIT_ALIASES = {
    "teaspoon": "tsp",
    "teaspoons": "tsp",
    "t": "tsp",
    "tsp.": "tsp",
    "tablespoon": "tbsp",
    "tablespoons": "tbsp",
    "tbsp.": "tbsp",
    "T": "tbsp",
    "cups": "cup",
    "c": "cup",
    "c.": "cup",
    "ounce": "oz",
    "ounces": "oz",
    "oz.": "oz",
    "pound": "lb",
    "pounds": "lb",
    "lbs": "lb",
    "lb.": "lb",
    "gram": "g",
    "grams": "g",
    "kilogram": "kg",
    "kilograms": "kg",
    "milliliter": "ml",
    "milliliters": "ml",
    "millilitre": "ml",
    "millilitres": "ml",
    "liter": "l",
    "liters": "l",
    "litre": "l",
    "litres": "l",
    "clove": "count",
    "cloves": "count",
    "can": "count",
    "cans": "count",
    "package": "count",
    "packages": "count",
    "slice": "count",
    "slices": "count",
    "piece": "count",
    "pieces": "count",
    "bunch": "count",
    "bunches": "count",
    "head": "count",
    "heads": "count",
    "stalk": "count",
    "stalks": "count",
    "large": "count",
    "medium": "count",
    "small": "count",
}

VAGUE = {
    "pinch": (0.06, "tsp"),
    "smidge": (0.06, "tsp"),
    "dash": (0.125, "tsp"),
    "handful": (0.5, "cup"),
    "splash": (1.0, "tbsp"),
    "drizzle": (1.0, "tbsp"),
    "to taste": (1.0, "to_taste"),
}

PROTEIN_WORDS = {
    "chicken", "beef", "pork", "turkey", "salmon", "tuna", "shrimp", "tofu",
    "tempeh", "eggs", "egg", "bacon", "sausage", "lamb", "fish", "cod",
    "ground beef", "ground turkey", "ground chicken",
}
DAIRY_WORDS = {
    "milk", "butter", "cheese", "yogurt", "cream", "parmesan", "mozzarella",
    "cheddar", "feta", "ricotta", "sour cream", "half-and-half",
}
SPICE_WORDS = {
    "salt", "pepper", "cumin", "paprika", "oregano", "basil", "thyme",
    "cinnamon", "chili", "garlic powder", "onion powder", "cayenne",
    "curry", "turmeric", "rosemary", "parsley", "cilantro", "dill",
    "red pepper flakes", "black pepper", "seasoning",
}
PRODUCE_WORDS = {
    "onion", "garlic", "tomato", "spinach", "kale", "lettuce", "carrot",
    "celery", "potato", "broccoli", "pepper", "bell pepper", "lemon",
    "lime", "avocado", "cucumber", "zucchini", "mushroom", "cabbage",
    "ginger", "scallion", "green onion", "shallot", "apple", "banana",
    "berry", "fruit", "herb",
}
FROZEN_WORDS = {"frozen"}


SYSTEM_PROMPT = """You normalize raw recipe ingredient lines into structured JSON for grocery consolidation.
Return ONLY a JSON array (no markdown) with one object per input line, same order:
{
  "quantity": number,
  "unit": one of [g, kg, ml, l, tsp, tbsp, cup, oz, lb, count, to_taste],
  "ingredient": "normalized lowercase singular name",
  "category": one of [produce, protein, dairy, pantry, spice, frozen, other],
  "note": "optional prep/brand note or empty string",
  "is_approximate": boolean
}
Rules:
- Vague amounts (pinch, smidge, handful, to taste) => is_approximate true and a small best-guess quantity.
- "to taste" with no number => unit to_taste, quantity 1, is_approximate true.
- Separate optional notes (chopped, low sodium) into note; keep ingredient_name clean.
- Do not invent ingredients that are not in the line.
- Eggs must always use unit "count" (number of eggs), never weight.
- Prefer shopping-friendly names (broccoli, spinach) without prep words.
"""


class IngredientNormalizer:
    def __init__(
        self,
        cache_path: str | Path,
        provider: str = "anthropic",
        anthropic_api_key: str = "",
        openai_api_key: str = "",
        anthropic_model: str = "claude-sonnet-4-20250514",
        openai_model: str = "gpt-4o-mini",
        batch_size: int = 20,
        # Back-compat kwargs
        api_key: str = "",
        model: str = "",
    ) -> None:
        self.cache_path = Path(cache_path)
        self.cache_path.parent.mkdir(parents=True, exist_ok=True)
        self.provider = (provider or "anthropic").strip().lower()
        self.anthropic_api_key = (anthropic_api_key or api_key or "").strip()
        self.openai_api_key = (openai_api_key or "").strip()
        self.anthropic_model = anthropic_model or model or "claude-sonnet-4-20250514"
        self.openai_model = openai_model or "gpt-4o-mini"
        self.batch_size = batch_size
        self.cache: dict[str, dict[str, Any]] = {}
        if self.cache_path.exists():
            try:
                self.cache = json.loads(self.cache_path.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                self.cache = {}
        self._anthropic = None
        self._openai = None
        self._backend: Optional[str] = None

        if self.provider == "openai" and self.openai_api_key:
            try:
                from openai import OpenAI

                self._openai = OpenAI(api_key=self.openai_api_key)
                self._backend = "openai"
            except Exception as exc:  # noqa: BLE001
                log.warning("Could not init OpenAI client: %s — using heuristic fallback", exc)
        elif self.anthropic_api_key:
            try:
                import anthropic

                self._anthropic = anthropic.Anthropic(api_key=self.anthropic_api_key)
                self._backend = "anthropic"
            except Exception as exc:  # noqa: BLE001
                log.warning("Could not init Anthropic client: %s — using heuristic fallback", exc)
        elif self.openai_api_key:
            # Fall back to OpenAI if Claude key missing but OpenAI is present.
            try:
                from openai import OpenAI

                self._openai = OpenAI(api_key=self.openai_api_key)
                self._backend = "openai"
            except Exception as exc:  # noqa: BLE001
                log.warning("Could not init OpenAI client: %s — using heuristic fallback", exc)

    @property
    def has_llm(self) -> bool:
        return self._backend is not None

    def save_cache(self) -> None:
        self.cache_path.write_text(json.dumps(self.cache, indent=2, ensure_ascii=False), encoding="utf-8")

    def normalize_many(self, lines: list[str]) -> list[dict[str, Any]]:
        results: list[Optional[dict[str, Any]]] = [None] * len(lines)
        pending_idx: list[int] = []
        pending_lines: list[str] = []

        for i, line in enumerate(lines):
            key = line.strip().lower()
            if key in self.cache:
                results[i] = self.cache[key]
            else:
                pending_idx.append(i)
                pending_lines.append(line)

        if pending_lines and self.has_llm:
            for start in range(0, len(pending_lines), self.batch_size):
                chunk = pending_lines[start : start + self.batch_size]
                idxs = pending_idx[start : start + self.batch_size]
                parsed = self._llm_batch(chunk)
                for j, line in enumerate(chunk):
                    item = parsed[j] if j < len(parsed) else self._heuristic(line)
                    item = self._validate(item, line)
                    self.cache[line.strip().lower()] = item
                    results[idxs[j]] = item
            self.save_cache()
        else:
            for i, line in zip(pending_idx, pending_lines):
                item = self._validate(self._heuristic(line), line)
                self.cache[line.strip().lower()] = item
                results[i] = item
            if pending_lines:
                self.save_cache()

        return [r if r is not None else self._heuristic(lines[i]) for i, r in enumerate(results)]

    def _llm_batch(self, lines: list[str]) -> list[dict[str, Any]]:
        payload = json.dumps(lines, ensure_ascii=False)
        user = f"Normalize these ingredient lines to a JSON array:\n{payload}"
        try:
            if self._backend == "openai":
                text = self._openai_complete(user)
            else:
                text = self._anthropic_complete(user)
            text = text.strip()
            if text.startswith("```"):
                text = re.sub(r"^```(?:json)?\s*", "", text)
                text = re.sub(r"\s*```$", "", text)
            data = json.loads(text)
            if isinstance(data, dict) and "ingredients" in data:
                data = data["ingredients"]
            if not isinstance(data, list):
                raise ValueError("expected list")
            out: list[dict[str, Any]] = []
            for i, line in enumerate(lines):
                if i < len(data) and isinstance(data[i], dict):
                    out.append(data[i])
                else:
                    out.append(self._heuristic(line))
            return out
        except Exception as exc:  # noqa: BLE001
            log.warning("LLM normalize failed (%s); heuristic fallback for %d lines", exc, len(lines))
            return [self._heuristic(line) for line in lines]

    def _anthropic_complete(self, user: str) -> str:
        assert self._anthropic is not None
        msg = self._anthropic.messages.create(
            model=self.anthropic_model,
            max_tokens=4096,
            system=SYSTEM_PROMPT,
            messages=[{"role": "user", "content": user}],
        )
        return "".join(getattr(b, "text", "") for b in msg.content)

    def _openai_complete(self, user: str) -> str:
        assert self._openai is not None
        # Prefer wrapping as object for models that insist on JSON objects.
        system = (
            SYSTEM_PROMPT
            + '\nIf you must return an object, use {"ingredients": [...]} with the array above.'
            + "\nRespond with valid JSON only — no markdown fences."
        )
        resp = self._openai.chat.completions.create(
            model=self.openai_model,
            temperature=0.2,
            max_tokens=4096,
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
        )
        return resp.choices[0].message.content or ""

    def _validate(self, item: dict[str, Any], raw: str) -> dict[str, Any]:
        unit = str(item.get("unit") or "count").lower()
        unit = UNIT_ALIASES.get(unit, unit)
        if unit not in UNITS:
            unit = "count"
        cat = str(item.get("category") or "other").lower()
        if cat not in CATEGORIES:
            cat = "other"
        try:
            qty = float(item.get("quantity") if item.get("quantity") is not None else 1.0)
        except (TypeError, ValueError):
            qty = 1.0
        name = str(item.get("ingredient") or raw).strip().lower()
        name = re.sub(r"\s+", " ", name)
        name = self._clean_name(name)

        # Eggs should always be a count (never ounces/grams on the grocery list later).
        if name in {"egg", "eggs"} or name.startswith("egg "):
            name = "egg"
            cat = "protein"
            if unit in {"g", "kg", "oz", "lb"}:
                grams = qty
                if unit == "kg":
                    grams = qty * 1000
                elif unit == "oz":
                    grams = qty * 28.3495
                elif unit == "lb":
                    grams = qty * 453.592
                qty = max(1.0, round(grams / 50.0))
                unit = "count"
            elif unit == "to_taste":
                unit = "count"
                qty = max(1.0, qty)

        return {
            "quantity": qty,
            "unit": unit,
            "ingredient": name,
            "category": cat,
            "note": str(item.get("note") or "").strip(),
            "is_approximate": bool(item.get("is_approximate", False)),
        }

    def _heuristic(self, line: str) -> dict[str, Any]:
        """Local fallback so we can build recipes.db without an API key."""
        original = line.strip()
        text = original.lower()
        note = ""
        is_approx = False

        # Parenthetical notes
        parens = re.findall(r"\(([^)]*)\)", text)
        if parens:
            note = "; ".join(parens)
            text = re.sub(r"\([^)]*\)", " ", text)

        for phrase, (q, u) in VAGUE.items():
            if phrase in text:
                is_approx = True
                name = re.sub(rf"\b{re.escape(phrase)}\b( of)?", " ", text)
                name = re.sub(r"\b(a|an|of)\b", " ", name)
                name = self._clean_name(name)
                return {
                    "quantity": q,
                    "unit": u,
                    "ingredient": name or "seasoning",
                    "category": self._guess_category(name),
                    "note": note,
                    "is_approximate": True,
                }

        # Fractions / mixed numbers
        text_norm = text.replace("¼", "1/4").replace("½", "1/2").replace("¾", "3/4")
        text_norm = text_norm.replace("⅓", "1/3").replace("⅔", "2/3").replace("⅛", "1/8")
        qty = None
        unit = "count"
        rest = text_norm

        m = re.match(
            r"^\s*(\d+\s+\d+/\d+|\d+/\d+|\d+\.\d+|\d+)\s*"
            r"(teaspoons?|tablespoons?|tsp\.?|tbsp\.?|cups?|c\.|ounces?|oz\.?|"
            r"pounds?|lbs?\.?|grams?|g|kilograms?|kg|milliliters?|ml|liters?|l|"
            r"cloves?|cans?|packages?|slices?|pieces?|bunches?|heads?|stalks?)?\b\s*(.*)$",
            text_norm,
            flags=re.I,
        )
        if m:
            qty = self._parse_number(m.group(1))
            raw_unit = (m.group(2) or "").strip().lower()
            rest = m.group(3) or ""
            if raw_unit:
                candidate = UNIT_ALIASES.get(raw_unit, UNIT_ALIASES.get(raw_unit.rstrip("."), raw_unit.rstrip(".")))
                unit = candidate if candidate in UNITS else "count"
            else:
                # "2 eggs" → count
                unit = "count"
        else:
            qty = 1.0
            is_approx = True
            rest = text_norm

        # Leading size words without qty unit already handled
        rest = re.sub(r"^(large|medium|small)\s+", "", rest).strip()
        if rest.startswith("of "):
            rest = rest[3:]

        # Split on comma for notes
        if "," in rest:
            name_part, _, maybe_note = rest.partition(",")
            rest = name_part
            extra = maybe_note.strip()
            if extra:
                note = f"{note}; {extra}".strip("; ").strip()

        name = self._clean_name(rest)
        if not name:
            name = self._clean_name(original.lower()) or "ingredient"

        return {
            "quantity": float(qty if qty is not None else 1.0),
            "unit": unit,
            "ingredient": name,
            "category": self._guess_category(name),
            "note": note,
            "is_approximate": is_approx,
        }

    @staticmethod
    def _parse_number(s: str) -> float:
        s = s.strip()
        if " " in s and "/" in s:
            whole, frac = s.split(None, 1)
            return float(whole) + IngredientNormalizer._parse_number(frac)
        if "/" in s:
            a, b = s.split("/", 1)
            return float(a) / float(b)
        return float(s)

    @staticmethod
    def _clean_name(name: str) -> str:
        name = name.lower().strip()
        name = re.sub(r"[*]+$", "", name).strip()
        name = re.sub(
            r"^(fresh|dried|ground|minced|chopped|sliced|diced|optional|boneless|skinless|bone-in|large|medium|small)\s+",
            "",
            name,
        )
        name = re.sub(r"\s+", " ", name).strip(" .,-")

        # Grocery-friendly protein collapses (matches iOS IngredientCanonicalizer).
        if "turkey" in name and ("breast" in name or "cutlet" in name):
            return "turkey breast"
        if "chicken" in name:
            if "thigh" in name:
                return "chicken thigh"
            if "drumstick" in name or re.search(r"\bleg\b", name):
                return "chicken drumstick"
            if "wing" in name:
                return "chicken wing"
            if "breast" in name or "tender" in name or "cutlet" in name:
                return "chicken breast"
            if "piece" in name or "parts" in name:
                return "chicken breast"
            if "whole" in name:
                return "whole chicken"

        # Light singularization for common plurals
        if name.endswith("oes"):
            name = name[:-2]
        elif name.endswith("ies"):
            name = name[:-3] + "y"
        elif name.endswith("s") and not name.endswith("ss") and " " not in name:
            name = name[:-1]
        elif name.endswith(" breasts"):
            name = name[:-1]
        return name

    @staticmethod
    def _guess_category(name: str) -> str:
        n = name.lower()
        if any(w in n for w in FROZEN_WORDS):
            return "frozen"
        if any(w in n for w in PROTEIN_WORDS):
            return "protein"
        if any(w in n for w in DAIRY_WORDS):
            return "dairy"
        if any(w in n for w in SPICE_WORDS):
            return "spice"
        if any(w in n for w in PRODUCE_WORDS):
            return "produce"
        return "pantry"
