# Cadence Body / Health redesign

**Status:** Phase 2 — Mobbin Bevel visual pass 2026-09-12 (stepped hypnogram + Sleep tab IA). Continue polish.  
**Refs:** User Bevel screenshots; Mobbin [Bevel Primary sleep](https://mobbin.com/flows/a3fb194c-c64d-4ac1-b424-317a26c013af), [Sleep stages hypnogram](https://mobbin.com/screens/c4c2dd72-1d95-431b-898f-ad415b4f5c39), [WHOOP Overview](https://mobbin.com/screens/a47efa6c-ecca-4b3a-b3c8-c511cea9c025), [Oura Activity](https://mobbin.com/screens/83208126-a5f9-440f-9005-de2b03211350)

---

## Shipped vs remaining (post-audit)

| Area | Status |
|------|--------|
| Multi-input Sleep / Recovery / Strain + ratings + confidence + sleep bank | **Shipped** (`BevelScoring`) |
| Explainable detail sheets (contributors, stages, bank) | **Shipped** |
| Body Overview · Sleep · Fitness · Lift | **Shipped** |
| HK workout list (Fitness logger) | **Shipped** |
| Persist stages/zones/latency/temp/confidence on snapshot | **Shipped** |
| Vitals → detail drill-down | **Shipped** |
| Sleep hypnogram / scrub stages chart | **Shipped** (Watch intervals when synced; demo synthesizes) |
| Multi-day history browser | **Shipped** (30-day picker + Fitness heatmap) |
| Per-workout detail sheet | **Shipped** |
| Biological age / blood biomarkers | Out of scope (needs labs) |
| HK write-back of Lift workouts | Remaining (optional) |
| Bevel Primary sleep layout (score pill, 2×3 grid, latency scale, Watch line) | **Shipped** |
| Bevel Health Monitor cards + stress gauge | **Shipped** |

---

## Goals

1. **Real Apple Health / Watch sync** — stages, HRV, RHR, RR, SpO₂, wrist temp, workouts, zones (already partially wired; harden + expose).
2. **Strong, explainable scores** — Sleep / Recovery / Strain with contributor ratings, confidence, baselines, sleep bank.
3. **Deliberate sub-pages** — every ring/card opens a page that explains *what*, *why*, and *what to do*.
4. **Sleep tracker** — Bevel-style primary sleep: score, time in bed/asleep, contributors, stage cards, overnight vitals.
5. **Fitness logger** — HK workouts list + Cadence Lift, activity summary, strain vs target.

Not medical advice — training/recovery context only (App Review).

---

## Information architecture

### Body dial page (`HealthHomeView`)

| Segment | Role |
|---------|------|
| **Overview** | Strain / Recovery / Sleep rings, insight, stress+energy, vitals 2×3, sync chip |
| **Sleep** | Primary sleep tracker (last night) + trends entry |
| **Fitness** | Activity heatmap / summary, strain vs target, **workout log** (HealthKit + Lift) |
| **Lift** | Existing Cadence strength program (`WorkoutHomeView`) |

### Reachable sub-pages (each must be clear + explanatory)

| From | Opens | Content |
|------|-------|---------|
| Strain ring / card | Strain detail | Active vs passive load, zones, target, 7d sparkline, plain-language “what strain means” |
| Recovery ring | Recovery detail | HRV/RHR/RR/SpO₂/temp vs baseline, ratings, insight |
| Sleep ring / Sleep tab | Sleep detail | Score + contributors (Excellent→Poor bars), stages grid, efficiency, HR dip, sleep bank |
| Vitals tiles | Vital detail | Value, baseline band, 7–30d sparkline, “Normal / Low / High” |
| Stress / Energy | Stress & Energy detail | High/avg/low + energy battery explained |
| Fitness workout row | Workout detail | Duration, kcal, avg HR, zones (when available), source (Watch / Lift) |
| Lift CTA | Lift segment | Unchanged program UX |

---

## Visual language (Cadence Theme + Bevel cues)

- Dark-first cards (`Theme.Card`), muted caps section labels.
- **Semantic status:** Excellent (cta/blue), Good (green), Fair (orange), Poor (danger) — same on contributor bars.
- Large hero numbers; one-sentence insight under every score.
- Chevrons on every drill-down; empty states say what Watch data unlocks.

---

## Algorithms (authoritative)

All math lives in `BevelScoring` + `HealthBaselines`. UI only displays breakdowns.

### Data confidence (0–1)

Weight available inputs; missing Watch overnight data lowers confidence and softens scores toward neutral (55–70) instead of pretending precision.

### Sleep (0–100)

| Contributor | Weight | Logic |
|-------------|--------|-------|
| Duration | 0.28 | Asleep ÷ goal (profile / 8h default); soft cap above goal |
| Stages (Deep + REM) | 0.22 | Deep ~15–20%, REM ~20–25% of asleep; scored separately in UI |
| Efficiency | 0.18 | Asleep ÷ time in bed |
| Continuity | 0.12 | Penalize awakenings |
| HR dip | 0.12 | (Day HR − overnight RHR) / Day HR vs ~15–20% |
| Latency* | 0.08 | Time in bed → first asleep (shown on Fast/Normal/Late scale; not in 2×3 grid) |

\*Latency optional until intervals are reliable. **UI grid (Bevel):** Time Asleep · Heart Rate Dip · REM · Deep · Efficiency · Continuity.

**Sleep bank:** rolling 7-day Σ(asleep − goal); debt/surplus shown on Sleep page.

**Ratings:** map contributor 0–100 → Poor &lt;45 · Fair &lt;65 · Good &lt;85 · Excellent ≥85.

### Recovery (0–100)

| Contributor | Weight | Logic |
|-------------|--------|-------|
| HRV vs 60d baseline | 0.32 | ratio mapped 0.7→1.3 |
| Overnight RHR vs baseline | 0.26 | lower than baseline better |
| Respiratory rate | 0.12 | distance from baseline |
| SpO₂ | 0.08 | ≥97 excellent |
| Wrist temp Δ | 0.05 | |Δ| penalty |
| Prior sleep score | 0.17 | carry sleep quality into readiness |

### Strain (0–100, logarithmic)

- **Active:** HR zone minutes (Z1…Z5 weights) + workout kcal + exercise minutes  
- **Passive:** non-workout active energy + steps + elevated daytime HR  
- `display = 100 * log(1+load) / log(1+220)`  
- **Target strain:** recent avg strain × recovery factor (higher recovery → higher target)

### Stress / Energy (derived)

- Stress avg from HRV vs baseline + inverse recovery + strain  
- Energy ≈ 0.55·Recovery + 0.25·Sleep + 0.20·(100−Strain)

### Insights

Template from score triad + sleep hours + kcal — no disease claims.

---

## Apple Health sync plan

| Metric | Source | Status |
|--------|--------|--------|
| Sleep stages / in bed | `HKCategoryType.sleepAnalysis` | Wired — keep primary session merge |
| Overnight RHR | HR samples during asleep intervals | Wired |
| Apple Resting HR | `restingHeartRate` | Wired |
| HRV SDNN | `heartRateVariabilitySDNN` | Prefer overnight samples |
| RR, SpO₂ | quantity types | Wired |
| Wrist temp | `appleSleepingWristTemperature` | Optional iOS 16+ |
| Steps, active kcal, exercise | cumulative | Wired |
| Workouts | `HKWorkout` | Stats wired — **expand to list** for Fitness log |
| HR zones | sample bucketing vs estimated max HR | Wired |

**Baselines:** `HealthBaselines` 60-day maps for HRV/RHR/RR — also store sleep goal adherence for sleep bank.

**Permissions:** Settings → Body; auto-request on Body appear.

---

## Implementation phases

1. **Algorithms** — contributor ratings, recovery breakdown, sleep bank, confidence; persist breakdown JSON on snapshot if needed.  
2. **Sync** — workout list fetch; overnight HRV preference; sleep latency.  
3. **Sleep page** — Bevel primary sleep layout in Cadence Theme.  
4. **Fitness page** — summary + HK workout logger + Lift bridge.  
5. **Strain / Recovery / Vital details** — replace placeholder blurbs with real breakdowns.  
6. **Overview polish** — sync chip, clearer vitals grid, insight expand.

---

## Out of scope (for now)

- Biological age / blood biomarkers (Bevel Biology) — needs labs, not Watch.  
- Menstrual cycle tracking.  
- Food / nutrition on Body (belongs Meals).  
- Cloning Bevel visuals pixel-perfect — Cadence Theme + patterns only.
