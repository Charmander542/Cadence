from __future__ import annotations

import re
from dataclasses import asdict, dataclass, field
from typing import Any

# Canonical cooking units we keep in the store.
CANONICAL_UNITS = {
    "tsp",
    "tbsp",
    "cup",
    "floz",
    "oz",
    "lb",
    "g",
    "kg",
    "ml",
    "l",
    "each",
    "clove",
    "slice",
    "can",
    "bunch",
    "stick",
    "head",
    "ear",
    "sprig",
    "leaf",
    "package",
}

# Vague amounts → approximate tsp (or to_taste when paired with seasonings).
VAGUE_TO_TSP = {
    "smidge": 1 / 16,
    "smidgen": 1 / 16,
    "pinch": 1 / 16,
    "pinches": 1 / 16,
    "dash": 1 / 8,
    "dashes": 1 / 8,
    "drop": 1 / 32,
    "drops": 1 / 32,
    "speck": 1 / 32,
    "touch": 1 / 16,
    "hint": 1 / 16,
}

UNIT_ALIASES: dict[str, str] = {
    "tsp": "tsp",
    "teaspoon": "tsp",
    "teaspoons": "tsp",
    "t": "tsp",
    "tsp.": "tsp",
    "tsps": "tsp",
    "tbsp": "tbsp",
    "tablespoon": "tbsp",
    "tablespoons": "tbsp",
    "tbsp.": "tbsp",
    "tbsps": "tbsp",
    "tbs": "tbsp",
    "T": "tbsp",
    "cup": "cup",
    "cups": "cup",
    "c": "cup",
    "c.": "cup",
    "oz": "oz",
    "ounce": "oz",
    "ounces": "oz",
    "oz.": "oz",
    "ozs": "oz",
    "floz": "floz",
    "fluid ounce": "floz",
    "fluid ounces": "floz",
    "fl oz": "floz",
    "fl. oz": "floz",
    "fl. oz.": "floz",
    "lb": "lb",
    "pound": "lb",
    "pounds": "lb",
    "lb.": "lb",
    "lbs": "lb",
    "lbs.": "lb",
    "g": "g",
    "gram": "g",
    "grams": "g",
    "g.": "g",
    "kg": "kg",
    "kilogram": "kg",
    "kilograms": "kg",
    "kg.": "kg",
    "ml": "ml",
    "milliliter": "ml",
    "milliliters": "ml",
    "millilitre": "ml",
    "millilitres": "ml",
    "ml.": "ml",
    "l": "l",
    "liter": "l",
    "liters": "l",
    "litre": "l",
    "litres": "l",
    "l.": "l",
    "clove": "clove",
    "cloves": "clove",
    "slice": "slice",
    "slices": "slice",
    "can": "can",
    "cans": "can",
    "bunch": "bunch",
    "bunches": "bunch",
    "stick": "stick",
    "sticks": "stick",
    "head": "head",
    "heads": "head",
    "ear": "ear",
    "ears": "ear",
    "sprig": "sprig",
    "sprigs": "sprig",
    "leaf": "leaf",
    "leaves": "leaf",
    "package": "package",
    "packages": "package",
    "pkg": "package",
    "pkt": "package",
    "handful": "each",
    "handfuls": "each",
    "large handful": "each",
    "big handful": "each",
}

# Countable foods often written without a unit ("2 eggs", "1 onion").
COUNTABLE_ITEMS = {
    "egg",
    "eggs",
    "onion",
    "onions",
    "shallot",
    "shallots",
    "lemon",
    "lemons",
    "lime",
    "limes",
    "orange",
    "oranges",
    "apple",
    "apples",
    "banana",
    "bananas",
    "avocado",
    "avocados",
    "tomato",
    "tomatoes",
    "potato",
    "potatoes",
    "carrot",
    "carrots",
    "stalk",
    "stalks",
    "rib",
    "ribs",
    "bay leaf",
    "bay leaves",
    "garlic clove",
    "garlic cloves",
}

ITEM_ALIASES: dict[str, str] = {
    "eggs": "egg",
    "egg yolks": "egg yolk",
    "egg yolk": "egg yolk",
    "egg whites": "egg white",
    "egg white": "egg white",
    "onions": "onion",
    "yellow onion": "onion",
    "yellow onions": "onion",
    "white onion": "onion",
    "red onion": "red onion",
    "green onions": "scallion",
    "green onion": "scallion",
    "scallions": "scallion",
    "spring onions": "scallion",
    "kosher salt": "salt",
    "sea salt": "salt",
    "table salt": "salt",
    "fine salt": "salt",
    "unsalted butter": "butter",
    "salted butter": "butter",
    "sweet butter": "butter",
    "extra-virgin olive oil": "olive oil",
    "extra virgin olive oil": "olive oil",
    "evoo": "olive oil",
    "all-purpose flour": "flour",
    "all purpose flour": "flour",
    "ap flour": "flour",
    "granulated sugar": "sugar",
    "white sugar": "sugar",
    "black pepper": "pepper",
    "freshly ground black pepper": "pepper",
    "freshly ground pepper": "pepper",
    "ground black pepper": "pepper",
    "garlic cloves": "garlic",
    "garlic clove": "garlic",
    "cloves garlic": "garlic",
    "clove garlic": "garlic",
    "minced garlic": "garlic",
}

SEASONING_ITEMS = {
    "salt",
    "pepper",
    "black pepper",
    "cayenne",
    "paprika",
    "cinnamon",
    "nutmeg",
    "cumin",
    "oregano",
    "thyme",
    "rosemary",
    "chili flakes",
    "red pepper flakes",
}

PREP_WORDS = {
    "chopped",
    "diced",
    "minced",
    "sliced",
    "grated",
    "shredded",
    "melted",
    "softened",
    "room temperature",
    "divided",
    "drained",
    "rinsed",
    "peeled",
    "seeded",
    "trimmed",
    "crushed",
    "beaten",
    "whisked",
    "toasted",
    "cooked",
    "fresh",
    "dried",
    "frozen",
    "thawed",
    "whole",
    "halved",
    "quartered",
    "thinly",
    "finely",
    "roughly",
    "coarsely",
    "lightly",
    "packed",
    "firmly",
    "loosely",
    "heaping",
    "scant",
    "rounded",
    "boneless",
    "skinless",
    "bone-in",
    "skin-on",
}

# Color/size leftovers from "green or red cabbage" — not foods on their own.
COLOR_WORDS = {
    "green",
    "red",
    "white",
    "black",
    "yellow",
    "brown",
    "purple",
    "pink",
    "gold",
    "golden",
    "dark",
    "light",
}

CONTAINER_WORDS = {
    "head",
    "heads",
    "bunch",
    "bunches",
    "bag",
    "bags",
    "can",
    "cans",
}

GROUND_MEAT_RE = re.compile(
    r"^ground\s+(meat|beef|pork|turkey|chicken|lamb|veal)\b",
    re.I,
)

# Size words are kept out of prep noise for display ("2 large eggs" → "2 egg").
SIZE_WORDS = {"large", "medium", "small", "extra-large", "jumbo"}

FRACTIONS = {
    "¼": 0.25,
    "½": 0.5,
    "¾": 0.75,
    "⅓": 1 / 3,
    "⅔": 2 / 3,
    "⅛": 0.125,
    "⅜": 0.375,
    "⅝": 0.625,
    "⅞": 0.875,
    "⅕": 0.2,
    "⅖": 0.4,
    "⅗": 0.6,
    "⅘": 0.8,
    "⅙": 1 / 6,
    "⅚": 5 / 6,
}


@dataclass
class ParsedIngredient:
    """Structured ingredient line for search, nutrition, and LLM prompts."""

    raw: str
    quantity: float | None = None
    unit: str | None = None
    item: str = ""
    prep: str = ""
    to_taste: bool = False
    optional: bool = False
    allergens: list[str] = field(default_factory=list)
    notes: str = ""

    def display(self) -> str:
        """Human-useful form like '2 tbsp butter' or '1 onion'."""
        if self.to_taste and self.quantity is None:
            base = self.item or self.raw
            return f"{base} to taste".strip()
        parts: list[str] = []
        if self.quantity is not None:
            parts.append(_format_qty(self.quantity))
        if self.unit and self.unit != "each":
            parts.append(self.unit)
        if self.item:
            parts.append(self.item)
        elif self.raw:
            parts.append(self.raw)
        text = " ".join(parts).strip()
        if self.prep:
            text = f"{text}, {self.prep}"
        if self.to_taste and self.quantity is not None:
            text = f"{text} (to taste)"
        return text

    def scaled(self, factor: float) -> ParsedIngredient:
        """Return a copy with quantity multiplied. To-taste lines without a qty stay put."""
        qty = self.quantity
        if qty is not None and factor != 1:
            qty = qty * factor
        return ParsedIngredient(
            raw=self.raw,
            quantity=qty,
            unit=self.unit,
            item=self.item,
            prep=self.prep,
            to_taste=self.to_taste,
            optional=self.optional,
            allergens=list(self.allergens),
            notes=self.notes,
        )

    def to_dict(self) -> dict[str, Any]:
        data = asdict(self)
        data["display"] = self.display()
        return data

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> ParsedIngredient:
        return cls(
            raw=data.get("raw", "") or "",
            quantity=data.get("quantity"),
            unit=data.get("unit"),
            item=data.get("item", "") or "",
            prep=data.get("prep", "") or "",
            to_taste=bool(data.get("to_taste")),
            optional=bool(data.get("optional")),
            allergens=list(data.get("allergens") or []),
            notes=data.get("notes", "") or "",
        )


def clean_ingredient_line(line: str) -> str | None:
    """Normalize one ingredient line for re-parse, or None to drop it."""
    raw = _clean(line)
    if not raw:
        return None
    # Bracket section markers from scraped books ("[INGREDIENTS]", "[For the Marinade]").
    if re.match(r"^\[.+\]$", raw):
        return None
    # Truncated OCR stubs that are useless alone ("whole-", "sushi-", "pumpkin-").
    if re.match(r"^[A-Za-z]{2,12}[-–—]$", raw):
        return None
    # Yield footnotes mis-filed as ingredients.
    if re.search(r"\byields?\b", raw, re.I):
        return None
    # Instruction / variation prose mis-filed as an ingredient line.
    if re.match(
        r"^(add |substitute |optional:\s*for |if you (don.?t|do not)|the following options|"
        r"up to \d+ cups of any|cooked and drained breakfast|garlic-braised|"
        r"optional additional toppings|optional aromatic ingredients|"
        r"optional\)\s*alcohol|about ½ teaspoon salt and|other common seasonings)\b",
        raw,
        re.I,
    ):
        return None
    # Multi-component lines jammed into one ("For the bites 12 slices… 2 tbsp…")
    if re.match(r"^for the \w+", raw, re.I):
        qty_hits = len(re.findall(r"\b\d+\s*(?:g|ml|tbsp|tsp|cup|oz|slices?|liter)\b", raw, re.I))
        if qty_hits >= 2:
            return None
    # Cross-recipe pointers / serving hints masquerading as ingredients.
    if re.search(r"\b(recipe follows|hint\s*:|dressed with some of the|added to each piece|"
                 r"added to the broth|scattered on top)\b", raw, re.I):
        if re.search(r"\bvinaigrette\b", raw, re.I):
            return "1/2 cup vinaigrette"
        if re.search(r"\bedamame\b", raw, re.I):
            return "1/2 cup edamame"
        if re.search(r"\bwasabi\b", raw, re.I):
            return "wasabi"
        if re.search(r"\bmiso\b", raw, re.I):
            return None
        return None
    # Metric-first amounts: "1 kilogram (about 2 pounds…) pork shoulder"
    kg = re.match(
        r"^([\d./¼½¾]+)\s*(?:kilograms?|kg)\b(?:\s*\([^)]*\))?\s*(.+)$",
        raw,
        flags=re.I,
    )
    if kg:
        food = re.split(r",\s*(?:cut|trimmed|cubed)\b", kg.group(2), maxsplit=1, flags=re.I)[0]
        food = re.sub(r"\s*\([^)]*\)", "", food)
        return f"{kg.group(1)} kg {food.strip(' ,;')}"
    # "2 cups (or one box) Biscuit Mix"
    box = re.match(
        r"^([\d./¼½¾]+)\s*cups?\s*\([^)]*box[^)]*\)\s*(.+)$",
        raw,
        flags=re.I,
    )
    if box:
        return f"{box.group(1)} cups {box.group(2).strip()}"
    # "Zest of 1 lemon removed…"
    if re.match(r"^zest of\b", raw, re.I):
        if "lemon" in raw.casefold():
            return "zest of 1 lemon"
        if "lime" in raw.casefold():
            return "zest of 1 lime"
        if "orange" in raw.casefold():
            return "zest of 1 orange"
    # "X using Dutch-process instead of…" — reference to another recipe.
    if re.search(r"\busing dutch-process instead\b", raw, re.I):
        return None
    # "N tablespoons (½ stick or 55g) unsalted butter…"
    tbsp_butter = re.match(
        r"^([\d¼½¾⅓⅔./]+)\s*(tablespoons?|tbsp)\s*\([^)]*\)\s*(.+butter.*)$",
        raw,
        flags=re.I,
    )
    if tbsp_butter:
        food = re.split(r",\s*(?:melted|browned|softened|at room)\b", tbsp_butter.group(3), maxsplit=1, flags=re.I)[0]
        return f"{tbsp_butter.group(1)} tablespoons {food.strip(' ,;')}"
    # "(1 stick plus 1 tablespoon) unsalted butter"
    if re.search(r"\bstick\b", raw, re.I) and re.search(r"\bbutter\b", raw, re.I):
        stick_m = re.search(r"([\d¼½¾⅓⅔./]+)\s*tablespoons?", raw, re.I)
        if stick_m:
            return f"{stick_m.group(1)} tablespoons butter"
        return "8 tablespoons butter"
    if re.match(r"^optional:\s", raw, re.I) and not re.search(
        r"^optional:\s*[\d¼½¾⅓⅔⅛./]+\s*(?:cup|tbsp|tsp|oz|lb|g|ml|tablespoon|teaspoon|ounce|pound)",
        raw,
        re.I,
    ):
        # "Optional: For a touch of smokiness…" essays — not shoppable.
        if len(raw) > 40 and not re.match(r"^optional:\s*[\d¼½¾]", raw, re.I):
            return None
    # Depth-of-oil frying shorthand → buyable oil amount.
    if re.search(r"\binch(?:es)?\b", raw, re.I) and re.search(r"\boil\b", raw, re.I):
        return "2 cups vegetable oil (for frying)"
    # Strip cross-ref pointers but keep the food when possible.
    raw = re.sub(r"\s*\(see here[^)]*\)", "", raw, flags=re.I)
    raw = re.sub(r"\s*\(see below[^)]*\)", "", raw, flags=re.I)
    raw = re.sub(r"\s*\(see notes?[^)]*\)", "", raw, flags=re.I)
    raw = re.sub(r"\s*see here(?:\s*[–—-]\s*here)?\s*", " ", raw, flags=re.I)
    raw = re.sub(r"\s*see below\b", " ", raw, flags=re.I)
    raw = re.sub(r",?\s*brined or dry-brined if desired\b", "", raw, flags=re.I)
    raw = re.sub(r",?\s*if desired\b", "", raw, flags=re.I)
    raw = re.sub(r",?\s*as desired\b", "", raw, flags=re.I)
    raw = re.sub(r",?\s*scrubbed(?: and peeled)?\b", "", raw, flags=re.I)
    raw = re.sub(r",?\s*peeled(?: and (?:scrubbed|seeded|cored))?\b", "", raw, flags=re.I)
    # Dual metric "(340 g)" / "(15 ml)" — strip so qty stays imperial and item is food-only.
    raw = re.sub(
        r"\s*\(\s*[\d./¼½¾⅓⅔]+\s*(?:to\s*[\d./¼½¾⅓⅔]+\s*)?(?:g|kg|ml|l|oz|ounces?)\s*"
        r"(?:/\s*about\s+[\d./¼½¾⅓⅔]+\s*(?:ounces?|oz|g|kg|ml))?\)",
        "",
        raw,
        flags=re.I,
    )
    raw = re.sub(
        r"\s*\(\s*about\s+[\d./¼½¾⅓⅔]+\s*(?:g|kg|ml|l|oz|ounces?)\s*"
        r"(?:/\s*[\d./¼½¾⅓⅔]+\s*(?:g|kg|ml|oz|ounces?))?\)",
        "",
        raw,
        flags=re.I,
    )
    raw = re.sub(
        r"\s*\(\s*[\d./¼½¾⅓⅔]+\s*g\s*/\s*about\s+[\d./¼½¾⅓⅔]+\s*ounces?\)",
        "",
        raw,
        flags=re.I,
    )
    # "short- or medium-grain" → keep full grain phrase
    raw = re.sub(
        r"\bshort-?\s*or\s*medium-grain\b",
        "short-grain or medium-grain",
        raw,
        flags=re.I,
    )
    # Common truncated compounds before "or" split.
    raw = re.sub(
        r"\bmild lemon-?\s*or\s*red wine[–—-]olive oil vinaigrette\b",
        "vinaigrette",
        raw,
        flags=re.I,
    )
    raw = re.sub(r"\bsoft-?\s*or\s*medium-boiled eggs?\b", "eggs", raw, flags=re.I)
    raw = re.sub(r"\bvegetable-?\s*or\s*tom yam-?quick noodles\b", "noodles", raw, flags=re.I)
    # "4 to 8 tablespoons butter" ranges → mid-range amount.
    range_tbsp = re.match(
        r"^([\d¼½¾⅓⅔./]+)\s*to\s+([\d¼½¾⅓⅔./]+)\s*(tablespoons?|tbsp)\b(.+)$",
        raw,
        flags=re.I,
    )
    if range_tbsp:
        lo = _parse_number(range_tbsp.group(1))
        hi = _parse_number(range_tbsp.group(2))
        mid = (lo + hi) / 2.0 if lo is not None and hi is not None else lo or hi
        rest = range_tbsp.group(4).strip()
        # Prefer butter over "or oil" alternatives in muffin-style lines.
        if re.search(r"\bbutter\b", rest, re.I):
            rest = re.sub(r"\s*\([^)]*\)", "", rest)
            rest = re.split(r",\s*or\b|\s+or\s+(?=\d|¼|½|¾)", rest, maxsplit=1, flags=re.I)[0]
            rest = rest.strip(" ,;")
            if rest:
                return f"{_format_qty(mid)} tablespoons {rest}"
            return f"{_format_qty(mid)} tablespoons butter"
    # Pineapple can juice/chunks.
    if re.search(r"\bpineapple\b", raw, re.I) and re.search(r"\b(juice|chunks)\b", raw, re.I):
        if re.search(r"\bjuice\b", raw, re.I):
            return "1 cup pineapple juice"
        return "1 can pineapple chunks"
    raw = re.sub(r"\s+", " ", raw).strip(" ,;")
    # "3 cups plus 2 tablespoons cold water" → single water line.
    plus = re.match(
        r"^([\d¼½¾⅓⅔./\s]+)\s*cups?\s+plus\s+([\d¼½¾⅓⅔./\s]+)\s*(?:tablespoons?|tbsp)\s+(.+)$",
        raw,
        flags=re.I,
    )
    if plus:
        whole = _parse_number(plus.group(1).strip())
        tbsp = _parse_number(plus.group(2).strip())
        food = plus.group(3).strip()
        food = re.sub(r"^(cold|hot|warm|room[- ]temperature)\s+", "", food, flags=re.I)
        return f"{_format_qty(whole + tbsp / 16.0)} cups {food}"
    # Flour lines with serving-style alternatives.
    if re.search(r"\bflour\b", raw, re.I) and re.search(r"\b(for serving|potpie|casserole|pasta|toast)\b", raw, re.I):
        m = re.match(
            r"^([\d¼½¾⅓⅔⅛./\s]+)\s*(cups?|cup|tbsp|tablespoons?|tsp|teaspoons?)?\s*(?:all-?purpose\s+)?flour\b",
            raw,
            flags=re.I,
        )
        if m:
            qty = (m.group(1) or "").strip()
            unit = (m.group(2) or "cup").strip()
            return f"{qty} {unit} all-purpose flour".strip()
    # Pure multi-recipe sauce/marinade choosers aren't a single shoppable line.
    if re.search(r"\b(marinade|pan sauce|glaze|vinaigrette)\b", raw, re.I):
        if re.search(r"\bor\b", raw, re.I) and raw.count(",") >= 1:
            return None
    # Bare section headers without a food on the same line.
    if re.match(r"^(for the |to serve|to make)\b", raw, re.I):
        # "For the bites 12 slices…" — keep (has food). Pure "For the bechamel" — drop.
        rest = re.sub(r"^(for the |to serve|to make)\s*", "", raw, flags=re.I).strip()
        if not rest or len(rest) < 8:
            return None
        return raw
    if not raw:
        return None
    return raw


def polish_parsed(ing: ParsedIngredient) -> ParsedIngredient | None:
    """Post-parse cleanup for shop/display friendliness."""
    if not ing.item and not ing.raw:
        return None
    item = ing.item
    # Drop residual hedges from the item field.
    item = re.sub(r"\bif desired\b", "", item, flags=re.I)
    item = re.sub(r"\bas desired\b", "", item, flags=re.I)
    item = re.sub(r"\bscrubbed\b", "", item, flags=re.I)
    item = re.sub(r"\bpeeled\b", "", item, flags=re.I)
    item = re.sub(r"\bsee (?:here|below|notes?)\b.*$", "", item, flags=re.I)
    # Leading dual-unit residue the qty parser left behind: "(340 g) chinese broccoli"
    item = re.sub(
        r"^\(\s*[\d./¼½¾⅓⅔]+\s*(?:to\s*[\d./¼½¾⅓⅔]+\s*)?(?:g|kg|ml|l|oz|ounces?)\s*\)\s*",
        "",
        item,
        flags=re.I,
    )
    item = re.sub(
        r"^\(\s*about\s+[\d./¼½¾⅓⅔]+\s*(?:g|kg|ml|l|oz|ounces?|cups?|/[^)]+)\s*\)\s*",
        "",
        item,
        flags=re.I,
    )
    # Trailing / broken dual-unit notes: "(about 5 teaspoons/15 g" or "about 2½ ounces)"
    item = re.sub(
        r"\s*\(\s*about\s+[\d./¼½¾⅓⅔]+\s*(?:teaspoons?|tablespoons?|tsp|tbsp|cups?|ounces?|oz|"
        r"g|kg|ml)?(?:\s*/\s*[\d./¼½¾⅓⅔]+\s*(?:g|kg|ml|oz|ounces?))?\s*\)?\s*$",
        "",
        item,
        flags=re.I,
    )
    item = re.sub(r"\s*\(\s*about\s+[\d./¼½¾⅓⅔]+\s*(?:g|kg|/[^)]*)\s*$", "", item, flags=re.I)
    # Prep glued with "and": "carrot and grated…", "shrimp and cut into…"
    item = re.split(
        r"\s+and\s+(?:cut|grated|minced|sliced|diced|chopped|washed|drained|trimmed|"
        r"lightly|roughly|finely|halved|quartered|reserved|added|prepped|broken)\b",
        item,
        maxsplit=1,
        flags=re.I,
    )[0]
    # Essay / brand blurb leftovers.
    if re.search(r"\b(is a dried|originating from|use no more than|i.?ve found that|"
                 r"should never have seen|works best\.|go-to alternative|"
                 r"preferably japanese bulldog|poly-o|pre-shredded)\b", item, re.I):
        item = re.split(r"[.;:]|i.?ve found", item, maxsplit=1, flags=re.I)[0]
        item = re.sub(r"\s*\([^)]*(poly-o|bulldog)[^)]*\)", "", item, flags=re.I)
    # "~8 oz shredded mozzarella …" with qty stuck in item
    m_oz = re.match(r"^~?\s*([\d./¼½¾]+)\s*oz\s+(.+)$", item, flags=re.I)
    if m_oz and ing.quantity is None:
        food = m_oz.group(2).strip()
        food = re.split(r"\bi.?ve found\b", food, maxsplit=1, flags=re.I)[0].strip(" ,;")
        return ParsedIngredient(
            raw=ing.raw,
            quantity=_parse_number(m_oz.group(1)),
            unit="oz",
            item=_canonicalize_item(food) or food.casefold(),
            prep="",
            to_taste=False,
            optional=ing.optional,
            allergens=infer_allergens(food, ing.raw),
            notes=ing.notes,
        )
    # Hummus-style: "cup … of lemon juice"
    if re.search(r"\blemon juice\b", item, re.I):
        item = "lemon juice"
    if re.search(r"\bwhole-grain\b", item, re.I) and re.search(r"\bmustard\b", ing.raw, re.I):
        item = "mustard"
    if item in {"soft-boiled", "soft boiled"} and re.search(r"\begg", ing.raw, re.I):
        item = "egg"
    if re.search(r"\bmozzarella\b", item, re.I):
        item = "mozzarella"
    item = re.sub(r"\s+", " ", item).strip(" ,;.")
    # Truncated hyphen compounds ("mild lemon-", "soft-", "8-") are not foods.
    if item.endswith("-") or item.endswith("–") or re.match(r"^[a-z]{2,12}-$", item):
        return None
    # Common protein shortcuts.
    if re.search(r"\bchicken breast", item, re.I):
        item = "chicken breast"
    elif re.search(r"\bchicken thigh", item, re.I):
        item = "chicken thigh"
    elif re.search(r"\bpork tenderloin", item, re.I):
        item = "pork tenderloin"
    elif re.search(r"\bflank steak", item, re.I):
        item = "flank steak"
    elif re.search(r"\bsweet potato", item, re.I):
        item = "sweet potato"
    elif re.search(r"\bbaking potato|\brusset", item, re.I):
        item = "potato"
    elif re.search(r"\bsushi rice|short-?grain|medium-?grain", item, re.I):
        item = "sushi rice"
    elif item.startswith("japanese short"):
        item = "sushi rice"
    elif re.search(r"\bpuff pastry|ready-rolled.*pastry", item, re.I):
        item = "puff pastry"
    elif re.search(r"\ball-purpose flour|\bunbleached all-purpose flour", item, re.I):
        item = "flour"
    elif re.search(r"\braisin(?:s)?\b", item, re.I) and len(item) > 20:
        item = "raisins"
    elif re.search(r"\bcashew", item, re.I):
        item = "cashews"
    elif re.search(r"\borange zest\b", item, re.I):
        item = "orange zest"
    elif re.search(r"\blime zest\b", item, re.I):
        item = "lime zest"
    elif re.search(r"\blemon zest\b", item, re.I) or re.match(r"^zest of\b", item, re.I):
        item = "lemon zest"
    elif re.search(r"\bwhipped cream\b", item, re.I):
        item = "whipped cream"
    elif re.match(r"^(sweet )?onions?\b", item, re.I):
        item = "onion"
    elif re.search(r"\bkale\b|\bspinach\b|\bgreens such as\b", item, re.I) and len(item) > 30:
        item = "greens"
    elif re.search(r"\bedamame\b", item, re.I):
        item = "edamame"
    elif re.search(r"\bpork shoulder\b", item, re.I):
        item = "pork shoulder"
    elif re.search(r"\bbiscuit mix\b|cheddar bay\b", item, re.I):
        item = "biscuit mix"
    elif re.search(r"\bvinaigrette\b", item, re.I):
        item = "vinaigrette"
    elif re.search(r"\bjalape", item, re.I):
        item = "jalapeño"
    elif re.search(r"\bcilantro\b", item, re.I) and len(item) > 20:
        item = "cilantro"
    elif re.search(r"\bbell pepper", item, re.I):
        item = "bell pepper"
    elif re.search(r"\bturnip", item, re.I):
        item = "turnip"
    elif re.search(r"\bcherry\b", item, re.I) and re.search(r"\b(spread|jam|preserve)", item, re.I):
        item = "cherry jam"
    elif re.search(r"\bice cream\b", item, re.I):
        item = "ice cream"
    elif re.search(r"\bmiso\b", item, re.I) and ("dip" in item or "here" in item):
        return None  # cross-recipe garnish
    elif re.search(r"\bchile paste\b|\bchili paste\b", item, re.I):
        item = "chile paste"
    elif re.search(r"\bcream cheese\b", item, re.I):
        item = "cream cheese"
    elif re.search(r"\byogurt\b|\byoghurt\b", item, re.I):
        item = "yogurt"
    elif re.search(r"\begg whites?\b", item, re.I):
        item = "egg white"
    elif re.search(r"\bcherries\b", item, re.I):
        item = "cherries"
    elif re.search(r"\bladyfinger|savoiardi\b", item, re.I):
        item = "ladyfingers"
    elif re.search(r"\bcream of chicken\b", item, re.I):
        item = "cream of chicken soup"
    elif re.search(r"\btopping for crispy chow mein\b|\brecipe .+ topping\b", item, re.I):
        return None
    elif re.search(r"\bfoie gras\b|\bpâté\b|\bpate\b", item, re.I):
        item = "pâté"
    elif re.search(r"\bmixed vegetables\b", item, re.I):
        item = "mixed vegetables"
    elif re.search(r"\bunsalted butter\b|\bbutter\b", item, re.I) and (
        len(item) > 20 or "stick" in item or "tablespoons" in item
    ):
        item = "butter"
    elif re.search(r"\bcheese\b", item, re.I) and re.search(r"\bi have made\b|~?\d+g of cheese", item, re.I):
        item = "cheese"
    elif re.search(r"\bstrawberr", item, re.I):
        item = "strawberries"
    elif re.search(r"\bmorsels\b|chocolate chips\b", item, re.I):
        item = "chocolate chips"
    elif re.search(r"\btomato.*juice\b|\bv8\b", item, re.I):
        item = "tomato juice"
    elif re.search(r"\bcoating of oil\b|more traditional\b", item, re.I):
        return None
    elif re.search(r"\btomato and chunky vegetable sauce\b|\bpasta sauce\b|sauce for pasta\b", item, re.I):
        item = "pasta sauce"
    elif re.match(r"^kilogram\b|^kg\b", item, re.I) is None and re.search(
        r"^\(about .+\)\s*pork", item, re.I
    ):
        item = "pork shoulder"
    elif re.search(r"\bfor every\b|\bgallon\b", item, re.I):
        # Ratio recipes ("coffee for every gallon") — keep a short food name.
        if "coffee" in item:
            item = "coffee"
        elif "tea" in item:
            item = "tea"
    elif "/" in item and item.count("/") >= 2:
        # Panini-style slash lists — take first food.
        item = item.split("/")[0].strip()
    # Cut absurdly long items at the first clear prep/cut clause.
    if len(item) > 40:
        cut = re.split(
            r",\s*(?:cut|peeled|trimmed|pounded|brined|chopped|diced|sliced|minced|"
            r"washed|drained|leaves|stems|florets|for serving|for a |plus |preferably |"
            r"such as |split |casing |rinsed |well drained|patted )\b",
            item,
            maxsplit=1,
            flags=re.I,
        )[0]
        item = cut.strip(" ,;")
    if re.search(r"\byields?\b", item, re.I):
        return None
    # Instruction-like items that slipped through.
    if re.match(
        r"^(add |substitute |optional|if you |the following |up to \d+ cups of any|"
        r"and drained|garlic-braised|about ½ teaspoon salt and)\b",
        item,
        re.I,
    ):
        return None
    # Broken "flour, pasta, or toast)" style leftovers from bad paren splits.
    if re.search(r"\bflour\b", item) and ("pasta" in item or "toast" in item or "potpie" in item):
        item = "flour"
    if "salt and white" in item or item in {"salt and white", "salt and black"}:
        item = "salt"
        return ParsedIngredient(
            raw=ing.raw,
            quantity=ing.quantity,
            unit=ing.unit,
            item=item,
            prep="",
            to_taste=True,
            optional=ing.optional,
            allergens=[],
            notes=ing.notes,
        )
    if not item or len(item) < 2:
        return None
    # Frying oil with bogus "inches" unit residue.
    if "oil" in item and ing.unit in {None, "each", "count"} and re.search(r"\binch", ing.raw, re.I):
        return ParsedIngredient(
            raw=ing.raw,
            quantity=2.0,
            unit="cup",
            item="vegetable oil",
            prep="for frying",
            to_taste=False,
            optional=ing.optional,
            allergens=list(ing.allergens),
            notes="frying_oil",
        )
    prep = re.sub(r"\bif desired\b|\bas desired\b|\bscrubbed\b|\bpeeled\b", "", ing.prep, flags=re.I)
    prep = re.sub(
        r"\(?\s*about\s+[\d./¼½¾⅓⅔]+\s*(?:teaspoons?|tablespoons?|tsp|tbsp|cups?|ounces?|oz|g|kg|ml)"
        r"(?:\s*/\s*[\d./¼½¾⅓⅔]+\s*(?:g|kg|ml|oz|ounces?))?\s*\)?",
        "",
        prep,
        flags=re.I,
    )
    prep = re.sub(r"\s+", " ", prep).strip(" ,;()")
    return ParsedIngredient(
        raw=ing.raw,
        quantity=ing.quantity,
        unit=ing.unit,
        item=item,
        prep=prep,
        to_taste=ing.to_taste,
        optional=ing.optional,
        allergens=infer_allergens(item, ing.raw),
        notes=ing.notes,
    )


def parse_ingredient(line: str) -> ParsedIngredient:
    """Parse one free-text ingredient line into qty / unit / item."""
    cleaned = clean_ingredient_line(line)
    if cleaned is None:
        return ParsedIngredient(raw=_clean(line), item="")
    raw = cleaned
    if not raw:
        return ParsedIngredient(raw=line, item="")

    optional = bool(re.search(r"\boptional\b", raw, re.I)) or raw.startswith("(")
    to_taste = bool(re.search(r"\bto taste\b|\bas needed\b|\bfor serving\b", raw, re.I))

    working = raw.strip("()[] ")
    working = re.sub(r"\s+", " ", working)
    # Drop leading "TO SERVE WITH:" style labels
    working = re.sub(r"^(to serve with|serve with|for garnish|garnish)[:\s]+", "", working, flags=re.I)

    qty, rest = _split_quantity(working)
    vague_unit = None
    unit = None

    # Vague units like pinch / dash / smidge
    vague_match = re.match(
        r"(?:a\s+)?(smidge|smidgen|pinch|pinches|dash|dashes|drop|drops|speck|touch|hint)\s+(?:of\s+)?(.+)$",
        rest,
        flags=re.I,
    )
    if vague_match:
        vague_unit = vague_match.group(1).casefold()
        rest = vague_match.group(2).strip()
        qty = (qty or 1.0) * VAGUE_TO_TSP[vague_unit]
        unit = "tsp"
        # Seasonings left as small tsp amounts; still mark to_taste for salt/pepper-only lines.
        item_guess = _canonicalize_item(rest)
        if item_guess in SEASONING_ITEMS and vague_unit in {"smidge", "smidgen", "pinch", "touch", "hint"}:
            to_taste = True

    if unit is None:
        unit, rest = _split_unit(rest)

    # Countable foods: "2 large eggs" / "1 onion"
    item, prep = _split_item_prep(rest)
    item = _canonicalize_item(item)

    if unit is None and qty is not None and _looks_countable(item, rest):
        unit = "each"
        if item.endswith("s") and item not in {"asparagus", "molasses"} and qty == 1:
            # keep plural item as canonical singular when possible
            pass

    # "2 cloves garlic" already maps clove unit; item becomes garlic via aliases
    if unit == "clove" and item in {"", "garlic"}:
        item = "garlic"

    # Eggs without unit
    if unit is None and re.search(r"\beggs?\b", item, re.I):
        unit = "each"

    # "One 3 ½- to 4-pound chicken" — no leading qty captured; keep as each=1.
    if qty is None and re.match(r"^(?:one|a|an)\b", working, re.I):
        qty = 1.0
        if unit is None and re.search(r"\b(chicken|hen|duck|turkey|roast|steak|tenderloin)\b", item, re.I):
            unit = "each"

    allergens = infer_allergens(item, raw)

    # If we only got noise, keep a cleaned item from raw
    if not item:
        item = _canonicalize_item(re.sub(r"^[\d./\s¼½¾⅓⅔⅛⅜⅝⅞]+", "", working).strip()) or working.casefold()

    notes = ""
    if vague_unit:
        notes = f"from_{vague_unit}"

    parsed = ParsedIngredient(
        raw=raw,
        quantity=qty,
        unit=unit,
        item=item,
        prep=prep,
        to_taste=to_taste,
        optional=optional,
        allergens=allergens,
        notes=notes,
    )
    polished = polish_parsed(parsed)
    if polished is None:
        return ParsedIngredient(raw=raw, item="")
    return polished


def parse_ingredients(lines: list[str]) -> list[ParsedIngredient]:
    out: list[ParsedIngredient] = []
    for line in lines:
        cleaned = clean_ingredient_line(line)
        if cleaned is None:
            continue
        if not _clean(cleaned):
            continue
        parsed = parse_ingredient(cleaned)
        if not parsed.item and not parsed.to_taste:
            continue
        out.append(parsed)
    return out


def infer_allergens(item: str, raw: str = "") -> list[str]:
    """Best-effort allergen tags from food name / raw line."""
    blob = f"{item} {raw}".casefold()
    found: list[str] = []

    rules: list[tuple[str, tuple[str, ...]]] = [
        ("dairy", ("milk", "cream", "butter", "cheese", "yogurt", "yoghurt", "whey", "buttermilk", "half-and-half", "sour cream", "mascarpone", "ricotta", "parmesan", "parm", "mozzarella", "cheddar", "ghee", "pecorino", "romano", "roquefort", "gorgonzola", "brie", "feta", "goat cheese", "cream cheese", "cotija", "gruyere", "gruyère", "swiss cheese", "provolone", "fontina", "asiago", "manchego", "blue cheese")),
        ("egg", ("egg", "eggs", "egg white", "egg yolk", "mayonnaise", "mayo")),
        ("gluten", ("flour", "wheat", "bread", "pasta", "noodle", "spaghetti", "couscous", "barley", "rye", "breadcrumb", "panko", "tortilla", "soy sauce", "worcestershire")),
        ("peanut", ("peanut", "peanuts", "peanut butter")),
        ("tree_nut", ("almond", "walnut", "pecan", "cashew", "pistachio", "hazelnut", "macadamia", "pine nut", "brazil nut")),
        ("soy", ("soy", "soya", "tofu", "tempeh", "edamame", "miso", "soy sauce")),
        ("fish", ("fish", "salmon", "tuna", "cod", "anchovy", "anchovies", "sardine", "trout", "halibut", "bass", "tilapia")),
        ("shellfish", ("shrimp", "prawn", "crab", "lobster", "clam", "mussel", "oyster", "scallop", "crawfish", "crayfish")),
        ("sesame", ("sesame", "tahini")),
        ("meat", ("beef", "pork", "lamb", "veal", "bacon", "ham", "sausage", "steak", "prosciutto", "pancetta", "chicken", "turkey", "duck", "hen", "meatball")),
        ("alcohol", ("wine", "beer", "rum", "vodka", "whiskey", "bourbon", "brandy", "sherry", "vermouth")),
        ("honey", ("honey",)),
    ]
    for allergen, needles in rules:
        if any(n in blob for n in needles):
            # Avoid "peanut" double-counting as tree_nut; peanut is separate.
            if allergen == "tree_nut" and "peanut" in blob:
                continue
            # "buttermilk" is dairy; "butter beans" false positive rare — accept.
            found.append(allergen)
    return found


def recipe_allergens(parsed: list[ParsedIngredient]) -> list[str]:
    seen: list[str] = []
    for ing in parsed:
        for a in ing.allergens:
            if a not in seen:
                seen.append(a)
    return seen


def matches_diet(allergens: list[str], diet: str) -> bool:
    """Return True if recipe allergens are compatible with a diet profile."""
    diet = diet.casefold().replace("-", "_").replace(" ", "_")
    blocked = {
        "vegetarian": {"meat", "fish", "shellfish"},
        "vegan": {"meat", "fish", "shellfish", "dairy", "egg", "honey"},
        "pescatarian": {"meat"},
        "dairy_free": {"dairy"},
        "gluten_free": {"gluten"},
        "nut_free": {"peanut", "tree_nut"},
        "peanut_free": {"peanut"},
        "egg_free": {"egg"},
        "soy_free": {"soy"},
        "shellfish_free": {"shellfish"},
    }.get(diet)
    if blocked is None:
        return True
    return not (set(allergens) & blocked)


def _split_quantity(text: str) -> tuple[float | None, str]:
    text = text.strip()
    # Patterns: 2, 2.5, 1/2, 1½, 1 1/2, 2-3 → take first number of range
    m = re.match(
        r"^(?P<q>(?:\d+\s+\d+/\d+)|(?:\d+/\d+)|(?:\d+[¼½¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚])|(?:\d*\.?\d+)|(?:[¼½¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚]))"
        r"(?:\s*[-–—to]+\s*(?:\d+\s+\d+/\d+|\d+/\d+|\d*\.?\d+|[¼½¾⅓⅔⅛⅜⅝⅞]))?"
        r"(?P<rest>\s+.*)?$",
        text,
        flags=re.I,
    )
    if not m:
        # "a cup of …" / "an onion"
        if re.match(r"^(?:a|an)\s+", text, re.I):
            return 1.0, re.sub(r"^(?:a|an)\s+", "", text, flags=re.I)
        return None, text
    qty = _parse_number(m.group("q"))
    rest = (m.group("rest") or "").strip()
    return qty, rest


def _parse_number(token: str) -> float:
    token = token.strip()
    # mixed unicode: 1½
    for glyph, value in FRACTIONS.items():
        if glyph in token:
            left = token.replace(glyph, "").strip()
            return (float(left) if left else 0.0) + value
    if re.fullmatch(r"\d+\s+\d+/\d+", token):
        whole, frac = token.split()
        num, den = frac.split("/")
        return float(whole) + float(num) / float(den)
    if "/" in token:
        num, den = token.split("/", 1)
        return float(num) / float(den)
    return float(token)


def _split_unit(text: str) -> tuple[str | None, str]:
    text = text.strip()
    if not text:
        return None, text
    # Prefer longer aliases first
    lower = text.casefold()
    for alias in sorted(UNIT_ALIASES.keys(), key=len, reverse=True):
        alias_l = alias.casefold()
        if lower.startswith(alias_l + " ") or lower == alias_l:
            unit = UNIT_ALIASES[alias]
            rest = text[len(alias_l) :].strip(" .")
            rest = re.sub(r"^of\s+", "", rest, flags=re.I)
            return unit, rest
    return None, text


def _split_item_prep(text: str) -> tuple[str, str]:
    text = text.strip().strip(",")
    # Split on comma prep: "butter, melted"
    # Do not split when the left side is only packing/prep ("lightly packed, chopped parsley").
    prep = ""
    if "," in text:
        main, _, tail = text.partition(",")
        main_st = main.strip()
        if main_st and not main_st.startswith("(") and not _is_modifier_phrase(main_st):
            text = main_st
            prep = _clean_prep(tail)

    # Strip trailing prep adjectives that are clearly prep
    tokens = text.split()
    leading_prep: list[str] = []
    while tokens:
        word = tokens[0].casefold().strip(",")
        if word in SIZE_WORDS:
            tokens.pop(0)
            continue
        if word in PREP_WORDS:
            leading_prep.append(word)
            tokens.pop(0)
            continue
        break
    trailing_prep: list[str] = []
    while tokens:
        word = tokens[-1].casefold().strip(",")
        if word in SIZE_WORDS:
            tokens.pop()
            continue
        if word in PREP_WORDS:
            trailing_prep.insert(0, word)
            tokens.pop()
            continue
        break

    item = " ".join(tokens).strip(" ,.")
    # Cut at "or" alternatives for canonical item: keep first *food*, not a color leftover
    # But keep "short- or medium-grain" / "olive or vegetable oil" style pairs.
    if re.search(r"\bor\b", item, re.I):
        if re.search(r"\b(short|medium|long)[- ]?(grain)?\s*or\s*(short|medium|long)", item, re.I):
            pass  # keep grain range
        elif re.search(r"\b(olive|vegetable|canola|neutral)\s+or\s+(olive|vegetable|canola|neutral|other)", item, re.I):
            item = "oil"
        else:
            left, right = re.split(r"\bor\b", item, maxsplit=1, flags=re.I)
            left_s, right_s = left.strip(" ,/"), right.strip(" ,/")
            # "mild lemon- or red wine…" / "8- or 10-ounce" — left is an incomplete hyphen compound.
            if left_s.endswith(("-", "–", "—")):
                item = f"{left_s} or {right_s}"
            elif _is_modifier_phrase(left_s):
                item = right_s
            else:
                item = left_s
    # Parenthetical notes after the food ("cabbage (about 1 pound)")
    item = re.sub(r"\s*\([^)]*\)\s*$", "", item).strip()
    item = re.sub(r"\s*\([^)]*$", "", item).strip()
    # Mid-item dual units left after qty split: "chinese broccoli (gai lan)" keep; bare grams drop earlier.

    merged_prep = ", ".join(p for p in [" ".join(leading_prep), prep, " ".join(trailing_prep)] if p)
    return item.casefold(), merged_prep


def _is_modifier_phrase(text: str) -> bool:
    """True when a phrase is only color/size/packing — not a buyable food."""
    tokens = [t.casefold().strip(" ,./") for t in text.split() if t.strip(" ,./")]
    if not tokens:
        return True
    modifiers = SIZE_WORDS | PREP_WORDS | COLOR_WORDS | CONTAINER_WORDS | {"of", "a", "an", "the"}
    return all(t in modifiers for t in tokens)


def _clean_prep(text: str) -> str:
    text = _clean(text).strip(" ,.")
    # Drop "or to taste" style tails already handled
    text = re.sub(r"\bor to taste\b", "", text, flags=re.I).strip(" ,.")
    return text.casefold()


def _canonicalize_item(item: str) -> str:
    item = _clean(item).casefold().strip(" .,;")
    item = re.sub(r"\bif desired\b|\bas desired\b", "", item, flags=re.I)
    item = re.sub(r"\bscrubbed\b|\bpeeled\b", "", item, flags=re.I)
    item = re.sub(r"\s*\([^)]*$", "", item).strip()
    item = re.sub(r"\s+", " ", item).strip(" .,;")
    # Keep "ground meat" / "ground beef" — stripping "ground" leaves a useless "meat".
    if not GROUND_MEAT_RE.match(item):
        item = re.sub(r"^(fresh|dried|frozen|ground|whole)\s+", "", item)
    if item in ITEM_ALIASES:
        return ITEM_ALIASES[item]
    # Try without leading size words already stripped
    for alias, canon in ITEM_ALIASES.items():
        if item == alias or item.endswith(" " + alias):
            return canon
    # Singular-ish: eggs -> egg when exact
    if item.endswith("oes") and item[:-2] in COUNTABLE_ITEMS:
        return item[:-2]
    if item.endswith("s") and item[:-1] in {c.rstrip("s") if c.endswith("s") else c for c in COUNTABLE_ITEMS}:
        singular = item[:-1]
        return ITEM_ALIASES.get(singular, singular)
    return item


def _looks_countable(item: str, rest: str) -> bool:
    blob = f"{item} {rest}".casefold()
    if item in COUNTABLE_ITEMS or item.rstrip("s") in {c.rstrip("s") for c in COUNTABLE_ITEMS}:
        return True
    return any(c in blob.split() for c in ("egg", "eggs", "onion", "onions", "lemon", "lime"))


def format_qty(value: float) -> str:
    """Pretty-print a cooking quantity (1, 1/2, 1 1/2, …)."""
    return _format_qty(value)


def _format_qty(value: float) -> str:
    if abs(value - round(value)) < 1e-9:
        return str(int(round(value)))
    # common cooking fractions
    table = {
        0.125: "1/8",
        0.25: "1/4",
        0.333: "1/3",
        1 / 3: "1/3",
        0.375: "3/8",
        0.5: "1/2",
        0.625: "5/8",
        0.666: "2/3",
        2 / 3: "2/3",
        0.75: "3/4",
        0.875: "7/8",
        1 / 16: "1/16",
        1 / 8: "1/8",
    }
    for target, label in table.items():
        if abs(value - target) < 0.02:
            return label
    # mixed numbers
    whole = int(value)
    frac = value - whole
    if whole and frac > 0.05:
        return f"{whole} {_format_qty(frac)}"
    return f"{value:.2f}".rstrip("0").rstrip(".")


def _clean(text: str) -> str:
    text = text.replace("\xa0", " ")
    text = re.sub(r"\s+", " ", text).strip()
    return text
