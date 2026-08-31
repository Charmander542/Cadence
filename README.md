# Based Cooking

Weekly cooking app for muscle-gain meal prep. **Recipes come from [Based-Cooking](https://github.com/Charmander542/Based-Cooking)** (cookbook + based.cooking store). The week is planned with **algorithms**, not a required API key.

## How you use it

1. **Onboarding** — body stats, goal, diet. Macros are Mifflin–St Jeor on-device. AI keys are optional.
2. **Week** — one dinner to cook each day. Lunch is leftovers from that cook. Breakfast is a high-protein staple mix (egg cap: 18/week).
3. **Swap** — don’t like tonight? Swap that dinner; the rest of the week stays.
4. **Cook** — ingredients keep minced/diced/chopped. Original recipe link is on the detail screen.
5. **Shop** — merged list in buyable units (bunches, heads, egg counts).
6. **Recipes** — search the local store (FTS-style in-memory over the SQLite snapshot).

The planner scores dinners for **shared groceries** (smaller shopping list) and **flavor/protein variety** (no chicken stir-fry every night), then pairs a **cookbook side** that overlaps ingredients with the main.

## Layout

| Path | Role |
|------|------|
| `backend/based-cooking/` | Vendored Based-Cooking: scrape, parse, FTS store, `plan_week` |
| `scripts/build_recipe_store.py` | Import legacy JSON + scrape based.cooking → `data/recipes.sqlite3` |
| `MealPlannerApp/` | SwiftUI app (iOS 18.6+) |

## Build the recipe database

```bash
cd ~/Projects/MuscleMeal
python3 scripts/build_recipe_store.py
# copies data/recipes.sqlite3 → MealPlannerApp/MealPlannerApp/Resources/recipes.sqlite3
```

To add Joy of Cooking / Food Lab / etc., drop EPUBs next to Based-Cooking and run:

```bash
cd backend/based-cooking
python3 -m pip install -e .
based-cooking scrape-all /path/to/epubs --data-dir ../../data
./scripts/sync_recipes_to_app.sh
```

Current bundled snapshot is the Based-Cooking store (~4,560 recipes: Joy of Cooking, Food Lab, The Wok, Food Network Magazine, Nigella Express, Sheet Pan Suppers, Martha One Pot, Salt Fat Acid Heat, Keep It Simple, and based.cooking). Cookbook page numbers and web links are on each recipe.

## App

Open `MealPlannerApp/MealPlannerApp.xcodeproj` in Xcode 16+. No API key is required to generate a week.

Planning is `WeekPlanner` (Swift port of `based_cooking.plan.plan_week`). Optional Claude/OpenAI is only for retuning macros.
