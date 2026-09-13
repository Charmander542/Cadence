# Cadence simulator automation

Agent-oriented tooling to build, drive, screenshot, and inspect the Cadence iOS app in the iPhone Simulator.

## Quick start

```bash
# One-time setup (installs idb via Homebrew)
./scripts/setup_sim_automation.sh

# Build, install, and screenshot every main surface
./scripts/cadence_sim build install spot-check
```

Screenshots are written to `/tmp/cadence-spot-check/` by default (`CADENCE_SHOT_DIR`).

## Agent workflow

1. **Doctor** — verify dependencies: `./scripts/cadence_sim doctor --json`
2. **Build + install** — `./scripts/cadence_sim build install`
3. **Launch** — `./scripts/cadence_sim launch` (passes `-cadenceSkipOnboarding` automatically)
4. **Navigate** — relaunch with launch args (default) or in-session taps:
   - `./scripts/cadence_sim navigate tab today`
   - `./scripts/cadence_sim navigate wheel spend` (also `focus` / `news` / `health` / …)
   - `./scripts/cadence_sim navigate open settings`
   - `./scripts/cadence_sim navigate tab calendar --in-session` (tap tab bar, keeps state)
5. **Screenshot** — `./scripts/cadence_sim screenshot --name my-screen`
6. **Inspect UI** — `./scripts/cadence_sim describe --json` (accessibility tree)
7. **Interact** — `./scripts/cadence_sim tap-label "Open sidebar"`
8. **Run scripted flows** — `./scripts/cadence_sim run spot_check`

Use `--json` on any command for structured output agents can parse.

## Commands

| Command | Purpose |
|---------|---------|
| `doctor` | Check simctl, idb, app bundle |
| `build` | `xcodebuild` for iPhone simulator |
| `boot` | Boot simulator + open Simulator.app |
| `install` | Install `.app` bundle |
| `launch [args…]` | Launch Cadence |
| `terminate` | Kill the app |
| `navigate tab <name\|0-4> [--in-session]` | Switch legacy tab (relaunch or tap) |
| `navigate wheel <dest> [--in-session]` | Open dial destination via `-openWheel` (spend/focus/news/…) |
| `navigate open settings\|search\|shop\|drawer\|spend\|focus\|news\|…` | Open sheet/drawer/wheel page |
| `navigate close settings\|search\|drawer\|all` | Dismiss chrome |
| `open-url <url>` | Raw `simctl openurl` |
| `screenshot [--name X] [--out path]` | PNG capture |
| `describe [--query text]` | Accessibility elements (idb) |
| `tap-label <label>` | Tap by VoiceOver label |
| `tap <x> <y>` | Tap device coordinates (points) |
| `swipe x1 y1 x2 y2` | Swipe gesture |
| `type <text>` | Type into focused field |
| `ui-appearance light\|dark` | Simulator appearance |
| `wait <seconds>` | Sleep |
| `run <flow>` | Run JSON flow from `scripts/cadence_sim_flows/` |
| `spot-check` | Preset: all tabs + shop + settings + search |

## Environment

| Variable | Default |
|----------|---------|
| `CADENCE_SIM_UDID` | iPhone 16 Pro Max (no Watch) UDID |
| `CADENCE_APP_PATH` | `/tmp/CadenceDerived/.../Cadence.app` |
| `CADENCE_SHOT_DIR` | `/tmp/cadence-spot-check` |
| `CADENCE_DEVICE` | `iPhone 16 Pro Max (no Watch)` |
| `CADENCE_BUNDLE` | `com.musclemeal.app` |

## Flow files

Add JSON flows under `scripts/cadence_sim_flows/`. Each step is an object with `"action"`:

```json
{ "action": "navigate", "target": "tab", "value": "calendar" }
{ "action": "tap-label", "label": "Settings" }
{ "action": "screenshot", "name": "calendar-tab" }
{ "action": "wait", "seconds": 0.8 }
```

Built-in flows:

- `spot_check` — legacy tabs + Spend/Focus/News, shop, settings, global search
- `drawer_and_settings` — drawer chrome + settings entry

## App integration

The app accepts:

- **Launch args**: `-cadenceSkipOnboarding`, `-openMainTab N`, `-openWheel <dest>`, `-openShop`, `-openSettings`, `-openGlobalSearch`
- **URL scheme `cadence://`**: optional; iOS may show an “Open in Cadence?” confirmation dialog, so prefer launch args + idb taps for automation.

Automation logs print as `CADENCE_AUTOMATION action=… detail=…` in the Xcode/simulator console when URLs are handled.

## Dependencies

- **Xcode** + iOS Simulator (required)
- **[idb](https://fbidb.io/)** — tap/swipe/type + accessibility tree. Install everything via Homebrew (companion + CLI):

  ```bash
  brew trust facebook/fb   # once, if prompted
  brew install facebook/fb/idb
  ```

  Or run `./scripts/setup_sim_automation.sh`.

- **Python 3** — stdlib only for `cadence_sim.py` (no pip packages needed)

## Example: agent design review loop

```bash
./scripts/cadence_sim build install launch
./scripts/cadence_sim navigate tab today
./scripts/cadence_sim screenshot --name today-before
./scripts/cadence_sim describe --query "Add task" --json
# … make SwiftUI changes …
./scripts/cadence_sim build install
./scripts/cadence_sim navigate tab today
./scripts/cadence_sim screenshot --name today-after
```

Compare PNGs in `CADENCE_SHOT_DIR` and use `describe --json` to verify accessibility labels before/after UX changes.
