# Cadence Sub-Apps

Cadence is a **shell** (wheel dial + shared Theme/chrome) that hosts modular **sub-apps**.
Domain logic stays inside each module — only Theme, navigation, and optional Today cards are shared.

## Layout

```
MealPlannerApp/MealPlannerApp/
  SubApps/CadenceSubApp.swift
  Models/SpendModels.swift | HealthModels.swift | NewsModels.swift
  Services/…Spend* | …Health* | …News*
  Views/Spend | Health | News
```

## Adding a new sub-app

1. Add `CadenceSubAppID` + manifest in `CadenceSubApp.swift`.
2. Add `WheelDestination` + `pageContent` in `RootView`.
3. Register SwiftData models; bump store name in `MealPlannerAppApp`.
4. Add `SettingsRoute` + Settings row / catalog.
5. Keep code under `Models/` + `Services/` + `Views/<Name>/`.
6. Document setup in `docs/` and set manifest `docsPath`.

## Rules

- Do not put Spend/Health/News logic in meal planning or `WorkoutIntegration`.
- Do not embed Plaid secrets, Teller mTLS keys, or news API secrets in the app binary (Keychain / gitignored local plist only).
- Visibility for **all** dial apps (Meals, Workout, Habits, Spend, …) uses `CadenceAppsPreferences` — swipe-up **Edit** / hold-to-edit grid + **Settings → Apps & wheel**.
- Optional module manifests still live in `CadenceSubAppRegistry`; `isWheelEnabled` delegates to apps prefs.
- Orange = nav/selection; blue = primary CTAs.

## Shipped modules

| Module | Status | Docs |
|--------|--------|------|
| **Spend** | Overview pie + budgets + subcategories; Plaid Link; cost-per-use | `docs/PLAID_SETUP.md` |
| **Health** | Bevel-like rings; HealthKit + demo | `docs/APPLE_HEALTH_SETUP.md` |
| **News** | Daily top-10 RSS + optional AI briefs + images | `docs/NEWS_SETUP.md` |
| **Focus** | Pomodoro + stopwatch + stats | (in-app Settings → Focus) |

Mobbin — Spend: Rocket Money (category donut, budgets, custom categories). Health: Bevel. News: Perplexity Discover, Apple News, Particle. Focus: Toggl Track / Me+ / Focus To-Do-style stats.
