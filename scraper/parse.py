"""JSON-LD Recipe extraction and step cleanup."""

from __future__ import annotations

import json
import logging
import re
from dataclasses import dataclass, field
from html import unescape
from typing import Any, Iterable, Optional

from bs4 import BeautifulSoup

log = logging.getLogger(__name__)

BOILERPLATE_PATTERNS = [
    re.compile(p, re.I)
    for p in [
        r"^watch how to make",
        r"^subscribe",
        r"^photograph by",
        r"^reprinted with permission",
        r"^nutrition\b",
        r"^click here",
        r"^save this recipe",
        r"^print\b",
        r"^rate this recipe",
        r"^leave a comment",
    ]
]


@dataclass
class ParsedRecipe:
    source_url: str
    title: str
    ingredients: list[str]
    steps: list[str]
    base_servings: int
    image_url: Optional[str] = None
    tags: list[str] = field(default_factory=list)
    equipment: list[str] = field(default_factory=list)
    protein_g_per_serving: Optional[float] = None
    calories_per_serving: Optional[float] = None


# Canonical kitchen tools we store + filter on in the iOS app.
EQUIPMENT_PATTERNS: list[tuple[str, re.Pattern[str]]] = [
    ("air_fryer", re.compile(r"\bair[\s-]?fryer\b", re.I)),
    ("instant_pot", re.compile(r"\b(instant[\s-]?pot|pressure cooker)\b", re.I)),
    ("slow_cooker", re.compile(r"\b(slow cooker|crock[\s-]?pot)\b", re.I)),
    ("grill", re.compile(r"\b(grill|grill pan|barbecue|bbq)\b", re.I)),
    ("blender", re.compile(r"\b(blender|immersion blender|hand blender)\b", re.I)),
    ("food_processor", re.compile(r"\bfood processor\b", re.I)),
    ("stand_mixer", re.compile(r"\b(stand mixer|kitchenaid)\b", re.I)),
    ("sous_vide", re.compile(r"\bsous[\s-]?vide\b", re.I)),
    ("microwave", re.compile(r"\bmicrowave\b", re.I)),
    ("oven", re.compile(r"\b(oven|bake|roast|broil|preheat)\b", re.I)),
    ("stove", re.compile(r"\b(stove|stovetop|saucepan|skillet|saute|sauté|simmer|boil|fry pan|frying pan|dutch oven)\b", re.I)),
]


def infer_equipment(obj: dict, steps: list[str], tags: list[str]) -> list[str]:
    """Pull schema.org tool when present; otherwise infer from steps/tags."""
    found: list[str] = []
    for item in _as_list(obj.get("tool")):
        name = ""
        if isinstance(item, str):
            name = item
        elif isinstance(item, dict):
            name = str(item.get("name") or item.get("text") or "")
        blob = name.lower()
        for key, pat in EQUIPMENT_PATTERNS:
            if pat.search(blob) and key not in found:
                found.append(key)

    corpus = " ".join(steps + tags + [str(obj.get("name") or "")])
    for key, pat in EQUIPMENT_PATTERNS:
        if key not in found and pat.search(corpus):
            found.append(key)

    # Decision: every cooked recipe is assumed usable with stove and/or oven basics
    # unless it ONLY mentions a specialty appliance. Always include stove as baseline
    # when any cooking verb appears and nothing else matched.
    if not found:
        found = ["stove", "oven"]
    return found


def _strip_html(text: str) -> str:
    if "<" in text and ">" in text:
        soup = BeautifulSoup(text, "lxml")
        text = soup.get_text(" ", strip=True)
    return unescape(re.sub(r"\s+", " ", text)).strip()


def _as_list(value: Any) -> list[Any]:
    if value is None:
        return []
    if isinstance(value, list):
        return value
    return [value]


def _walk_jsonld(node: Any) -> Iterable[dict]:
    if isinstance(node, dict):
        yield node
        for key in ("@graph", "mainEntity"):
            if key in node:
                yield from _walk_jsonld(node[key])
    elif isinstance(node, list):
        for item in node:
            yield from _walk_jsonld(item)


def _types_of(obj: dict) -> set[str]:
    t = obj.get("@type")
    if isinstance(t, list):
        return {str(x) for x in t}
    if t:
        return {str(t)}
    return set()


def extract_jsonld_blocks(html: str) -> list[Any]:
    soup = BeautifulSoup(html, "lxml")
    blocks: list[Any] = []
    for tag in soup.find_all("script", attrs={"type": "application/ld+json"}):
        raw = tag.string or tag.get_text() or ""
        raw = raw.strip()
        if not raw:
            continue
        try:
            blocks.append(json.loads(raw))
        except json.JSONDecodeError:
            # Some sites emit trailing commas / multiple objects; try a light fix.
            try:
                cleaned = re.sub(r",\s*}", "}", raw)
                cleaned = re.sub(r",\s*]", "]", cleaned)
                blocks.append(json.loads(cleaned))
            except json.JSONDecodeError:
                log.debug("Skipping invalid JSON-LD block")
    return blocks


def find_recipe_objects(html: str) -> list[dict]:
    recipes: list[dict] = []
    for block in extract_jsonld_blocks(html):
        for obj in _walk_jsonld(block):
            types = _types_of(obj)
            if "Recipe" in types:
                recipes.append(obj)
    return recipes


def _parse_servings(yield_val: Any) -> int:
    if yield_val is None:
        return 4  # Decision: default batch size when yield missing
    if isinstance(yield_val, (int, float)):
        return max(1, int(yield_val))
    text = " ".join(str(x) for x in _as_list(yield_val))
    nums = re.findall(r"\d+", text)
    if nums:
        return max(1, int(nums[0]))
    return 4


def _parse_instructions(raw: Any) -> list[str]:
    steps: list[str] = []

    def add_text(t: str) -> None:
        t = _strip_html(t)
        if not t:
            return
        if any(p.search(t) for p in BOILERPLATE_PATTERNS):
            return
        # Drop very short non-instruction crumbs
        if len(t) < 3:
            return
        steps.append(t)

    for item in _as_list(raw):
        if isinstance(item, str):
            add_text(item)
        elif isinstance(item, dict):
            types = _types_of(item)
            if "HowToSection" in types:
                for sub in _as_list(item.get("itemListElement")):
                    if isinstance(sub, dict):
                        add_text(str(sub.get("text") or sub.get("name") or ""))
                    else:
                        add_text(str(sub))
            elif "HowToStep" in types or "text" in item or "name" in item:
                add_text(str(item.get("text") or item.get("name") or ""))
            else:
                add_text(str(item.get("text") or item.get("name") or ""))
    return steps


def _parse_image(raw: Any) -> Optional[str]:
    for item in _as_list(raw):
        if isinstance(item, str) and item.startswith("http"):
            return item
        if isinstance(item, dict):
            url = item.get("url") or item.get("@id")
            if isinstance(url, str) and url.startswith("http"):
                return url
    return None


def _parse_tags(obj: dict) -> list[str]:
    tags: list[str] = []
    for key in ("keywords", "recipeCategory", "recipeCuisine", "recipeIngredient"):
        if key == "recipeIngredient":
            continue
        val = obj.get(key)
        if isinstance(val, str):
            parts = re.split(r"[,|/]", val)
            tags.extend(p.strip().lower() for p in parts if p.strip())
        elif isinstance(val, list):
            for v in val:
                if isinstance(v, str) and v.strip():
                    tags.append(v.strip().lower())
    # Deduplicate preserving order
    seen: set[str] = set()
    out: list[str] = []
    for t in tags:
        if t not in seen and len(t) < 40:
            seen.add(t)
            out.append(t)
    return out[:12]


def _parse_nutrition(obj: dict) -> tuple[Optional[float], Optional[float]]:
    nut = obj.get("nutrition")
    if isinstance(nut, list) and nut:
        nut = nut[0]
    if not isinstance(nut, dict):
        return None, None

    def num(key: str) -> Optional[float]:
        val = nut.get(key)
        if val is None:
            return None
        m = re.search(r"[\d.]+", str(val))
        return float(m.group()) if m else None

    calories = num("calories")
    protein = num("proteinContent")
    return protein, calories


def parse_recipe_from_html(url: str, html: str) -> Optional[ParsedRecipe]:
    recipes = find_recipe_objects(html)
    if not recipes:
        return None

    obj = recipes[0]
    title = _strip_html(str(obj.get("name") or "")).strip()
    ingredients = [
        _strip_html(str(x))
        for x in _as_list(obj.get("recipeIngredient"))
        if str(x).strip()
    ]
    # Strip Budget Bytes-style trailing price annotations: " ($0.40)"
    ingredients = [re.sub(r"\s*\(\$[^)]*\)\s*$", "", ing).strip() for ing in ingredients]
    # Strip footnote asterisks Food Network sometimes leaves on lines
    ingredients = [re.sub(r"[*]+$", "", ing).strip() for ing in ingredients]
    ingredients = [ing for ing in ingredients if ing]
    steps = _parse_instructions(obj.get("recipeInstructions"))

    if not title or not ingredients or not steps:
        log.info("Skip incomplete recipe at %s (title=%s ings=%d steps=%d)", url, bool(title), len(ingredients), len(steps))
        return None

    tags = _parse_tags(obj)
    protein, calories = _parse_nutrition(obj)
    equipment = infer_equipment(obj, steps, tags)
    return ParsedRecipe(
        source_url=url,
        title=title,
        ingredients=ingredients,
        steps=steps,
        base_servings=_parse_servings(obj.get("recipeYield")),
        image_url=_parse_image(obj.get("image")),
        tags=tags,
        equipment=equipment,
        protein_g_per_serving=protein,
        calories_per_serving=calories,
    )
