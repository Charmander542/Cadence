# Apple Health setup for Cadence Body

Cadence **Body** combines Bevel-style Strain / Recovery / Sleep with the Lift program on one dial page.

Scoring follows Bevel’s **published** components (Help Center + blog) — not a proprietary reverse-engineer:

| Score | Inputs |
|-------|--------|
| **Sleep** | Time Asleep vs goal, Deep/REM balance, efficiency (asleep ÷ in bed), continuity (awakenings), nocturnal HR dip |
| **Recovery** | Overnight RHR, HRV (SDNN from HealthKit), respiratory rate, SpO₂, wrist temp delta — vs ~60-day personal baselines |
| **Strain** | Active (Watch workouts + HR zone minutes) + passive (steps, non-workout energy, daytime HR), **logarithmic** curve; Target Strain from recent strain × recovery |

## 1. Capabilities

In Xcode → Cadence target → **Signing & Capabilities**:

1. Add **HealthKit**.
2. Confirm `Cadence.entitlements` contains `com.apple.developer.healthkit` = true.

## 2. Privacy strings

| Key | Purpose |
|-----|---------|
| `NSHealthShareUsageDescription` | Why Cadence **reads** health data |
| `NSHealthUpdateUsageDescription` | Required by Apple even if write is unused today |

## 3. Types requested (`HealthKitClient.readTypes`)

- Sleep analysis (stages)
- Resting heart rate + overnight HR from samples during sleep
- Heart rate (zones + sparkline)
- HRV SDNN
- Respiratory rate
- Oxygen saturation (SpO₂)
- Active energy, steps, Apple exercise time
- Workouts (`HKWorkout`)
- Apple sleeping wrist temperature (when available)

## 4. First-run / sync

1. Open **Body** on the dial.
2. Cadence requests HealthKit on first sync (or Settings → Body → Connect Apple Health).
3. Wear Apple Watch overnight for sleep stages / HRV / overnight RHR.
4. Watch workouts feed **active strain**; daily movement feeds **passive strain**.

Simulator often has empty HealthKit → demo fallback (Settings → Body).

## 5. Architecture

| Piece | Location |
|-------|----------|
| Dial page | `HealthHomeView` (Overview + Lift segments) |
| HealthKit I/O | `HealthKitClient.swift` |
| Bevel-style math | `BevelScoring.swift` + `HealthBaselines` |
| Snapshot persist | `HealthStore` / `HealthDaySnapshotEntity` |
| Lift program | `WorkoutHomeView` embedded in Body → Lift |

## 6. App Review

- Usage copy: training / recovery context — not medical diagnosis.
- Avoid disease claims in insight strings.
