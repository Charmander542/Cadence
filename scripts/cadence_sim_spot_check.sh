#!/usr/bin/env bash
# Cadence UX loop — install app and spot-check all 5 tabs (+ settings + search).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UDID="${CADENCE_SIM_UDID:-E06A7FB1-24AB-4F46-BEB9-9A0CFFEB83F0}"
BUNDLE="com.musclemeal.app"
APP="${CADENCE_APP_PATH:-/tmp/CadenceDerived/Build/Products/Debug-iphonesimulator/MealPlannerApp.app}"
SHOT_DIR="${CADENCE_SHOT_DIR:-/tmp/cadence-spot-check}"

if [[ ! -d "$APP" ]]; then
  echo "Missing app bundle: $APP" >&2
  exit 1
fi

mkdir -p "$SHOT_DIR"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true

tab_names=(today calendar meals matrix habits)
for tab in 0 1 2 3 4; do
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE" -openMainTab "$tab" >/dev/null
  sleep 1.6
  xcrun simctl io "$UDID" screenshot "$SHOT_DIR/tab-${tab_names[$tab]}.png"
  echo "CADENCE_SPOT_CHECK screenshot tab=${tab_names[$tab]}"
done

xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl launch "$UDID" "$BUNDLE" -openShop >/dev/null
sleep 2.0
xcrun simctl io "$UDID" screenshot "$SHOT_DIR/shop.png"
echo "CADENCE_SPOT_CHECK screenshot shop"

xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl launch "$UDID" "$BUNDLE" -openSettings >/dev/null
sleep 0.9
xcrun simctl io "$UDID" screenshot "$SHOT_DIR/settings.png"
echo "CADENCE_SPOT_CHECK screenshot settings"

xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl launch "$UDID" "$BUNDLE" -openGlobalSearch >/dev/null
sleep 0.9
xcrun simctl io "$UDID" screenshot "$SHOT_DIR/global-search.png"
echo "CADENCE_SPOT_CHECK screenshot global-search"

xcrun simctl ui "$UDID" appearance dark
echo "CADENCE_SPOT_CHECK complete shots=$SHOT_DIR"
