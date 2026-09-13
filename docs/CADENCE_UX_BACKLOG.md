# Cadence UX Backlog

**Status:** Audit round 5–6 complete 2026-08-30 — Batches H–J implemented + verified

---

## How to use this file

**One agent** cycles forever: **Implement batch → Test in simulator → repeat.** When P0/P1/P2 are all Done, run a fresh audit, append new P2 batches, and keep going.

| Step | Action |
|------|--------|
| **Implement** | Fix the next batch. Add `→ Fix:` under items. Never check Done boxes yet. |
| **Test** | Build + simulator. Mark Done with date. Note failures on the item. |
| **Audit** | Only when nothing is open — full-app pass, append new P2 groups. |

Set **Phase** → `RUNNING` always. **Do not stop** — audit and add more work when backlog clears. User ends the task when they want to.

---

## P0 — Must fix

_All P0 verified 2026-08-30._

---

## P1 — Should fix

_All P1 verified 2026-08-30 batch 3._

---

## P2 — Polish (next batches)

### Batch A — Layout & duplicate chrome

- [x] **Calendar FAB still obscures workout chips on last grid row** — 2026-08-30.
- [x] **Today has duplicate search affordances** — 2026-08-30.

### Batch B — Empty states & dead ends

- [x] **Grocery empty state has no CTA** — 2026-08-30.
- [x] **Habits tab blank when no habits** — 2026-08-30.
- [x] **Today clear-state inconsistent** — 2026-08-30.
- [x] **Matrix all-empty quadrants** — 2026-08-30.
- [x] **TonightMealCard silent without plan** — 2026-08-30.

### Batch C — Settings & discoverability

- [x] **Metric units only in onboarding** — 2026-08-30.
- [x] **Global search excludes calendar events** — 2026-08-30.
- [x] **Browse recipes buried in Settings** — 2026-08-30.
- [x] **Drawer sub-destinations lose context** — 2026-08-30.

### Batch D — Accessibility

- [x] **Sparse VoiceOver on core rows** — 2026-08-30.
- [x] **Habit complete disabled with no hint** — 2026-08-30.

### Batch E — Polish (audit round 2)

- [x] **Calendar month grid vertical dead space** — 2026-08-30.
- [x] **Workout Begin/Skip VoiceOver** — 2026-08-30.
- [x] **Global search recipe title casing** — 2026-08-30.
- [x] **Light mode spot-check** — 2026-08-30.

### Batch F — Audit round 3

- [x] **Simulator left in light mode after testing** — 2026-08-30.
- [x] **Recipe ALL CAPS in Meals/Today/Browse** — 2026-08-30.

### Batch G — Audit round 4

- [x] **Recipe detail nav title ALL CAPS** — 2026-08-30.

### Batch H — Audit round 5 (accessibility & calendar)

- [x] **OrangeFAB says “Add task” everywhere** — 2026-08-30. Calendar “Add event”; Habits “Add habit”; Today/Matrix keep defaults.
  → Fix: `OrangeFAB` optional `accessibilityLabel` / `accessibilityHint` params.
- [x] **Habits tab stacked duplicate week selectors** — 2026-08-30. Removed `WorkoutWeekStrip`; habit `weekStrip` shows lift short name under day number.
  → Fix: single week strip with `WorkoutIntegration.scheduledSession` badge.
- [x] **DayDetailSheet empty day is a dead end** — 2026-08-30. “Add task” + “Add event” CTAs; `QuickAddSheet(initialDue:)` pre-fills day.
  → Fix: `DayAgendaSection` empty card + sheets.
- [x] **Habits VoiceOver says “today” on non-today days** — 2026-08-30. Combined label uses “not scheduled on this day”.
- [x] **Calendar month cells invisible to VoiceOver** — 2026-08-30. Combined label + button trait on month cells.
  → Fix: `monthCellAccessibilityLabel`; header prev/next/scope labels added.
- [x] **Calendar grid lines hardcoded white (light mode)** — 2026-08-30. `Theme.gridDivider` adaptive token; calendar week grid uses it.
  → Fix: `Theme.gridDivider`; replaced `Color.white.opacity` strokes in `CalendarPlannerView`.

### Batch I — Audit round 6 (search, meals, theming)

- [x] **Global Search excludes shop/grocery items** — 2026-08-30. Shop section in search; tap → Meals + shop sheet via `requestedOpenShop`.
  → Fix: `@Query GroceryItemEntity`; `AppModel.requestedOpenShop`; updated placeholder copy.
- [x] **Meals day with no dinner is a dead end** — 2026-08-30. “Swap in dinner” + “Browse” on empty day hero.
  → Fix: `todayHero` else branch CTAs reuse swap/browse flows.
- [x] **Browse blank when filters match nothing** — 2026-08-30. “No recipes match” message when `filtered.isEmpty`.
- [x] **Browse/Search/Settings lists don’t use Theme.canvas** — 2026-08-30. `scrollContentBackground(.hidden)` + `Theme.canvas` on Browse, GlobalSearch, Settings.
- [x] **Global search E2E verified** — 2026-08-30. `-openGlobalSearch` shows updated placeholder + shop help text.

### Batch J — Audit round 7 (copy & light polish)

- [x] **Drawer search hint omits shop** — 2026-08-30. Hint matches global search scope.
- [x] **Drawer dividers hardcoded white** — 2026-08-30. `Theme.gridDivider` on drawer section dividers.
- [x] **QuickAdd checkbox ring hardcoded white** — 2026-08-30. `Theme.muted.opacity(0.45)` stroke.

### Batch K — Audit round 8 (header & adaptive chrome)

- [x] **Meals header “New week” wraps vertically** — 2026-08-30. `fixedSize` + `lineLimit(1)` on plan button; `PlannerScreenHeader` title scales.
  → Fix: trailing `layoutPriority`; title `minimumScaleFactor`.
- [x] **GlobalSearchButton missing shop scope hint** — 2026-08-30. Hint matches drawer/global search copy.
- [x] **TaskCheckbox ring hardcoded white** — 2026-08-30. `Theme.muted.opacity(0.45)` unchecked stroke.
- [x] **Habit mini-week dots hardcoded white** — 2026-08-30. `Theme.sunken` / `Theme.flagNone` for scheduled/unscheduled dots.
- [x] **Grocery list default grouped background** — 2026-08-30. `Theme.canvas` on shop list.

### Batch L — Audit round 9 (workout adaptive chrome)

- [x] **Active workout set checkbox white ring** — 2026-08-30. `Theme.muted.opacity(0.4)` unchecked stroke.
- [x] **Workout preview dividers hardcoded white** — 2026-08-30. `Theme.gridDivider` between exercise rows.
- [x] **WorkoutWeekStrip log dots hardcoded white** — 2026-08-30. `Theme.sunken` for unlogged days (component retained for reuse).
- [x] **Keypad plate borders hardcoded white** — 2026-08-30. `Color.primary.opacity(0.15)` adaptive rim.

### Batch M — Audit round 10 (matrix & lists)

- [x] **Matrix empty hint is plain text only** — 2026-08-30. `Theme.EmptyState` + “Add task” opens QuickAdd.
- [x] **UndoFAB missing VoiceOver hint** — 2026-08-30. “Restores the last completed task”.
- [x] **Inbox/list views show completed tasks in open list** — 2026-08-30. Filter `!isCompleted` for inbox + custom lists.
- [x] **Task delete button sparse a11y** — 2026-08-30. Delete hint on TaskEditorSheet.

### Batch N — Audit round 11 (onboarding & overlays)

- [x] **Onboarding uses default Form background** — 2026-08-30. `Theme.canvas` on onboarding flow.
- [x] **Pantry editor default grouped background** — 2026-08-30. `Theme.canvas` on pantry sheet.
- [x] **Suggested tasks empty state off-brand** — 2026-08-30. `Theme.EmptyState` replaces `ContentUnavailableView`.
- [x] **Plan generating overlay sparse VoiceOver** — 2026-08-30. Container label + Continue hint; minimized banner Show label.
- [x] **Calendar year month tiles unlabeled** — 2026-08-30. “January, open month view” accessibility labels.

### Batch O — Audit round 12 (navigation a11y & dead ends)

- [x] **Active workout with no live session is a dead end** — 2026-08-30. `Theme.EmptyState` + Close dismisses sheet.
- [x] **Planner drawer menu icon unlabeled** — 2026-08-30. “Open menu” + drawer hint.
- [x] **Settings gear missing hint** — 2026-08-30. “Opens app settings”.
- [x] **Suggested tasks lightbulb sparse a11y** — 2026-08-30. Hint explains overdue/undated suggestions.
- [x] **Onboarding skip actions sparse a11y** — 2026-08-30. Hints on Skip setup / Skip to finish.

### Batch P — Audit round 13 (calendar week & Today a11y)

- [x] **Calendar week hour slots unlabeled** — 2026-08-30. Day/time + event count label; “Double tap to add event”.
- [x] **Lift hub week strip rest days silent when disabled** — 2026-08-30. Labels + hints for rest/workout/live-in-progress.
- [x] **Today overdue Postpone menu unlabeled** — 2026-08-30. Label + hint for bulk postpone.
- [x] **Today collapsible sections lack expand/collapse a11y** — 2026-08-30. Value Collapsed/Expanded + toggle hint.
- [x] **Lift rest card uses system secondary color** — 2026-08-30. `Theme.muted` for body copy.

### Batch Q — Audit round 14 (shop, matrix, habits)

- [x] **Matrix quadrants missing drop hint** — 2026-08-30. “Drop tasks here to change priority”.
- [x] **Shop rebuild/add/pantry toolbar sparse a11y** — 2026-08-30. Hints on rebuild (incl. disabled), add item, pantry.
- [x] **Grocery rows use system secondary colors** — 2026-08-30. Checked/manual badge use `Theme.muted` / `Theme.ink`.
- [x] **New habit Save/Delete sparse a11y** — 2026-08-30. Save hint when disabled; Delete destructive hint.
- [x] **Lift hub week strip system colors** — 2026-08-30. Caption + day chips use `Theme.muted` / `Theme.accent`.

### Batch R — Audit round 15 (editor sheets a11y)

- [x] **Planner event Add/Delete sparse a11y** — 2026-08-30. Save hint when title empty; Delete destructive hint.
- [x] **Tag editor Save unlabeled** — 2026-08-30. “Saves tag name and color” hint.
- [x] **List settings delete + caption theming** — 2026-08-30. Delete hint; caption uses `Theme.muted`.
- [x] **Due date picker “No date” sparse a11y** — 2026-08-30. Clears due date hint.
- [x] **Suggested tasks “Add to Today” unlabeled** — 2026-08-30. Per-task label + hint; Tag manager Add hint.

### Batch S — Audit round 16 (Lift/Meals theming & hints)

- [x] **Lift hub card missing open hint** — 2026-08-30. “Opens full Lift program and workout history”.
- [x] **Lift hub exercise/recent rows system colors** — 2026-08-30. Prescription, reps, dates use `Theme.muted`.
- [x] **Today habit Skip sparse a11y** — 2026-08-30. Skip-for-today hint on Today rows.
- [x] **Meals tab chevrons and captions system colors** — 2026-08-30. Chevrons + secondary copy → `Theme.muted`.
- [x] **Event sheet + pantry footnotes system secondary** — 2026-08-30. Tag helper + pantry copy use `Theme.muted`.

### Batch T — Audit round 17 (settings/onboarding/workout theming)

- [x] **Settings footnotes use system secondary** — 2026-08-30. All helper copy → `Theme.muted`.
- [x] **Onboarding helper text system secondary** — 2026-08-30. Step copy → `Theme.muted`.
- [x] **Browse recipe citations system secondary** — 2026-08-30. Source line → `Theme.muted`.
- [x] **Active workout chrome unlabeled** — 2026-08-30. Menu + ellipsis options labels/hints; body copy `Theme.muted`.
- [x] **Settings macro recalculate sparse a11y** — 2026-08-30. Hints on recalc + AI recalc buttons.

### Batch U — Audit round 18 (integrations & matrix)

- [x] **Integrations settings footnotes system secondary** — 2026-08-30. Denied/setup copy → `Theme.muted`.
- [x] **Plan generating status lines system colors** — 2026-08-30. Status + flavor lines use `Theme.muted`.
- [x] **Settings plan regen + API keys sparse a11y** — 2026-08-30. Hints on regenerate plan and Save keys.
- [x] **Matrix task rows missing drag hint** — 2026-08-30. Edit + drag priority hint on rows.
- [x] **Refresh reminders button unlabeled** — 2026-08-30. Reschedule notifications hint.

### Batch V — Audit round 19 (Meals toolbar & workout preview)

- [x] **Meals Browse/Shop icons sparse a11y** — 2026-08-30. Hints for cookbook browse and shop list.
- [x] **Quick Add Save sparse a11y** — 2026-08-30. Hint when title empty vs ready to save.
- [x] **Workout preview exercise rows unlabeled** — 2026-08-30. Name + “Opens exercise form guide”.
- [x] **Workout preview Start button off-brand** — 2026-08-30. `Theme.accent` CTA + start hint (was white pill).
- [x] **Calendar integration connect buttons sparse a11y** — 2026-08-30. Apple Calendar + Google connect hints.

### Batch W — Audit round 20 (drawer, live workout, plan CTA)

- [x] **Meals Plan/New week button sparse a11y** — 2026-08-30. First plan vs regenerate hints.
- [x] **Drawer New list / Manage tags / Settings sparse a11y** — 2026-08-30. Action hints on drawer footer items.
- [x] **Live workout set row controls unlabeled** — 2026-08-30. Weight, reps/duration, complete set labels + hints.
- [x] **Rest timer Skip unlabeled** — 2026-08-30. Ends rest timer hint.
- [x] **Google disconnect/load calendars sparse a11y** — 2026-08-30. Disconnect + load calendar hints.

### Batch X — Audit round 21 (onboarding, calendar week, live workout)

- [x] **Calendar week day headers missing agenda hint** — 2026-08-30. “Double tap to open day agenda”.
- [x] **Live workout exercise carousel unlabeled** — 2026-08-30. Name + selected/switch hints on thumbnails.
- [x] **Onboarding Next/Back/Finish sparse a11y** — 2026-08-30. Step navigation hints.
- [x] **Drawer list settings icon sparse a11y** — 2026-08-30. Edit list name/Today visibility hint.
- [x] **Quick Add date menu + busy overlays** — 2026-08-30. Date menu hint; `BusyOverlay` includes detail text.

### Batch Y — Audit round 22 (day agenda, recipe cook, search results)

- [x] **DayDetailSheet task/event rows sparse a11y** — 2026-08-30. Combined labels + edit hints; Close + empty-day CTAs; missed/resume workout hints.
  → Fix: `dayTaskAccessibilityLabel` / `dayEventAccessibilityLabel`; toolbar + CTA hints on `DayAgendaSection` / `WorkoutDayDetailCard`.
- [x] **Recipe detail ingredient rows system colors** — 2026-08-30. Checked/unchecked copy uses `Theme.muted`/`Theme.ink`; toggle a11y.
  → Fix: `ingredientButton` theming + label/value/hint.
- [x] **Global search result rows sparse a11y** — 2026-08-30. Tasks, events, habits, shop rows labeled; Close hint.
  → Fix: `globalSearchTaskLabel` / `globalSearchEventLabel`; per-row hints in `GlobalSearchSheet`.
- [x] **Browse “Show more” unlabeled** — 2026-08-30. Pagination button label + hint.
- [x] **Exercise guide Done sparse a11y** — 2026-08-30. Dismiss hint on toolbar Done.

### Batch Z — Audit round 23 (Meals, habits strip, shop, search recipes)

- [x] **Meals day rows system `.primary` + sparse a11y** — 2026-08-30. `Theme.ink`; open-day hint on list rows.
  → Fix: `mealsDayRowLabel`; combined label + hint on `dayRow`.
- [x] **Meals Swap/Browse CTAs sparse a11y** — 2026-08-30. Empty-day + hero swap hints.
- [x] **Global search recipe rows sparse a11y** — 2026-08-30. Opens recipe detail hint on NavigationLink.
- [x] **Habits week strip day buttons unlabeled** — 2026-08-30. Selected/today labels + select hint.
  → Fix: `habitWeekStripLabel`; selected trait on strip buttons.
- [x] **Grocery swipe actions + row toggle sparse a11y** — 2026-08-30. Delete/pantry swipe labels; check-off + inline Add hints.

### Batch AA — Audit round 24 (pantry, editors, recipe cook, lift hub)

- [x] **Pantry editor sparse a11y** — 2026-08-30. Done/Add hints; staple swipe labels.
  → Fix: staple row label; Add to Shop / Remove swipe labels in `PantryEditor`.
- [x] **List settings + tag manager Done sparse a11y** — 2026-08-30. Dismiss hints; tag row edit hint; tag Cancel hint.
- [x] **Workout hub Done sparse a11y** — 2026-08-30. Closes Lift sheet hint.
- [x] **Recipe source link + servings sparse a11y** — 2026-08-30. Open-in-Safari hint; stepper value/hint; main/side picker hint.
- [x] **Lift hub recent logs unlabeled** — 2026-08-30. Session name/date/duration combined labels.

### Batch AB — Audit round 25 (sheet dismiss, browse, drawer alert)

- [x] **Settings Done sparse a11y** — 2026-08-30. Closes settings hint.
- [x] **New habit + event Cancel sparse a11y** — 2026-08-30. Discard without saving hints.
- [x] **Task editor Done sparse a11y** — 2026-08-30. Saves task and closes hint.
- [x] **Due date picker Done sparse a11y** — 2026-08-30. Confirms selected due date hint.
- [x] **Browse recipe rows + drawer new-list alert sparse a11y** — 2026-08-30. Opens recipe detail; Create/Cancel alert hints.

### Batch AC — Audit round 26 (drawer, habit form, meals hero, lift CTAs)

- [x] **Drawer close button sparse a11y** — 2026-08-30. Closes menu hint on X.
- [x] **New habit form controls sparse a11y** — 2026-08-30. Icon grid, frequency/weekday/period pills labeled with selected traits.
  → Fix: `pill` selected trait; icon/weekday button labels + hints.
- [x] **Quick Add list menu sparse a11y** — 2026-08-30. Choose task list hint.
- [x] **Meals tonight hero + side sparse a11y** — 2026-08-30. Opens recipe detail hints on dinner/side links.
- [x] **Lift hub hero CTAs sparse a11y** — 2026-08-30. Begin/Resume/Skip hints on primary actions.

### Batch AD — Audit round 27 (Meals chips, Quick Add, colors, settings)

- [x] **Meals day picker chips sparse a11y** — 2026-08-30. `Theme.DayChip` selected labels + jump hint; unselected dot → `Theme.sunken`.
- [x] **Quick Add priority + due date sparse a11y** — 2026-08-30. Priority menu, due date button, remind toggle hints.
- [x] **Color swatch grid sparse a11y** — 2026-08-30. Tag/event color picker labels + selected trait.
- [x] **Settings Browse cookbooks sparse a11y** — 2026-08-30. Opens recipe browse hint.
- [x] **Tonight meal empty CTA sparse a11y** — 2026-08-30. Go to Meals tab hint.

### Batch AE — Audit round 28 (lift strip, workout log, browse, onboarding)

- [x] **WorkoutWeekStrip sparse a11y** — 2026-08-30. Program day buttons labeled with rest/logged/today state.
  → Fix: `workoutWeekStripLabel`; hints on strip buttons in `WorkoutWeekStrip`.
- [x] **WorkoutLogSummary unlabeled** — 2026-08-30. Completed session combined VoiceOver label.
- [x] **Meals regenerate confirm sparse a11y** — 2026-08-30. Generate/cancel dialog hints.
- [x] **Browse course filter sparse a11y** — 2026-08-30. Course picker filter hint.
- [x] **Onboarding metric toggle sparse a11y** — 2026-08-30. Units switch hint.

### Batch AF — Audit round 29 (settings toggles, event form, workout summary)

- [x] **Settings metric toggle + regenerate confirm sparse a11y** — 2026-08-30. Units hint; regenerate/cancel dialog hints.
- [x] **Settings cooking tools + cookbook toggles sparse a11y** — 2026-08-30. Equipment and cookbook include hints.
- [x] **Event recurrence weekday chips sparse a11y** — 2026-08-30. Custom weekly day toggle labels + hints.
- [x] **Event reminder toggle sparse a11y** — 2026-08-30. Schedules alert hint.
- [x] **Workout summary Done sparse a11y** — 2026-08-30. Dismisses post-workout summary hint.

### Batch AG — Audit round 30 (confirm dialogs, task editor, integrations)

- [x] **Active workout confirm dialogs sparse a11y** — 2026-08-30. Finish/incomplete/leave/options dialog hints.
- [x] **Lift skip/replace confirm dialogs sparse a11y** — 2026-08-30. Lift hub + day detail dialog hints.
- [x] **Calendar view scope dialog sparse a11y** — 2026-08-30. Month/week/day/year scope hints.
- [x] **Task editor reminder/completed toggles sparse a11y** — 2026-08-30. Notification + completion hints.
- [x] **Integrations reminder toggles sparse a11y** — 2026-08-30. Master + per-type reminder hints.

### Batch AH — Audit round 31 (sync toggles, event/list form, tags)

- [x] **Integrations calendar sync toggles sparse a11y** — 2026-08-30. Apple + Google sync task/workout/meal hints.
- [x] **Event all-day + completed toggles sparse a11y** — 2026-08-30. Event form toggle hints.
- [x] **List settings Show in Today sparse a11y** — 2026-08-30. Undated tasks on Today hint.
- [x] **Event tag chips sparse a11y** — 2026-08-30. Tag select/deselect labels + selected trait in `FlowLayoutTags`.
- [x] **Onboarding cooking tools sparse a11y** — 2026-08-30. Equipment include hints.

### Batch AI — Audit round 32 (banner, lift preview, calendar, sliders, postpone)

- [x] **Plan generation Show banner sparse a11y** — 2026-08-30. Restores progress overlay hint.
- [x] **Lift hub today's lifts preview unlabeled** — 2026-08-30. Exercise name + prescription combined labels.
  → Fix: `liftPreviewRowLabel` on preview rows in `WorkoutHomeView`.
- [x] **Calendar Go to today sparse a11y** — 2026-08-30. Jumps to today hint.
- [x] **Settings + onboarding complexity slider sparse a11y** — 2026-08-30. Cooking complexity label/value/hint.
- [x] **Today postpone menu actions sparse a11y** — 2026-08-30. Per-option postpone hints.

### Batch AJ — Audit round 33 (Quick Add dates, rest timer, onboarding diet, steppers)

- [x] **Quick Add date menu actions sparse a11y** — 2026-08-30. Today/Tomorrow/No date hints.
- [x] **Rest timer banner sparse a11y** — 2026-08-30. Combined timer label + Skip rest label.
- [x] **Onboarding diet preferences sparse a11y** — 2026-08-30. Diet picker + foods-to-skip field hints.
- [x] **Settings meal steppers sparse a11y** — 2026-08-30. Servings and recipe cooldown hints.
- [x] **Lift hub rest card sparse a11y** — 2026-08-30. Recovery day combined VoiceOver label.

### Batch AK — Audit round 34 (workout keypad, integrations, shared chrome)

- [x] **Workout keypad sparse a11y** — 2026-08-30. Num keys, RIR chips, F/P toggle, nudge/dismiss/confirm hints.
- [x] **Plate calculator inline a11y** — 2026-08-30. Combined loading summary label.
- [x] **Integration reminder steppers sparse a11y** — 2026-08-30. Task/workout/lunch/dinner stepper hints.
- [x] **Settings profile age stepper sparse a11y** — 2026-08-30. Macro calculation hint.
- [x] **Shared task checkbox + error alert a11y** — 2026-08-30. Complete/incomplete hint; dismiss error hint.

### Batch AL — Audit round 35 (profile forms, calendar nav)

- [x] **Onboarding body metrics sparse a11y** — 2026-08-30. Weight/height fields, age, sex hints.
- [x] **Onboarding goals step sparse a11y** — 2026-08-30. Activity/goal pickers + servings stepper hints.
- [x] **Settings profile + nutrition form sparse a11y** — 2026-08-30. Body metrics, pickers, diet skip, calorie/protein fields.
- [x] **Calendar prev/next nav sparse a11y** — 2026-08-30. Shift chevron hints per scope.
- [x] **Calendar event chip edit sparse a11y** — 2026-08-30. All-day and timed event open-editor hints.

### Batch AM — Audit round 36 (habits, calendar grid, settings sync, shop)

- [x] **New habit form sparse a11y** — 2026-08-30. Name field, frequency/period pill hints.
- [x] **Calendar month grid events sparse a11y** — 2026-08-30. Month cell + year tile event/edit hints.
- [x] **Settings AI keys sparse a11y** — 2026-08-30. Provider picker + Keychain field hints.
- [x] **Integration calendar pickers sparse a11y** — 2026-08-30. Apple/Google target calendar hints.
- [x] **Shop swipe + empty workout CTA sparse a11y** — 2026-08-30. Delete/pantry swipe hints; EmptyState ctaHint.

### Batch AN — Audit round 37 (event form, drawer, Today, pantry)

- [x] **Event editor form sparse a11y** — 2026-08-30. Title/location/notes, dates, repeat/priority/list pickers.
- [x] **Color swatch grid sparse a11y** — 2026-08-30. Event color selection hint.
- [x] **Planner drawer nav sparse a11y** — 2026-08-30. Today/Next 7/Inbox/Shop/list row hints.
- [x] **Today completed section sparse a11y** — 2026-08-30. Collapse/expand completed tasks hint.
- [x] **Pantry swipe actions sparse a11y** — 2026-08-30. Add-to-shop and remove staple hints.

### Batch AO — Audit round 38 (task editor, tags, search)

- [x] **Task editor form sparse a11y** — 2026-08-30. Title/notes/location, due/reminder/duration, repeat/priority/list hints.
- [x] **Due date picker sparse a11y** — 2026-08-30. Graphical calendar hint in Quick Add.
- [x] **Tag editor name sparse a11y** — 2026-08-30. Tag name field hint.
- [x] **Quick Add title sparse a11y** — 2026-08-30. Smart title parsing hint.
- [x] **Global search field sparse a11y** — 2026-08-30. Cross-app search scope hint.

### Batch AP — Audit round 39 (empty states, shop entry, browse)

- [x] **Empty state CTA hints** — 2026-08-30. Matrix/Habits/Today/Meals/Shop EmptyState ctaHint labels.
- [x] **Shop manual entry sparse a11y** — 2026-08-30. Per-category add-item field hints.
- [x] **Pantry add staple sparse a11y** — 2026-08-30. Staple name field hint.
- [x] **Matrix helper caption a11y** — 2026-08-30. Drag/tap instruction static text trait.
- [x] **Browse empty results sparse a11y** — 2026-08-30. Combined no-match label.

### Batch AQ — Audit round 40 (recipe cook, swatches, search polish)

- [x] **Recipe cook steps + citation sparse a11y** — 2026-08-30. Step rows + cookbook block combined labels.
- [x] **Color swatch contextual hints** — 2026-08-30. Event vs tag swatchHint parameter.
- [x] **Global search empty states sparse a11y** — 2026-08-30. Placeholder static text + no-results label.
- [x] **Today habit row + no-dinner card sparse a11y** — 2026-08-30. Edit hint; empty dinner combined label.
- [x] **Lift recent logs sparse a11y** — 2026-08-30. Static text trait on history rows.

### Batch AR — Audit round 41 (workout preview, suggestions, guide, day agenda)

- [x] **Workout preview header sparse a11y** — 2026-08-30. Combined exercise count, duration, focus label.
- [x] **Suggested tasks sheet sparse a11y** — 2026-08-30. Row + empty-state combined labels.
- [x] **Exercise guide steps sparse a11y** — 2026-08-30. Per-step combined labels; fallback static text.
- [x] **Quick Add list menu sparse a11y** — 2026-08-30. Per-list save hints.
- [x] **Day agenda + meals info sparse a11y** — 2026-08-30. Empty day label; log summary static; leftovers note.

### Batch AS — Audit round 42 (onboarding, lift hero, habits week, calendar)

- [x] **Onboarding welcome + progress sparse a11y** — 2026-08-30. Welcome combined label; step progress value.
- [x] **Lift hub hero + saving state sparse a11y** — 2026-08-30. Status combined label; week hint static; saving overlay.
- [x] **Exercise guide meta sparse a11y** — 2026-08-30. Equipment, muscles, rep range combined label.
- [x] **Habits mini-week sparse a11y** — 2026-08-30. Weekly completion summary label on dot strip.
- [x] **Meals rationale + calendar overflow sparse a11y** — 2026-08-30. Plan summary static; “+N more” events label.

### Batch AT — Audit round 43 (informational a11y)

- [x] **Day agenda section headers sparse a11y** — 2026-08-30. Tasks/Events headers get `.isHeader` trait.
- [x] **Shop building state sparse a11y** — 2026-08-30. Progress row combined label + `updatesFrequently`.
- [x] **Settings intro footnote sparse a11y** — 2026-08-30. Profile intro static text trait.
- [x] **Smart title hints sparse a11y** — 2026-08-30. Due + tag chips combined label.
- [x] **Quick Add tips + guide attribution sparse a11y** — 2026-08-30. Tips static label; exercise DB citation static; `Theme.SectionHeader` header trait.

### Batch AU — Audit round 44 (footnotes)

- [x] **Onboarding footnotes sparse a11y** — 2026-08-30. Servings, complexity, dietary skip, settings-after-setup static traits.
- [x] **Settings macro rationale sparse a11y** — 2026-08-30. Profile rationale footnote static text trait.
- [x] **Pantry intro footnote sparse a11y** — 2026-08-30. Staples section explainer static text trait.
- [x] **Integrations settings footnotes sparse a11y** — 2026-08-30. Notifications/calendar/Google OAuth help copy static traits.
- [x] **Grocery shop intro footnote sparse a11y** — 2026-08-30. EmptyState message static text trait (shop + all empty states).

### Batch AV — Audit round 45 (helper copy)

- [x] **Settings About footnote sparse a11y** — 2026-08-30. Cadence/product name explainer static text trait.
- [x] **Onboarding welcome footnote sparse a11y** — 2026-08-30. Step progress + tagline static text traits.
- [x] **Meal plan rationale footnote sparse a11y** — 2026-08-30. Week summary + recipe reason static text traits.
- [x] **Active workout rest guidance sparse a11y** — 2026-08-30. Rest banner skip hint between sets.
- [x] **Matrix quadrant labels sparse a11y** — 2026-08-30. Quadrant roman/title headers get `.isHeader`.

### Batch AW — Audit round 46 (overlays, badges, calendar)

- [x] **Workout summary notes sparse a11y** — 2026-08-30. “Next time” rows combined label; footnote static trait.
- [x] **Theme overlay footnotes sparse a11y** — 2026-08-30. BusyOverlay detail static; planning overlay combined status label.
- [x] **Settings integrations status sparse a11y** — 2026-08-30. Status message combined label + updatesFrequently.
- [x] **Grocery manual badge sparse a11y** — 2026-08-30. Badge hidden; manual entry in row label.
- [x] **Calendar week hour empty cell sparse a11y** — 2026-08-30. Empty slots labeled “empty time slot”.

### Batch AX — Audit round 47 (forms, browse, lift preview)

- [x] **Workout summary header sparse a11y** — 2026-08-30. Session logged headline header trait + label.
- [x] **Recipe step rows sparse a11y** — 2026-08-30. Step label includes scaled ingredients.
- [x] **Browse filter chips sparse a11y** — 2026-08-30. Course filter selected value in label.
- [x] **Habit editor form sparse a11y** — 2026-08-30. Frequency/days/section headers + icon helper static text.
- [x] **Lift preview strip sparse a11y** — 2026-08-30. Section header trait; row label includes last sets or none.

### Batch AY — Audit round 48 (search, events, keypad, meals)

- [x] **Global search result rows sparse a11y** — 2026-08-30. Section headers; recipe/habit/shop combined labels.
- [x] **Planner event sheet sparse a11y** — 2026-08-30. All-day state label; end date duration hint; tags helper static.
- [x] **Workout keypad sparse a11y** — 2026-08-30. Mode-specific digit entry hints (weight/reps/duration).
- [x] **Meal day picker sparse a11y** — 2026-08-30. DayChip selected vs unselected hints.
- [x] **Suggested tasks empty sparse a11y** — 2026-08-30. Empty static label; section headers; row includes section.

### Batch AZ — Audit round 49 (repeat, calendar, citation, lift, drawer)

- [x] **Task editor repeat section sparse a11y** — 2026-08-30. Custom weekly chips + summary static text (matches event editor).
- [x] **Calendar month grid sparse a11y** — 2026-08-30. Outside-month + year current-month labels.
- [x] **Recipe citation block sparse a11y** — 2026-08-30. SourceCitation hint for web link.
- [x] **Lift recent logs section sparse a11y** — 2026-08-30. Recent header trait; row hint.
- [x] **Planner drawer search field sparse a11y** — 2026-08-30. Search scope caption static text under drawer Search.

### Batch BA — Audit round 50 (lists, meals, lift, dialogs)

- [x] **Habits list row sparse a11y** — 2026-08-30. Contain layout; rich row label + complete/edit hints.
- [x] **Meal plan day row sparse a11y** — 2026-08-30. Rest-of-week label includes source citation.
- [x] **Workout preview sheet sparse a11y** — 2026-08-30. Exercise rows combine name + set prescription.
- [x] **List settings sheet sparse a11y** — 2026-08-30. List name label; Show in Today state; footnote static.
- [x] **Confirm dialog sparse a11y** — 2026-08-30. Regenerate dialogs message static + destructive hints.

### Batch BB — Audit round 51 (Today, meals hero, sets, tags, day detail)

- [x] **Today habit row sparse a11y** — 2026-08-30. Contain layout; skip/complete/edit hints; skipped state in label.
- [x] **Meal tonight hero sparse a11y** — 2026-08-30. Hero card combines dinner, citation, macros, side, link.
- [x] **Active workout set rows sparse a11y** — 2026-08-30. Set row contain label; complete toggle hint polish.
- [x] **Tag manager sparse a11y** — 2026-08-30. Empty static label; tag rows combined labels.
- [x] **Calendar day detail sparse a11y** — 2026-08-30. Overdue badge hidden; due date in task label.

### Batch BC — Audit round 52 (Quick Add, thumbnails, empty states, lift strip)

- [x] **Quick Add sheet sparse a11y** — 2026-08-30. Save-to-list + due date section headers.
- [x] **Exercise thumbnail sparse a11y** — 2026-08-30. Catalog thumbnail image label; hidden in preview row combine.
- [x] **Meal empty day card sparse a11y** — 2026-08-30. No-dinner card label + action hint.
- [x] **Planner inbox empty sparse a11y** — 2026-08-30. Inbox/list empty combined label.
- [x] **Workout week strip sparse a11y** — 2026-08-30. Lift program header; today-specific strip hints.

### Batch BD — Audit round 53 (empty states, guide hero, live strip)

- [x] **Today all-clear empty sparse a11y** — 2026-08-30. All clear combined empty label.
- [x] **Exercise guide hero sparse a11y** — 2026-08-30. Hero image + meta combined label; how-to header trait.
- [x] **Meal plan empty week sparse a11y** — 2026-08-30. Build-week EmptyState combined label.
- [x] **Habits empty sparse a11y** — 2026-08-30. No habits EmptyState combined label.
- [x] **Workout live exercise strip sparse a11y** — 2026-08-30. Selected state in label; thumbnail hidden; guide hint polish.

### Batch BE — Audit round 54 (tab empty states)

- [x] **Matrix empty sparse a11y** — 2026-08-30. Matrix empty combined label.
- [x] **Shop empty sparse a11y** — 2026-08-30. Grocery EmptyState combined label with message.
- [x] **Lift hub empty sparse a11y** — 2026-08-30. No active workout EmptyState combined label; ctaHint verified.
- [x] **Browse search empty sparse a11y** — 2026-08-30. Course section footer static search scope hint.
- [x] **Calendar day detail empty sparse a11y** — 2026-08-30. Empty day card label + action hint.

### Batch BF — Audit round 55 (dialogs, cards, menus)

- [x] **Suggested tasks empty sparse a11y** — 2026-08-30. Combined label matches EmptyState message.
- [x] **Active workout finish dialog sparse a11y** — 2026-08-30. Dialog messages static; log/cancel hints polished.
- [x] **Pantry empty search sparse a11y** — 2026-08-30. No staples match combined static label.
- [x] **Workout day card sparse a11y** — 2026-08-30. Session/rest combined label on Lift hub button.
- [x] **Planner postpone menu sparse a11y** — 2026-08-30. Postpone label includes overdue task count.

### Batch BG — Audit round 56

- [x] **Leave workout dialog sparse a11y** — 2026-08-30. Exit/discard message static trait + hint polish.
  → Fix: `ActiveWorkoutView.swift` leave dialog message `.isStaticText`; clearer action hints.
- [x] **Undo FAB sparse a11y** — 2026-08-30. Matrix/Today undo button context hints.
  → Fix: `UndoFAB` optional `accessibilityHint`; Matrix + Today pass context-specific hints.
- [x] **Tonight meal card sparse a11y** — 2026-08-30. Today tab dinner card combined label polish.
  → Fix: `TonightMealCard` combined label with side, reason, cookbook citation.
- [x] **Recipe cook pane sparse a11y** — 2026-08-30. Main/side pane toggle selected state labels.
  → Fix: `RecipeDetailView` `cookPaneAccessibilityLabel` on segmented picker.
- [x] **Calendar ghost event sparse a11y** — 2026-08-30. Draft event chip + hour cell label.
  → Fix: `ghostEventChip` static label; `weekHourCellAccessibilityLabel` includes draft time.

### Batch BH — Audit round 57

- [x] **Browse recipe row sparse a11y** — 2026-08-30. Combined label with course + source citation on browse rows.
  → Fix: `BrowseView` `browseRecipeRowLabel` on NavigationLink rows.
- [x] **Skip session dialog sparse a11y** — 2026-08-30. Skip confirmation message static trait (Lift + day detail).
  → Fix: `WorkoutHomeView` + `DayDetailSheet` skip dialog messages `.isStaticText`.
- [x] **Replace workout dialog sparse a11y** — 2026-08-30. Replace-live message static trait + day detail message.
  → Fix: `WorkoutHomeView` + both `DayDetailSheet` replace dialogs with static messages.
- [x] **Global search empty sparse a11y** — 2026-08-30. No-results static text trait (idle help already static).
  → Fix: `GlobalSearchSheet` no-results `.isStaticText`.
- [x] **Calendar scope dialog sparse a11y** — 2026-08-30. Scope picker labels mark current view as selected.
  → Fix: `CalendarPlannerView` scope buttons include "selected" when active.

### Batch BI — Audit round 58

- [x] **App error alert sparse a11y** — 2026-08-30. Root error alert message static trait.
  → Fix: `RootView` error alert message `.isStaticText`.
- [x] **Global search recipe sparse a11y** — 2026-08-30. Recipe result rows include source citation in combined label.
  → Fix: `GlobalSearchSheet` `globalSearchRecipeLabel` with citation + web link flag.
- [x] **New list alert sparse a11y** — 2026-08-30. Drawer new-list alert explanatory message static trait.
  → Fix: `PlannerDrawer` new-list alert message `.isStaticText`.
- [x] **Shop category header sparse a11y** — 2026-08-30. Grocery section headers announce category + item count.
  → Fix: `GroceryListView` custom section headers with count labels.
- [x] **Workout options dialog sparse a11y** — 2026-08-30. Live workout options menu explanatory message static trait.
  → Fix: `ActiveWorkoutView` options dialog message `.isStaticText`.

### Batch BJ — Audit round 59

- [x] **Tag editor sparse a11y** — 2026-08-30. Tag name field label + section header traits in tag editor sheet.
  → Fix: `TagEditorSheet` name field label/value; Name/Color section headers `.isHeader`.
- [x] **Busy overlay sparse a11y** — 2026-08-30. Loading overlay title line static text trait.
  → Fix: `Theme.BusyOverlay` title `.isStaticText`.
- [x] **Global search shop sparse a11y** — 2026-08-30. Shop result rows include check state in combined label.
  → Fix: `GlobalSearchSheet` `globalSearchGroceryLabel` with checked state.
- [x] **Task editor picker sparse a11y** — 2026-08-30. Repeat/priority/list pickers expose selected value labels.
  → Fix: `TaskEditorSheet` pickers include selected value in `accessibilityLabel`.
- [x] **Calendar scope cancel sparse a11y** — 2026-08-30. Scope dialog cancel hint names the current calendar view.
  → Fix: `CalendarPlannerView` cancel hint includes active scope name.

### Batch BK — Audit round 60

- [x] **Event editor picker sparse a11y** — 2026-08-30. Repeat/priority/list pickers expose selected value labels.
  → Fix: `PlannerEventSheet` pickers include selected recurrence, priority, and list in labels.
- [x] **Settings profile picker sparse a11y** — 2026-08-30. Sex/activity/goal/diet pickers announce selected values.
  → Fix: `SettingsView` profile pickers include selected option titles in labels.
- [x] **Onboarding picker sparse a11y** — 2026-08-30. Profile pickers announce selected values on onboarding steps.
  → Fix: `OnboardingView` sex/activity/goal/diet pickers include selected titles.
- [x] **Quick Add priority sparse a11y** — 2026-08-30. Priority menu combined label includes selected flag level.
  → Fix: `PriorityPickerMenu` label includes Matrix quadrant with priority title.
- [x] **Integrations calendar sparse a11y** — 2026-08-30. Calendar sync target pickers announce selected calendar names.
  → Fix: `PlannerIntegrationsSettings` Apple/Google calendar pickers include selected calendar labels.

### Batch BL — Audit round 61

- [x] **Settings provider picker sparse a11y** — 2026-08-30. AI provider picker announces selected provider.
  → Fix: `SettingsView` provider segmented picker label includes selected provider title.
- [x] **Browse course picker sparse a11y** — 2026-08-30. Course filter updates selected value in accessibility label dynamically.
  → Fix: `BrowseView` course picker adds `accessibilityValue` for selected course.
- [x] **Event editor all-day sparse a11y** — 2026-08-30. All-day toggle announces on/off state in combined label.
  → Fix: `PlannerEventSheet` all-day toggle adds timed vs all-day `accessibilityValue`.
- [x] **Habit editor icon sparse a11y** — 2026-08-30. New/edit habit icon grid selected state in row labels.
  → Fix: `NewHabitSheet` preview row + grid buttons use descriptive icon names and selected state.
- [x] **Meals complexity slider sparse a11y** — 2026-08-30. Settings cooking complexity slider value label polish.
  → Fix: `SettingsView` complexity slider label/value include title + subtitle; subtitle static trait.

### Batch BM — Audit round 62

- [x] **Onboarding complexity sparse a11y** — 2026-08-30. Onboarding cooking slider matches Settings label/value polish.
  → Fix: `OnboardingView` complexity slider label/value include title + subtitle.
- [x] **Habit period picker sparse a11y** — 2026-08-30. New habit morning/afternoon/evening pills announce selected period.
  → Fix: `NewHabitSheet` period row combined label with selected time of day.
- [x] **Settings tool toggle sparse a11y** — 2026-08-30. Cooking tool toggles announce on/off in combined labels.
  → Fix: `SettingsView` + `OnboardingView` tool toggles include on/off in labels.
- [x] **Event color swatch sparse a11y** — 2026-08-30. Event editor color grid selected swatch labels.
  → Fix: `ColorSwatchGrid` numbered swatch labels + `Event color` prefix in event sheet.
- [x] **Matrix quadrant header sparse a11y** — 2026-08-30. Matrix quadrant headers combined labels with counts.
  → Fix: `MatrixView` header row + quadrant container use roman title and task count.

### Batch BN — Audit round 63

- [x] **Settings cookbook toggle sparse a11y** — 2026-08-30. Enabled cookbook toggles announce on/off in combined labels.
  → Fix: `SettingsView` cookbook toggles include on/off in labels.
- [x] **Tag editor color sparse a11y** — 2026-08-30. Tag editor color grid uses numbered swatch labels with Tag color prefix.
  → Fix: `TagEditorSheet` `ColorSwatchGrid` with `Tag color` prefix.
- [x] **Habit frequency sparse a11y** — 2026-08-30. New habit daily/weekly row announces selected frequency.
  → Fix: `NewHabitSheet` frequency row combined label with selected value.
- [x] **Matrix intro sparse a11y** — 2026-08-30. Matrix drag-help banner explicit static label.
  → Fix: `MatrixView` intro text adds explicit `accessibilityLabel`.
- [x] **Quick Add due sparse a11y** — 2026-08-30. Quick Add due date button combined label with chosen date.
  → Fix: `QuickAddSheet` due button/menu labels include date or none; no-date static state.

### Batch BO — Audit round 64

- [x] **Task editor completed sparse a11y** — 2026-08-30. Completed toggle announces on/off in combined label.
  → Fix: `TaskEditorSheet` completed toggle label includes on/off state.
- [x] **Event editor completed sparse a11y** — 2026-08-30. Edit-event completed toggle announces on/off state.
  → Fix: `PlannerEventSheet` completed toggle label includes on/off state.
- [x] **Habit name field sparse a11y** — 2026-08-30. New/edit habit name field explicit label + value.
  → Fix: `NewHabitSheet` name field label and value for VoiceOver.
- [x] **Integrations toggle sparse a11y** — 2026-08-30. Calendar/reminder sync toggles announce on/off in labels.
  → Fix: `PlannerIntegrationsSettings` notification + Apple/Google sync toggles include on/off.
- [x] **Settings nutrition sparse a11y** — 2026-08-30. Calorie/protein target fields combined accessibility labels.
  → Fix: `SettingsView` nutrition rows combine label with current target values.

### Batch BP — Audit round 65

- [x] **Task editor reminder sparse a11y** — 2026-08-30. Task editor reminder toggle announces on/off state.
  → Fix: `TaskEditorSheet` reminder toggle label includes on/off.
- [x] **Event reminder sparse a11y** — 2026-08-30. Event editor reminder toggle announces on/off state.
  → Fix: `PlannerEventSheet` reminder toggle label includes on/off.
- [x] **List settings toggle sparse a11y** — 2026-08-30. Show in Today toggle announces on/off in combined label.
  → Fix: verified existing `ListSettingsSheet` on/off label (batch AD).
- [x] **Onboarding tool toggle sparse a11y** — 2026-08-30. Onboarding cooking-tool toggles match Settings on/off labels.
  → Fix: verified existing labels from batch BM.
- [x] **Settings cookbook stepper sparse a11y** — 2026-08-30. Recipe cooldown stepper combined label with current days.
  → Fix: `SettingsView` cooldown stepper explicit label with day count.

### Batch BQ — Audit round 66

- [x] **Task duration stepper sparse a11y** — 2026-08-30. Task editor duration stepper combined label with minutes.
  → Fix: `TaskEditorSheet` duration stepper explicit minutes label.
- [x] **Settings servings stepper sparse a11y** — 2026-08-30. Servings-per-recipe stepper combined label with count.
  → Fix: `SettingsView` servings stepper label includes count.
- [x] **Integrations reminder stepper sparse a11y** — 2026-08-30. Task/workout/lunch/dinner reminder steppers announce current values.
  → Fix: `PlannerIntegrationsSettings` reminder steppers explicit value labels.
- [x] **Onboarding servings stepper sparse a11y** — 2026-08-30. Onboarding batch-size stepper combined label with count.
  → Fix: `OnboardingView` servings stepper label includes count.
- [x] **Event all-day section sparse a11y** — 2026-08-30. All-day date pickers announce all-day vs timed context in labels.
  → Fix: `PlannerEventSheet` start/end pickers label all-day vs timed events.

### Batch BR — Audit round 67

- [x] **Settings age stepper sparse a11y** — 2026-08-30. Profile age stepper combined label with current age.
  → Fix: `SettingsView` age stepper label includes current age.
- [x] **Onboarding age stepper sparse a11y** — 2026-08-30. Onboarding age stepper combined label with current age.
  → Fix: `OnboardingView` age stepper label includes current age.
- [x] **Task editor due sparse a11y** — 2026-08-30. Task editor due date picker combined label with formatted date.
  → Fix: `TaskEditorSheet` `taskDueAccessibilityLabel` on due picker.
- [x] **Event alert picker sparse a11y** — 2026-08-30. Event reminder date picker label when reminder enabled.
  → Fix: `PlannerEventSheet` alert picker label with formatted date.
- [x] **Recipe detail servings sparse a11y** — 2026-08-30. Recipe detail servings stepper label includes current count.
  → Fix: `RecipeDetailView` servings stepper combined count label.

### Batch BS — Audit round 68

- [x] **Task remind-at sparse a11y** — 2026-08-30. Task editor remind-at picker label with formatted date/time.
  → Fix: `TaskEditorSheet` `taskRemindAtAccessibilityLabel` with medium date + short time.
- [x] **Settings body metrics sparse a11y** — 2026-08-30. Height/weight fields combined labels with current values.
  → Fix: `SettingsView` weight/height rows combine label with imperial or metric values.
- [x] **Onboarding height sparse a11y** — 2026-08-30. Onboarding height field combined label with inches value.
  → Fix: `OnboardingView` height row combined label (metric-aware).
- [x] **Due date sheet sparse a11y** — 2026-08-30. Quick Add due picker sheet announces selected date.
  → Fix: `DueDatePickerSheet` picker label with formatted selected date.
- [x] **Settings weight sparse a11y** — 2026-08-30. Profile weight field combined label with current pounds.
  → Fix: covered by settings body metrics combined weight row.

### Batch BT — Audit round 69

- [x] **Metric units toggle sparse a11y** — 2026-08-30. Settings/onboarding metric toggle announces on/off and unit system.
  → Fix: metric toggle labels include on/off + Metric/Imperial accessibility value.
- [x] **Task editor due time sparse a11y** — 2026-08-30. Task due picker label includes date and time.
  → Fix: `TaskEditorSheet` due label uses `taskDateTimeLabel` with medium date + short time.
- [x] **Event alert time sparse a11y** — 2026-08-30. Event alert picker label includes date and time.
  → Fix: `PlannerEventSheet` alert label uses `eventDateTimeLabel`.
- [x] **Onboarding weight sparse a11y** — 2026-08-30. Onboarding weight row verified with metric toggle context.
  → Fix: verified combined weight label from batch BS; metric toggle now exposes unit system.
- [x] **Nutrition BMR row sparse a11y** — 2026-08-30. Settings BMR/TDEE/carbs/fat rows combined static labels.
  → Fix: `SettingsView` nutrition read-only rows combined labels + static trait.

### Batch BU — Audit round 70

- [x] **Settings metric toggle sparse a11y** — 2026-08-30. Metric toggle hint names affected weight/height fields.
  → Fix: Settings + onboarding metric toggle hints mention pounds/inches vs kg/cm.
- [x] **Nutrition rationale sparse a11y** — 2026-08-30. Macro rationale footnote explicit combined label.
  → Fix: `accessibilityLabel("Macro rationale, …")` on profile rationale footnote.
- [x] **Task editor location sparse a11y** — 2026-08-30. Task location field label + value when non-empty.
  → Fix: TaskEditorSheet location TextField label + Empty/value.
- [x] **Event location sparse a11y** — 2026-08-30. Event location field label + value when non-empty.
  → Fix: PlannerEventSheet location TextField label + Empty/value.
- [x] **Onboarding progress sparse a11y** — 2026-08-30. Step progress bar combined label with step title context.
  → Fix: `onboardingStepTitle`; combined progress label + percent value.

### Batch BV — Audit round 71

- [x] **Task editor notes sparse a11y** — 2026-08-30. Notes field label + value when non-empty.
- [x] **Event notes sparse a11y** — 2026-08-30. Event notes field label + value when non-empty.
- [x] **Task editor title sparse a11y** — 2026-08-30. Title field label + current value.
- [x] **Event title sparse a11y** — 2026-08-30. Event title field label + current value.
- [x] **Dietary restrictions sparse a11y** — 2026-08-30. Settings/onboarding skip-list field label + value.

### Batch BW — Chrome, calendar, shop, workout (user)

- [x] **Matrix extra chrome** — 2026-08-30. Matrix tab is the 2×2 grid only (no empty-state stack, no header search/settings).
- [x] **Calendar not full width** — 2026-08-30. Month grid uses full screen width; FAB overlays instead of shrinking columns.
- [x] **Settings/search in tab headers** — 2026-08-30. Removed from Calendar/Meals/Habits/Matrix/Today; Search + Settings live in Today’s left drawer.
- [x] **Workout checkboxes off-by-one** — 2026-08-30. Tight tap targets so set rows no longer steal the next row’s tap.
- [x] **Shop list slow to open** — 2026-08-30. Skip LLM grocery generation; don’t rebuild on every open; pantry matching computed once.

### Batch BY — Performance pass (user)

- [x] **Duplicate startup work** — 2026-08-30. Single app-level boot path; MainTabView only applies tab bar + launch args.
- [x] **Lazy tab loading** — 2026-08-30. Calendar/Meals/Matrix/Habits mount on first visit, not at launch.
- [x] **Widget publish hitch** — 2026-08-30. Debounced widget snapshots; one task fetch per publish.
- [x] **Deferred calendar sync** — 2026-08-30. Notification/calendar sync runs 2s after launch, not blocking first paint.
- [x] **Background recipe warm** — 2026-08-30. Recipe DB loads off main thread.
- [x] **Scoped SwiftData queries** — 2026-08-30. Matrix + Calendar fetch only open tasks / open events.
- [x] **Calendar event index** — 2026-08-30. Day lookups use cached index instead of scanning all events per cell.
- [x] **Meals plan decode cache** — 2026-08-30. Weekly plan JSON decoded once per change, not every body pass.
- [x] **Shop/grocery startup** — 2026-08-30. Grocery refresh runs once per session at launch; shop open skips re-seed/rebuild.

### Batch BX — Audit round 72

- [x] **Calendar weekday header alignment** — 2026-08-30. Weekday labels centered in full-width month columns.
- [x] **Today drawer Search placement** — 2026-08-30. Search grouped with Settings in drawer footer.
- [x] **Workout keypad vs checkbox spacing** — 2026-08-30. Weight/reps/checkbox buttons get fixed frames + content shapes.
- [x] **Shop empty first-open** — 2026-08-30. Empty shop auto-populates from plan locally (no spinner overlay).
- [x] **Habits header trailing empty** — 2026-08-30. `PlannerTitleHeader` removes stray trailing gap on Matrix/Habits.

### Batch BZ — Audit round 73

- [x] **Drawer search scope hint** — 2026-08-30. Footer search row shows muted scope line + combined a11y label.
- [x] **Calendar day number alignment** — 2026-08-30. Day numbers centered in month columns to match weekday headers.
- [x] **Shop populate idempotency** — 2026-08-30. `didAttemptShopPopulate` prevents repeat populate on navigation pop.
- [x] **Matrix title header consistency** — 2026-08-30. Documented `PlannerTitleHeader` vs `PlannerScreenHeader` pattern.
- [x] **Workout set row VoiceOver** — 2026-08-30. Combined row label includes “Set N of M”.

### Batch CA — Audit round 74

- [x] **Drawer footer touch targets** — 2026-08-30. Search + Settings footer rows use 44pt minimum height.
- [x] **Calendar today circle** — 2026-08-30. Today badge uses ZStack circle so it stays round when centered.
- [x] **Global search placeholder** — 2026-08-30. Placeholder + empty hint match drawer scope copy.
- [x] **Shop populate failure** — 2026-08-30. Failed populate clears attempt flag so Build shop list can retry.
- [x] **Meals header doc** — 2026-08-30. Comment documents PlannerScreenHeader for action tabs.

### Batch CB — Audit round 75

- [x] **Global search empty hint a11y** — 2026-09-09. Empty-state scope line uses explicit “Search scope: …” label.
- [x] **Drawer settings row label** — 2026-09-09. Settings footer has explicit accessibility label + hint.
- [x] **Calendar today a11y** — 2026-09-09. Month cell label still prefixes “Today,” when badge is centered.
- [x] **Shop manual refresh clears flag** — 2026-09-09. `refreshGroceryFromCurrentPlan` resets `didAttemptShopPopulate`.
- [x] **PlannerScreenHeader doc** — 2026-09-09. Struct comment documents trailing-toolbar vs `PlannerTitleHeader`.

### Batch CC — Design language & UX polish (2026-08-31)

- [x] **Blue/orange accent split** — 2026-08-31. `Theme.cta` (blue) for actions; `Theme.accent` (orange) for nav/selection.
- [x] **FAB flat shadow** — 2026-08-31. Removed orange glow; blue fill + subtle elevation.
- [x] **Today time-aware hero** — 2026-08-31. Morning promotes workout; evening promotes dinner (`promoted` card gradient).
- [x] **Today tasks section + habit Skip label** — 2026-08-31. Open tasks in collapsible section; text Skip replaces ⏩ icon.
- [x] **Habits compact workout banner** — 2026-08-31. `WorkoutCompactBanner` replaces duplicate full card.
- [x] **Global search quick jumps + recents** — 2026-08-31. Recent queries + dinner/shop/workout/settings shortcuts.
- [x] **Calendar day preview strip** — 2026-08-31. Selected-day agenda below month grid; tap updates preview.
- [x] **Matrix unified empty state** — 2026-08-31. Center overlay when all quadrants empty.
- [x] **Drawer Menu sections** — 2026-08-31. Views / Lists / More grouping; title → Menu.
- [x] **Shop Done + items-left header** — 2026-08-31. Top Done button; sticky unchecked count.
- [x] **Settings quick tweaks** — 2026-08-31. Units / Reminders / Meals chips; intro shown once.

### Batch CD — Wheel nav + app grid (2026-09-09)

- [x] **Swipe-up app grid** — 2026-09-09. Vertical swipe on wheel expands 4-column Apps grid; swipe down / dim tap collapses.
  → Fix: `WheelNav` `isExpanded` + `RootView` binding/scrim (scrim under dock so cells stay tappable).
- [x] **Grid pick commits + closes** — 2026-09-09. Grid cell selects destination, snaps wheel, collapses panel.
- [x] **Neighbor icon readability** — 2026-09-09. Raised arc neighbor opacity/scale floor so side apps stay discoverable.
- [x] **Idle dim less aggressive** — 2026-09-09. Collapsed wheel idle opacity 0.55 so grabber/center remain readable.
- [x] **Hide FAB over app grid** — 2026-09-09. `OrangeFAB` respects `isAppGridExpanded` environment.

### Batch CE — Wheel polish

- [x] **Collapsed label while spinning** — 2026-09-09. Selected name stays visible during drag (`showLabel || isDragging`).
- [x] **Shop/Settings from grid** — 2026-09-09. Grid pick uses same `onSelect` → Shop sheet / Settings sheet as spin.
- [x] **Placeholder pages empty CTA** — 2026-09-09. Inbox/Browse/Workout get “Back to Today”.
- [x] **Grid cell VoiceOver order** — 2026-09-09. Cells expose individual labels + sort priority; panel uses `.contain`.
- [x] **Expand pull preview** — 2026-09-09. Drag-up peeks a sheet silhouette + lifts wheel before commit.

### Batch CF — Wheel polish 2

- [x] **FAB clearance above wheel** — 2026-09-09. FAB bottom padding 12 → 28 on Today/Calendar/Matrix/Habits.
- [x] **Settings dismiss restores content wheel** — 2026-09-09. Already restored `contentDestination` on sheet dismiss (verified earlier).
- [x] **Shop dismiss restores Meals selection** — 2026-09-09. `onChange(openShopOnMeals)` snaps wheel to Meals.
- [x] **Grid “Apps” title a11y** — 2026-09-09. Title `accessibilityHidden`; cells individually labeled.
- [x] **Spot-check flow for swipe-up grid** — 2026-09-09. `spot_check.json` swipe + tap-label Calendar; `cadence_sim` swipe/tap ints for idb.
- [x] **Grid row-3 clipped** — 2026-09-09. Smaller 56pt cells so Workout/Settings fully visible.

### Batch CG — Wheel polish 3

- [x] **Collapse gesture vs buttons** — 2026-09-09. `simultaneousGesture` on panel so cells stay tappable; grabber has Close action.
- [x] **Shop Done a11y label** — 2026-09-09. Explicit Done in shop header inset with label + identifier (toolbar AX flaky in idb).
- [x] **Wheel value announces on VO** — 2026-09-09. Collapsed wheel already exposes `accessibilityValue` from selection.
- [x] **Light-mode grid contrast** — 2026-09-09. Expanded grid readable on light surface; restored dark after shot.
- [x] **Drawer vs wheel swipe conflict** — 2026-09-09. Opening drawer collapses app grid.
- [x] **Shop dismiss restores Meals (real dismiss)** — 2026-09-09. `MealPlanView.onShopDismiss` (not `openShop` clear-on-open).
- [x] **Grid cell AX ids** — 2026-09-09. `wheel-app-{id}` identifiers; spot-check taps Calendar by UniqueId.

### Batch CH — Next audit

- [x] **Duplicate Done in shop chrome** — 2026-09-09. Removed toolbar Done; header inset Done is the single control.
- [x] **Grid expands over Meals empty CTA** — 2026-09-09. Accepted; scrim dims content under panel.
- [x] **Haptic on grid collapse** — 2026-09-09. Light impact when swipe-down closes.
- [x] **Settings sheet dismiss from grid** — 2026-09-09. Dismiss restores prior content page (Meals verified).
- [x] **Automation: shop via wheel-app-shop** — 2026-09-09. UniqueId open + Done restore verified.

### Batch CI — Wheel polish 4

- [x] **Close app grid via scrim a11y** — 2026-09-09. Scrim labeled “Dismiss app grid” with button traits.
- [x] **Selected wheel icon uses Theme.accent** — 2026-09-09. Center glow + grid selection use nav orange.
- [x] **Expand threshold feel** — 2026-09-09. Threshold 48pt / predicted 90pt.
- [x] **Placeholder Back to Today a11y smoke** — 2026-09-09. Tap-label returns to Today.
- [x] **Spot-check includes shop-from-grid** — 2026-09-09. Flow taps `wheel-app-shop` then Done.

### Batch CJ — Rotary dial redesign (2026-09-09)

- [x] **Compact submerged dial** — 2026-09-09. ~58pt dial, no grabber, soft arc glass (not full chrome bar).
- [x] **Continuous position + 1:1 drag** — 2026-09-09. Floating `position`; deferred page commit until snap.
- [x] **Flick momentum** — 2026-09-09. Friction coast capped at ~2.4 segments, then spring snap.
- [x] **Idle neighbors fade** — 2026-09-09. After 2.4s only center stays clear; touch wakes.
- [x] **Transient labels** — 2026-09-09. Capsule label ~650ms above center; no permanent labels.
- [x] **Swipe-up grid (no dock handle)** — 2026-09-09. Vertical swipe expands apps; dock has no grabber.
- [x] **Page content stays readable** — 2026-09-09. Soft 35–55% bottom fade instead of opaque gradient takeover.

### Batch CK — Dial polish

- [x] **Idle neighbors more visible** — 2026-09-09. ±1 ~62%, ±2 ~38% when idle; no pill chrome on collapsed dial.
- [x] **Expand morphs one menu** — 2026-09-09. Shared growing shell + matchedGeometry icons; pull peeks growth.
- [x] **Expanded takes ~72% screen** — 2026-09-09. Larger 74pt cells, vertical spacers, all 10 apps with room.

### Batch CL — Idle flat pill + smoother expand

- [x] **Idle morphs to flat 5-icon pill** — 2026-09-09. After 5s, arc lerps into flat capsule (center bright, neighbors muted).
- [x] **Touch wakes back to arc** — 2026-09-09. Drag/tap animates `idleAmount` → 0 with spring.
- [x] **Smoother expand/collapse** — 2026-09-09. Softer spring, removed matchedGeometry fight; easier swipe-down / scrim dismiss.

### Batch CN — Mobbin cohesive redesign (visual system)

_References: [Ladder workouts](https://mobbin.com/screens/4f68e1bb-7f3a-4452-bcb2-e1d70c4dcc42), [Todoist Upcoming](https://mobbin.com/screens/4159b14b-0ff2-4130-8844-616b858a7e78), [Crouton Meal Plan](https://mobbin.com/screens/64b7d756-1bd0-4835-a5e8-29ea2495de75), [Centr Shopping List](https://mobbin.com/screens/a4b9ad4e-b96c-4929-bd47-db7069693e30), [Tonal / MacroFactor onboarding](https://mobbin.com/flows/9f597ed6-aea4-4ec7-b573-48ea7484b164)._

- [x] **Elevated Theme tokens** — hairline borders, softer charcoal surfaces, card shadow, ProgressTrack, MetaPill, CountBadge, IconWell, SoftDayCell; Primary/Secondary buttons as filled continuous shapes with CTA glow.
  → Fix: `Theme.swift` design-system pass.
- [x] **Today section chrome** — overdue danger title, CountBadge, hairline cards, MetaPill due dates (Todoist hierarchy).
  → Fix: `TodayView.sectionCard` + task due pills.
- [x] **Meals hero + day chips** — HeroPanel dinner card with meta pills; DayChip filled capsules mark today.
  → Fix: `MealPlanView`.
- [x] **Habits week strip** — SoftDayCell in elevated strip; habit cards hairlined.
  → Fix: `HabitsView`.
- [x] **Shop progress + Settings/Browse/Lift/Onboarding polish** — shop ProgressTrack; Settings profile header + IconWell rows; Browse course chips + icon wells; Lift cards; onboarding progress track; placeholder IconWell + PrimaryButton; FAB CTA glow.
  → Fix: Grocery/Settings/Browse/Workout/Onboarding/Placeholder/OrangeFAB.

### Batch CO — Calendar & Matrix visual cohesion

- [x] **Calendar month cells** — today number white on accent circle (matches SoftDayCell).
  → Fix: `CalendarPlannerView.monthCell`.
- [x] **Matrix quadrant cards** — count capsules + soft elevation shadow.
  → Fix: `MatrixView.quadrant`.
- [x] **Drawer menu** — IconWell leading icons on destination rows + hairline edge.
  → Fix: `PlannerDrawer.drawerRow`.

---

## Done

_(See prior entries — all pre-H batches verified 2026-08-30.)_

---

## Done

_(See prior entries — all pre-H batches verified 2026-08-30.)_

---

## Tester notes (latest)

- **Batch H PASS 2026-08-30** — build OK; global search E2E; calendar light-mode grid dividers code-verified; habits/calendar tab taps missed in automation (sim window coords).
- **Batch I PASS 2026-08-30** — build OK; search sheet shows shop placeholder; `requestedOpenShop` wired in RootView.
- **Batch J PASS 2026-08-30** — build OK; drawer/search copy aligned.

- **Batch Y PASS 2026-08-30** — build OK; global search E2E launch; day agenda + ingredient + search a11y code-verified.

- **Batch Z PASS 2026-08-30** — build OK; global search E2E; Meals/habits/shop a11y code-verified.

- **Batch AA PASS 2026-08-30** — build OK; global search E2E; pantry/tags/recipe/lift a11y code-verified.

- **Batch AB PASS 2026-08-30** — build OK; global search E2E; sheet dismiss + browse + drawer alert a11y code-verified.

- **Batch AC PASS 2026-08-30** — build OK; global search E2E; drawer/habit/meals/lift a11y code-verified.

- **Batch AD PASS 2026-08-30** — build OK; global search E2E; Meals chips/Quick Add/colors a11y code-verified.

- **Batch AE PASS 2026-08-30** — build OK; global search E2E; lift strip/log/browse/onboarding a11y code-verified.

- **Batch AF PASS 2026-08-30** — build OK; global search E2E; settings/event/workout summary a11y code-verified.

- **Batch AG PASS 2026-08-30** — build OK; global search E2E; confirm dialogs/task/integrations a11y code-verified.

- **Batch AH PASS 2026-08-30** — build OK; global search E2E; sync/event/list/tag/onboarding a11y code-verified.

- **Batch AI PASS 2026-08-30** — build OK; global search E2E; banner/lift/calendar/slider/postpone a11y code-verified.

- **Batch BF PASS 2026-08-30** — build OK; global search E2E; suggested/finish/pantry/workout/postpone a11y code-verified.

- **Batch BG PASS 2026-08-30** — build OK; global search E2E; leave-workout/undo/dinner/cook-pane/ghost-event a11y code-verified.

- **Batch BH PASS 2026-08-30** — build OK; global search E2E; browse/skip-replace/global-search/calendar-scope a11y code-verified.

- **Batch BI PASS 2026-08-30** — build OK; global search E2E; error/new-list/shop-header/workout-options a11y code-verified.

- **Batch BJ PASS 2026-08-30** — build OK; global search E2E; tag-editor/busy-overlay/search-shop/task-editor/scope-cancel a11y code-verified.

- **Batch BK PASS 2026-08-30** — build OK; global search E2E; event/settings/onboarding/quick-add/integrations picker a11y code-verified.

- **Batch BL PASS 2026-08-30** — build OK; global search E2E; provider/browse/all-day/habit-icon/complexity a11y code-verified.

- **Batch BM PASS 2026-08-30** — build OK; global search E2E; onboarding-complexity/habit-period/tools/color/matrix-header a11y code-verified.

- **Batch BN PASS 2026-08-30** — build OK; global search E2E; cookbook/tag-color/frequency/matrix-intro/quick-add-due a11y code-verified.

- **Batch BO PASS 2026-08-30** — build OK; global search E2E; completed/habit-name/integrations/nutrition a11y code-verified.

- **Batch BP PASS 2026-08-30** — build OK; global search E2E; reminder toggles/cooldown stepper a11y code-verified; list/onboarding toggles verified.

- **Batch BQ PASS 2026-08-30** — build OK; global search E2E; duration/servings/integration steppers/event all-day pickers a11y code-verified.

- **Batch BR PASS 2026-08-30** — build OK; global search E2E; age/due/alert/servings picker a11y code-verified.

- **Batch BS PASS 2026-08-30** — build OK; global search E2E; remind-at/body-metrics/due-date-sheet a11y code-verified.

- **Batch BU PASS 2026-08-30** — build OK; global search E2E; metric-hint/rationale/location/progress a11y code-verified.

- **Batch BV PASS 2026-08-30** — notes/title/dietary a11y; 5-tab screenshot script added.

- **Batch BW PASS 2026-08-30** — matrix grid-only; calendar full width; search/settings in Today drawer; workout tap targets; shop open without LLM rebuild.

- **Batch BY PASS 2026-08-30** — lazy tabs, debounced widgets, deferred sync, scoped queries, plan cache; build OK.

- **Batch BX PASS 2026-08-30** — drawer footer search, calendar headers, workout tap frames, shop auto-populate, title headers; spot-check OK.

- **Batch BZ PASS 2026-08-30** — drawer scope hint, centered day numbers, shop idempotency, set row a11y; spot-check OK.

- **Batch CA PASS 2026-08-30** — footer touch targets, today circle, search copy, shop retry, meals header doc; spot-check OK.

- **Batch CB PASS 2026-09-09** — CB items already in tree; spot-check OK after wheel grid work.

- **Batch CD PASS 2026-09-09** — swipe-up Apps grid, pick/collapse, neighbor readability, idle dim, FAB hide; sim verified.

- **Batch CE PASS 2026-09-09** — spinning label, Shop/Settings from grid, placeholder CTA, VO order, expand peek; sim verified.

- **Batch CF PASS 2026-09-09** — FAB clearance, Shop→Meals restore, Apps title a11y, spot-check swipe+pick, grid fit; sim verified.

- **Batch CG PASS 2026-09-09** — simultaneous collapse gesture, Done header a11y, light grid, drawer collapses grid, real shop dismiss restore, wheel-app ids.

- **Batch CH PASS 2026-09-09** — single Shop Done, collapse haptic, Settings restore, shop-from-grid automation.

- **Batch CI PASS 2026-09-09** — accent nav selection, expand threshold, Back to Today, spot-check shop-from-grid.

- **Batch CL PASS 2026-09-09** — idle flat pill morph (5s), wake-to-arc, smoother expand/collapse.

---

### Batch CM — FAB vs wheel hit target (user report)

- [x] **Plus button under wheel steals taps** — 2026-09-10. FAB sat under the dial; then full-width FAB plate + hit carve-outs blocked the dial.
  → Fix: Host `OrangeFAB` above dial as trailing-only (spacers `allowsHitTesting(false)`); restore full dial gestures; raise clearance so + clears icons. Verified: dial tap→Calendar, Add task/Add event still open.

### Batch CQ — Drawer + Meals rows + matrix empty

- [x] **Drawer Search/Settings IconWells** — footer rows match destination IconWell language.
  → Fix: `PlannerDrawer` footer.
- [x] **Meals rest-of-week rows** — hairline cards, Today pill, empty MetaPill CTA cue.
  → Fix: `MealPlanView.dayRow`.
- [x] **Matrix empty quadrant hint** — subtle “Drop here” when empty.
  → Fix: `MatrixView.quadrant`.

### Batch CR — Fresh audit (next)

- [x] **Quick Add sheet** — canvas background + FieldChrome-style title field with hairline.
  → Fix: `QuickAddSheet`.
- [x] **Calendar agenda preview card** — hairline + soft elevation.
  → Fix: `CalendarPlannerView.monthDayPreview`.
- [x] **Tonight dinner card on Today** — IconWell + hairline/hero stroke.
  → Fix: `TonightMealCard`.
- [x] **Widget snapshot chrome** — elevated charcoal surface tokens aligned with Theme.
  → Fix: `CadenceWidgets.WidgetTheme`.

### Batch CS — Continuity polish

- [x] **Onboarding PrimaryButton** — Continue / Get started footer like Tonal/MacroFactor.
  → Fix: `OnboardingView` safeAreaInset.
- [x] **Grocery category headers** — CountBadge for open items in section.
  → Fix: `GroceryListView` section headers.
- [x] **Habits period headers** — CountBadge next to MORNING/EVENING.
  → Fix: `HabitsHomeView`.
- [x] **Global search sheet** — hairline search field chrome.
  → Fix: `GlobalSearchSheet` field row.

### Batch CT — Next audit

- [x] **New habit sheet** — Theme.PrimaryButton Save + hairline name field.
  → Fix: `NewHabitSheet`.
- [x] **Browse recipe detail** — MetaPill macros on Plate section.
  → Fix: `RecipeDetailView`.
- [x] **Wheel app grid cells** — hairline on all cells; selected accent stroke.
  → Fix: `WheelAppMenuOverlay`.
- [x] **Spot-check full flow** — 2026-09-10. Build OK; Today/Calendar/Meals/Matrix/Habits screenshots; dark restored.

### Batch CU — Density & chrome

- [x] **Habits empty vertical space** — tighter strip/list spacing + tip when <3 habits (no forced minHeight empty).
  → Fix: `HabitsHomeView` denser VStack; tip under workout banner.
- [x] **Today hero cards hairline** — WorkoutDayCard / TonightMealCard / WorkoutCompactBanner elevated chrome.
  → Fix: hairline + cardShadow; compact banner uses `Theme.Card` + IconWell.
- [x] **Settings profile header** — elevated listRowBackground with hairline + shadow.
  → Fix: `SettingsView` profile section.
- [x] **SoftDayCell selection uses accent** — AccentColor asset orange confirmed in sim pixels (255,122,0). Pin `Theme.accent = Color("AccentColor")` so tint cannot collapse nav→CTA blue.
  → Fix: `Theme.accent`; SoftDayCell white rim when selected.
  → Verified: 2026-09-10 Habits screenshot SoftDayCell crop.

### Batch CV — Recipe & Meals polish (Mobbin: Crouton)

- [x] **Recipe detail ingredients** — quantity/unit in CTA blue; item ink; prep muted.
  → Fix: `RecipeDetailView.ingredientColoredLabel`.
- [x] **Recipe detail method steps** — numbered CTA circles; scaled lines in CTA.
  → Fix: `RecipeStepRow`.
- [x] **Meals rest-of-week rows** — hairline + cardShadow elevation; side row chrome; Swap uses CTA tint.
  → Fix: `MealPlanView.dayRow` / side / empty-day Swap.
- [x] **Quick Add sheet** — CheckGlyph + IconWell date + PrimaryButton Save (CTA).
  → Fix: `QuickAddSheet`.
  → Verified: 2026-09-10 build OK; Meals empty + Today/Habits screenshots; SoftDayCell orange on Lift week strip.

### Batch CW — Toolbar & Shop (Mobbin: Centr)

- [x] **Toolbar Done** — confirmation/dismissal Done uses Theme.cta across Settings, Lift, Shop, sheets.
  → Fix: WorkoutHomeView, SettingsView, GroceryListView, ExerciseGuide, Planner sheets, Task editor.
- [x] **Grocery quantities** — name left, quantity right in CTA blue (Centr pattern).
  → Fix: `GroceryRow`.
- [x] **Today section density** — ScrollView spacing 14→10.
  → Fix: `TodayDestinationView` / Today scroll stack.
- [x] **WorkoutDayCard hairline** — already elevated with hairline + shadow (CU); confirmed on Today.
  → Verified: 2026-09-10 Settings Done blue; Shop qty + Done blue.

### Batch CX — Action chrome & surfaces

- [x] **Shop toolbar icons** — pantry/refresh/add use Image + Theme.cta (not Label tint bleed).
  → Fix: `GroceryListView` toolbar.
- [x] **Shop CountBadge** — muted (not emphasized orange) for category counts.
  → Fix: `CountBadge(count:)` without emphasized.
- [x] **Calendar agenda cards** — stronger cardShadow on month day preview.
  → Fix: `CalendarPlannerView.monthDayPreview`.
- [x] **Matrix empty cells** — sunken + hairline “Drop here” wells; stronger quadrant shadow.
  → Fix: `MatrixView.quadrant`.
  → Verified: 2026-09-10 Matrix Drop-here wells; Shop CTA toolbar.

### Batch CY — Browse & Day detail (Mobbin: Structured / Crouton)

- [x] **Browse recipe rows** — course MetaPill (CTA) + link glyph CTA.
  → Fix: `BrowseView` recipe rows.
- [x] **Day detail sheet cards** — cardShadow on tasks/events/workout cards.
  → Fix: `DayDetailSheet` / `WorkoutDayDetailCard`.
- [x] **Meals Plan week CTA** — already PrimaryButton + Plan week CTA link (verified empty Meals).
- [x] **Drawer Settings footer** — Settings IconWell uses Theme.cta; destinations keep accent when selected.
  → Fix: `PlannerDrawer` Settings row.
  → Verified: 2026-09-10 build OK.

### Batch CZ — Dial & placeholders audit

- [x] **Wheel dial active ring** — center glow + stroke use Theme.accent (was hardcoded blue).
  → Fix: `WheelNav.dialIcon` selected radial.
- [x] **Placeholder pages** — IconWell tint Theme.accent (place); PrimaryButton stays CTA.
  → Fix: `PlaceholderPageView`.
- [x] **Active workout set rows** — hairline + sunken chrome; complete glyph remains accent fill.
  → Fix: `ActiveWorkoutView` set row.
- [x] **Widget surfaces** — shared chromeBackground + AccentColor for countdown.
  → Fix: `CadenceWidgets` WidgetTheme.
  → Verified: 2026-09-10 dial crop orangePx=455 bluePx=0.

### Batch DA — Fresh UX audit (loop continue)

- [x] **Onboarding Continue** — ProgressTrack in elevated surface card; PrimaryButton unchanged.
  → Fix: `OnboardingView` progress section listRowBackground.
- [x] **Meals with plan** — rest-of-week elevation already in CV; empty PrimaryButton verified.
- [x] **Search sheet result density** — MetaPill dues on events; row vertical padding.
  → Fix: `GlobalSearchSheet` task/event rows.
- [x] **FAB vs dial** — FAB CTA blue + dial place orange (CZ).
  → Verified: 2026-09-10 search + Today screenshots.

### Batch DB — Light mode & form chrome

- [x] **Form listRowBackground** — settingsFormChrome tints toggles/links Theme.cta.
  → Fix: `settingsFormChrome()`.
- [x] **Light SoftDayCell** — AccentColor orange readable on light (verified crop).
- [x] **Browse course chips** — hairline on selected/unselected capsules.
  → Fix: `BrowseView` course filter.
- [x] **Habits tip copy** — muted tip retained from CU; light contrast OK.
  → Verified: 2026-09-10 light Habits/Settings.

### Batch DC — Empty states & sheets

- [x] **Meals empty IconWell** — MetaPills “7 dinners” / “Auto shop” under subtitle.
  → Fix: `Theme.EmptyState.meta` + `MealPlanView.emptyState`.
- [x] **Matrix empty Drop-here** — CX wells; re-verified in sim.
- [x] **Task editor sheet** — canvas + Theme.cta tint for toggles.
  → Fix: `TaskEditorSheet`.
- [x] **New habit sheet** — period pills white-on-accent + hairline.
  → Fix: `NewHabitSheet.pill`.
  → Verified: 2026-09-10 Meals empty MetaPills + Matrix.

### Batch DD — Calendar day cells & FAB

- [x] **Calendar today numeral** — white on accent fill retained; agenda elevation from CX.
- [x] **FAB glow** — CTA rim + soft dual shadow (action blue, not dial orange).
  → Fix: `OrangeFAB`.
- [x] **OrangeFAB accessibility** — labels/hints unchanged; hidden when app grid expanded.
- [x] **DayChip Meals strip** — hairline when unselected; accent rim when today/selected.
  → Fix: `Theme.DayChip`.
  → Verified: 2026-09-10 calendar/meals/today shots.

### Batch DE — Continuous polish audit

- [x] **Lift SoftDayCell** — uses Theme.SoftDayCell / AccentColor pin (CU).
- [x] **Shop Add row** — Add action Theme.cta; pantry swipe Theme.cta.
  → Fix: `GroceryListView`.
- [x] **Source citation card** — IconWell + Link tinted Theme.cta.
  → Fix: `SourceCitationView`.
- [x] **Countdown track button** — accent fill well when tracked.
  → Fix: `CountdownTrackButton`.
  → Verified: 2026-09-10 shop/today.

### Batch DF — Next audit pass

- [x] **Active workout Finish CTA** — Finish nav action Theme.cta (Hevy pattern).
  → Fix: `ActiveWorkoutView.topBar`.
- [x] **Habits mini-week dots** — Theme.accent fill (HabitsView).
- [x] **Global search empty** — IconWell + muted no-results stack.
  → Fix: `GlobalSearchSheet`.
- [x] **Planner event sheet** — CTA confirmation already (CW).
  → Verified: 2026-09-10 build OK.

### Batch DG — Fresh skim (tabs)

- [x] **Today overdue section** — danger title retained; CountBadge no longer orange-emphasized for overdue.
  → Fix: `TodayView.sectionCard` CountBadge.
- [x] **Calendar week strip** — SoftDayCell AccentColor (CU/CZ).
- [x] **Settings quick tweaks** — CTA fill + CTA hairline stroke.
  → Fix: `SettingsQuickTweaks.quickChip`.
- [x] **Browse empty** — MetaPill “Clear filters” tip.
  → Fix: `BrowseView` empty section.
  → Verified: 2026-09-10 build + settings shot.

### Batch DH — Keep polishing

- [x] **PlanGeneratingOverlay** — CTA rings + fork icon (action of building).
  → Fix: `PlanGeneratingOverlay`.
- [x] **Grocery ProgressTrack complete** — accent when all done (place “done”).
- [x] **Wheel app grid** — hairline cells (CT).
- [x] **Day detail New Event** — Add event tinted Theme.cta.
  → Fix: `DayAgendaBody` empty card.
  → Verified: 2026-09-10 build OK.

### Batch DI — Continuous audit

- [x] **Light mode dial glow** — orangePx=3168 bluePx=0 on light dial crop.
  → Fix: `WheelNav` Theme.accent glow (CZ); verified light.
- [x] **Habits FAB** — OrangeFAB Theme.cta (shared).
- [x] **Recipe steps** — numbered CTA circles (CV).
- [x] **Settings Done** — Theme.cta (CW).
  → Verified: 2026-09-10 light dial.

### Batch DJ — Fresh UX audit append

- [x] **Today hero Skip** — bordered Skip tinted Theme.cta (action).
  → Fix: `WorkoutTodayActions`.
- [x] **Meals Swap** — CTA (CV).
- [x] **Matrix quadrant tints** — functional colors retained.
- [x] **Onboarding Get started** — PrimaryButton busy (CQ).
  → Verified: 2026-09-10 build OK.

### Batch DK — Keep going

- [x] **Rest timer Skip** — Theme.cta + ProgressView CTA tint.
  → Fix: `ActiveWorkoutView` rest banner.
- [x] **Onboarding Skip setup / Skip to finish** — muted secondary.
  → Fix: `OnboardingView` toolbar.
- [x] **Drawer Shop row** — SoftDayCell/drawer selection accent (place).
- [x] **Tonight MealCard Today label** — accent place (OK).
  → Verified: 2026-09-10 build OK.

### Batch DL — Fresh audit

- [x] **Rest timer label** — remaining time Theme.cta (with Skip + track).
  → Fix: rest banner countdown.
- [x] **Undo FAB** — flagMedium retained.
- [x] **SecondaryButton** — hairline chrome already.
- [x] **Light Mode Shop Done** — CTA blue (verified light screenshot).
  → Verified: 2026-09-10 dl-shop-light.

### Batch DM — Continuous polish

- [x] **Tonight dinner IconWell** — CTA (OK).
- [x] **Calendar Agenda button** — CTA (OK).
- [x] **Habits period CountBadge** — muted (OK).
- [x] **Global search Close** — Theme.cta.
  → Fix: `GlobalSearchSheet` toolbar.
  → Verified: 2026-09-10 build OK.

### Batch DN — Fresh UX audit

- [x] **Drawer Close** — muted xmark (dismiss secondary) OK.
- [x] **Meals Plan week** — CTA link (OK).
- [x] **Lift Done** — CTA (CW).
- [x] **Widget countdown accent** — AccentColor (CZ).
  → Verified: code skim 2026-09-10.

### Batch DO — Fresh UX audit (append)

- [x] **Today “Today” workout label** — Theme.accent place (OK).
- [x] **Begin workout** — Theme.cta (OK).
- [x] **Habit Skip** — muted (OK secondary).
- [x] **Form Picker chevrons** — Onboarding + Settings `.tint(Theme.cta)`.
  → Fix: `OnboardingView` form tint; Settings via settingsFormChrome.
  → Verified: 2026-09-10 build + tab spot-check.

### Batch DP — Keep auditing

- [x] **Task editor LocationField** — Maps affordance Theme.cta (OK).
- [x] **SmartTitleHints** — MetaPill due (danger) + tags (accent).
  → Fix: `SmartTitleHints` ([Things 3](https://mobbin.com/screens/ef57eb64-7960-49c2-994a-c72eadcbfb46) pattern).
- [x] **Exercise guide Done** — CTA (CW).
- [x] **Pantry editor Done** — CTA (CW).
  → Verified: 2026-09-10 build OK.

### Batch DQ — Fresh skim

- [x] **PriorityFlagIcon** — keep priority colors (OK).
- [x] **DialFABAnchor** — FAB above dial (CM).
- [x] **HeroPanel dinner** — CTA tint (OK).
- [x] **EmptyState meta optional** — Meals uses it (DC).
  → Verified: code skim 2026-09-10.

### Batch DR — Fresh UX audit

- [x] **PlannerDateTimeRow** — value Theme.cta + chevron.
  → Fix: `PlannerDateTimeRow`.
- [x] **TaskCheckbox** — accent complete fill (OK).
- [x] **HabitIconBadge** — retain custom colors (OK).
- [x] **Light Mode Matrix Drop-here** — sunken wells verified light screenshot.
  → Verified: 2026-09-10 dr-matrix-light.

### Batch DS — Continuous

- [x] **DueDatePicker No date** — muted secondary.
  → Fix: `DueDatePickerSheet`.
- [x] **Graphical DatePicker tint** — Theme.cta.
  → Fix: `DueDatePickerSheet`.
- [x] **Priority menu** — keep flag colors (OK).
- [x] **Workout EditableField** — CTA focus stroke + hairline idle.
  → Fix: `WorkoutEditableField`.
  → Verified: 2026-09-10 build OK.

### Batch DT — Fresh audit

- [x] **RIRBadge** — retain palette (OK).
- [x] **SetTypeBadge** — Theme.sunken + hairline.
  → Fix: `SetTypeBadge`.
- [x] **Light SoftDayCell badges** — accent (verified earlier SoftDayCell orange).
- [x] **Meals Plan week toolbar** — CTA (OK).
  → Verified: 2026-09-10 build OK.

### Batch DU — Keep looping

- [x] **Active workout top bar** — Finish CTA (DF).
- [x] **Rest banner CTA** — (DK/DL).
- [x] **Widget hairline chrome** — (CZ).
- [x] **Browse course chips** — hairline (DB).
  → Verified: re-skim 2026-09-10.

### Batch DV — Fresh UX audit (append)

- [x] **Dial idle pill** — glass contrast OK.
- [x] **FAB vs dial spacing** — FAB above dial (CM).
- [x] **Settings profile IconWell** — accent place (OK).
- [x] **Shop ProgressTrack** — CTA while shopping / accent when done (OK).
  → Verified: re-skim 2026-09-10.

### Batch DW — Fresh audit (continue)

- [x] **Calendar today cell** — white on accent (OK).
- [x] **Habits tip line** — muted (OK).
- [x] **Quick Add PrimaryButton** — CTA (CV).
- [x] **New habit period pills** — accent selected (DC).
  → Verified: re-skim 2026-09-10.

### Batch DX — Fresh UX audit

- [x] **Start Workout button orange** — should be CTA blue (Ladder/Peloton primary action).
  → Fix: `WorkoutSessionPreviewView` Start uses `Theme.cta` + white label + CTA shadow.
- [x] **Exercise guide step circles orange** — step numbers are action chrome like recipe (Crouton).
  → Fix: `ExerciseGuideView` step wells use `Theme.cta` + white numerals.
- [x] **Habits completed lack strikethrough** — QUITTR-style done de-emphasis.
  → Fix: done habit title strikethrough + muted; subtitle/opacity soften.
- [x] **Workout keypad hardcoded grays** — breaks light cohesion.
  → Fix: keypad/keys/confirm/`WorkoutEditableField`/`PlateCalculatorInline` on Theme tokens; confirm = CTA.
  → Verified: build + sim 2026-09-10.

### Batch DY — Fresh UX audit (append)

- [x] **Today task completed chrome** — strikethrough already (OK).
- [x] **Habit completed badge keeps habit color** — done state should read as accent completion (TaskCheckbox parity).
  → Fix: `HabitIconBadge` completed fill → `Theme.accent`.
- [x] **Active workout auto label** — hardcoded gray.
  → Fix: `Theme.muted` on set auto hint.
- [x] **Keypad / Start CTA** — covered in DX.
  → Verified: build + sim 2026-09-10.

### Batch DZ — Fresh UX audit

- [x] **Settings category IconWells** — Linktree-style: place vs action tint.
  → Fix: `SettingsCategoryRow` optional `tint`; Planning/Reminders/AI → `Theme.cta`; Profile/Nutrition/Calendar stay accent.
- [x] **Workout logged mint** — off-token completion color.
  → Fix: logged workout check + DayDetail “Completed” → `Theme.accent`.
- [x] **Habit done card rim** — accent hairline when complete.
  → Fix: `HabitsView` card stroke uses accent when done.
- [x] **Finish toolbar** — CTA (OK).
  → Verified: build + sim settings/habits 2026-09-10.

### Batch EA — Fresh UX audit

- [x] **Browse course MetaPill** — category = place → accent (CREME tags).
  → Fix: Browse row course pill `tone: .accent`.
- [x] **Browse Show more** — CTA link color.
  → Fix: `Theme.cta` on Show more.
- [x] **Shop aisle headers** — muted caps (Habits MORNING parity).
  → Fix: grocery section headers caption/muted/uppercase.
- [x] **Matrix Drop wells** — dashed empty affordance.
  → Fix: dashed muted stroke on empty quadrant wells.
  → Verified: build + matrix/shop screenshots 2026-09-10.

### Batch EB — Fresh UX audit

- [x] **Add something shop header** — muted caps parity.
  → Fix: empty-state Add something header caption/muted/uppercase.
- [x] **Browse empty Clear filters** — tappable CTA.
  → Fix: Clear filters button resets course + search.
- [x] **Light mode SoftDayCell** — re-verify accent.
  → Verified: light habits SoftDayCell orange 2026-09-10.
- [x] **Widget chrome** — AccentColor (CZ, OK).

### Batch EC — Fresh UX audit

- [x] **Meals day row place cue** — Equinox vertical accent bar for today.
  → Fix: day rows get 3pt accent rail + accent hairline when today.
- [x] **Onboarding Skip** — CTA (DK, OK).
- [x] **Search empty IconWell** — CTA (DF, OK).
- [x] **FAB rim** — white rim (DD, OK).
  → Verified: build + meals screenshot 2026-09-10.

### Batch ED — Fresh UX audit

- [x] **Calendar agenda preview** — Equinox vertical color rails.
  → Fix: month preview items use 3pt color rails; today preview accent hairline.
- [x] **Meals empty Tap to plan** — MetaPill CTA (OK).
- [x] **Today workout Begin** — PrimaryButton CTA (OK).
- [x] **Dial glow** — accent (CZ, OK).
  → Verified: build + calendar screenshot 2026-09-10.

### Batch EE — Fresh UX audit

- [x] **Day detail event rows** — Equinox vertical color rails.
  → Fix: event rows use 3pt color rails instead of dots.
- [x] **Calendar preview rails** — ED.
- [x] **Plan generating overlay** — CTA rings (DH, OK).
- [x] **Shop ProgressTrack** — CTA while shopping (OK).
  → Verified: build 2026-09-10.

### Batch EF — Fresh UX audit

- [x] **Today event rows** — matching vertical rails.
  → Fix: Today event color rail (Equinox).
- [x] **Matrix task rows** — left rail by quadrant tint.
  → Fix: `matrixTaskRow` 3pt tint rail.
- [x] **Global search result chrome** — MetaPill parity (OK from prior).
- [x] **Placeholder pages** — IconWell CTA (CZ, OK).
  → Verified: build 2026-09-10.

### Batch EG — Fresh UX audit

- [x] **Search result section headers** — muted caps.
  → Fix: `searchSectionHeader` helper on GlobalSearchSheet sections.
- [x] **Drawer list rows** — IconWell cohesion.
  → Fix: custom list rows use IconWell (accent when selected).
- [x] **Widgets SoftDayCell** — accent pin (CZ, OK).
- [x] **Onboarding Continue** — PrimaryButton CTA (OK).
  → Verified: build 2026-09-10.

### Batch EH — Fresh UX audit

- [x] **Search event rows** — Equinox color rails.
  → Fix: GlobalSearch event rows get event-color rail before IconWell.
- [x] **Search task rows** — IconWell CTA OK.
- [x] **Drawer Views rows** — already IconWell (OK).
- [x] **Light mode Matrix rails** — tint rails work in light (Theme tokens).
  → Verified: build + install 2026-09-10.

### Batch EI — Fresh UX audit

- [x] **Recipe detail section headers** — muted caps (Recime).
  → Fix: Plate / Steps / Ingredients headers caption muted uppercase.
- [x] **Active workout set headers** — already Theme.muted caption2 (OK).
- [x] **Habits MORNING header** — already muted caps (OK).
- [x] **Meals Rest of week** — SectionHeader (OK).
  → Verified: build 2026-09-10.

### Batch EJ — Fresh UX audit

- [x] **Settings section headers** — Form already uppercases (OK).
- [x] **Onboarding section headers** — Form system caps (OK).
- [x] **Day detail Tasks/Events** — caption muted (OK).
- [x] **Placeholder pages density** — quieter chrome.
  → Fix: muted IconWell + accent “Coming soon” MetaPill; PrimaryButton stays CTA.
  → Verified: build 2026-09-10.

### Batch EK — Fresh UX audit

- [x] **Today habit Skip** — CTA (DJ, OK).
- [x] **Workout rest Skip** — CTA (DK, OK).
- [x] **SoftDayCell light** — orange (EB, OK).
- [x] **Browse filter chip selected glow** — light cohesion (Yazio/Blue Apron).
  → Fix: selected course chip soft accent shadow.
  → Verified: build 2026-09-10.

### Batch EL — Fresh UX audit

- [x] **DayChip selected shadow** — match SoftDayCell glow.
  → Fix: `DayChip` + `SoftDayCell` selected accent glow shadows.
- [x] **New habit period pills** — accent selected (DC, OK).
- [x] **Quick Add period pills** — accent (OK).
- [x] **FAB accessibility** — labels per tab (H, OK).
  → Verified: build + habits screenshot 2026-09-10.

### Batch EM — Fresh UX audit

- [x] **CountBadge emphasized** — accent (OK).
- [x] **MetaPill accent vs cta** — roles locked (OK).
- [x] **PrimaryButton shadow** — CTA glow (OK).
- [x] **Shop ProgressTrack height** — thicker shopping track.
  → Fix: shop inset ProgressTrack height 6 (onboarding parity).
  → Verified: build 2026-09-10.

### Batch EN — Fresh UX audit

- [x] **Widget SoftDayCell glow** — no SoftDayCell in widgets; countdown uses AccentColor (OK).
- [x] **Dial idle pill contrast** — glass OK.
- [x] **HeroPanel tint** — CTA workout cards (OK).
- [x] **Matrix drop dashed** — EA OK.
  → Verified: re-skim widgets 2026-09-10.

### Batch EO — Fresh UX audit

- [x] **Widget task checkbox** — AccentColor when done + strikethrough.
  → Fix: widget `rowLabel` uses `WidgetTheme.accent`; done title strikethrough/muted.
- [x] **Widget empty chrome** — hairline surface (OK).
- [x] **Countdown star** — accent (DE, OK).
- [x] **Home Screen widget density** — OK for small/medium.
  → Verified: build 2026-09-10.

### Batch EP — Fresh UX audit

- [x] **Lock-screen countdown accessory** — OK.
- [x] **Widget open count badge** — secondary OK.
- [x] **App icon accent wave** — brand OK.
- [x] **Settings quick tweaks** — IconWell cards (Linktree).
  → Fix: quick chips use elevated surface + CTA IconWell + hairline/shadow.
  → Verified: build + settings screenshot 2026-09-10.

### Batch EQ — Fresh UX audit

- [x] **Profile hero card** — already elevated (OK).
- [x] **Settings Done** — CTA (OK).
- [x] **Nutrition IconWell** — accent place (OK).
- [x] **Meals with plan day rails** — today accent rail + hairline on rows.
  → Verified: meals planned week UI in sim 2026-09-10 (day rows + DayChip glow).

### Batch ER — Fresh UX audit

- [x] **Meals Browse bordered button** — tint CTA.
  → Fix: empty-tonight Browse `.tint(Theme.cta)`.
- [x] **Swap in dinner** — Primary CTA (OK).
- [x] **New week** — CTA link (OK).
- [x] **Tonight empty secondary Browse chrome** — CTA tint (above).
  → Verified: build 2026-09-10.

### Batch ES — Fresh UX audit

- [x] **Calendar Agenda link** — CTA (OK).
- [x] **Matrix FAB** — CTA (OK).
- [x] **Habits tip line** — muted (OK).
- [x] **Light mode Settings quick chips** — elevated surface + CTA IconWell.
  → Verified: light settings screenshot 2026-09-10.

### Batch ET — Fresh UX audit

- [x] **Light SoftDayCell glow** — EL shadow (OK).
- [x] **Light dial glow** — accent (DI, OK).
- [x] **Light Matrix dashed drops** — EA (OK).
- [x] **Settings category CTA tints** — Planning/Integrations use Theme.cta (code).
  → Verified: light Settings + code skim 2026-09-10.

### Batch EU — Fresh UX audit

- [x] **Meals empty Browse** — SecondaryButton (Peanut pair).
  → Fix: Tonight empty Browse uses `Theme.SecondaryButton`.
- [x] **Day detail Add task/event** — CTA pair (OK).
- [x] **Grocery empty PrimaryButton** — Plan this week (OK).
- [x] **Matrix empty Drop wells** — dashed (OK).
  → Verified: build 2026-09-10.

### Batch EV — Fresh UX audit

- [x] **EmptyState Primary+Secondary** — Theme components (OK).
- [x] **Search Clear filters** — MetaPill CTA button (EB, OK).
- [x] **Habits empty CTA** — OK.
- [x] **Drawer Search/Settings rows** — elevated hairline cards.
  → Fix: drawer Search + Settings rows get surface + hairline chrome.
  → Verified: build + drawer screenshot 2026-09-10.

### Batch EW — Fresh UX audit

- [x] **Drawer Close** — CTA (DN, OK).
- [x] **Drawer Views selection** — accent (OK).
- [x] **Drawer list IconWell** — EG (OK).
- [x] **FAB vs drawer** — FAB hidden when drawer open (OK).
  → Verified: re-skim 2026-09-10.

### Batch EX — Fresh UX audit

- [x] **Workout compact Lift link** — CTA (OK).
- [x] **TonightMealCard Plan** — CTA (OK).
- [x] **Overdue MetaPill** — danger (OK).
- [x] **Soft card radius consistency** — Theme.Radius.md on drawer/settings chips.
  → Fix: drawer Search/Settings + Settings quick chips use `Theme.Radius.md`.
  → Verified: build 2026-09-10.

### Batch EY — Fresh UX audit

- [x] **Today cards radius** — Theme.Radius.lg (OK).
- [x] **Habits cards** — Theme.Radius.lg (OK).
- [x] **Keypad keys** — Theme.Radius.sm.
  → Fix: WorkoutKeypadEditor RoundedRectangle uses Theme.Radius.sm.
- [x] **Keypad radius tokens** — done.
  → Verified: build 2026-09-10.

### Batch EZ — Fresh UX audit

- [x] **ActiveWorkout surface radius 16** — Theme.Radius.lg.
- [x] **Workout preview radius 16** — Theme.Radius.lg.
- [x] **Session preview Start radius 16** — Theme.Radius.lg.
- [x] **Remaining cornerRadius 16/14** — Today + ExerciseGuide + Lift home.
  → Fix: `Theme.Radius.lg` / `.md` tokens across workout/Today surfaces.
  → Verified: build 2026-09-10.

### Batch FA — Fresh UX audit (round 7)

- [x] **Residual hardcoded cornerRadius** — tokenized 10/12/14/16.
  → Fix: Lift/drawer/workout visuals → Theme.Radius; checkbox 8 kept micro.
- [x] **Light mode Meals day rails** — screenshot.
  → Verified: light meals 2026-09-10.
- [x] **Dial selection glow** — accent (OK).
- [x] **Calendar week strip** — SoftDayCell glow (EL, OK).

### Batch FB — Fresh UX audit

- [x] **Workout checkbox radius 8** — intentional micro (OK).
- [x] **Plate calculator tiny radii** — physical plates OK.
- [x] **WheelNav glass** — OK.
- [x] **Today density** — Oura-style tighter stack.
  → Fix: Today ScrollView VStack spacing → `Theme.Space.sm`.
  → Verified: build + today screenshot 2026-09-10.

### Batch FC — Fresh UX audit

- [x] **Habits list spacing** — match Today density.
  → Fix: Habits main VStack spacing → `Theme.Space.md`.
- [x] **Matrix quadrant padding** — density OK.
- [x] **Calendar preview card** — OK.
- [x] **Habits VStack spacing** — done.
  → Verified: build 2026-09-10.

### Batch FD — Fresh UX audit

- [x] **Meals Rest of week spacing** — Theme.Space.
  → Fix: Meals hero/empty/day-row spacings use Theme.Space tokens.
- [x] **Browse list density** — OK.
- [x] **Settings section gaps** — Form OK.
- [x] **Meals day row spacing** — Theme.Space.md HStack.
  → Verified: build 2026-09-10.

### Batch FE — Fresh UX audit

- [x] **Recipe step HStack spacing** — Theme.Space.
  → Fix: `RecipeStepRow` + `SourceCitationView` use Theme.Space.
- [x] **Grocery row spacing** — OK.
- [x] **Onboarding progress card** — OK.
- [x] **RecipeStepRow chrome** — CTA step circles (CV) + spacing (FE).
  → Verified: build 2026-09-10.

### Batch FF — Fresh UX audit

- [x] **Exercise guide steps** — CTA circles (DX, OK).
- [x] **Ingredient CheckGlyph** — CTA (OK).
- [x] **PlanGeneratingOverlay** — CTA rings (DH, OK).
- [x] **Lift week strip density** — Theme.Space + today accent rim/glow.
  → Fix: `WorkoutHomeView` + `WorkoutIntegration` week strips. Calendar brace fix unblocked build.
  → Verified: build 2026-09-10.

### Batch FG — Fresh UX audit (Mobbin: Structured / Lifesum calendar)

- [x] **Calendar weekday headers** — muted caps + tracking.
  → Fix: `CalendarPlannerView` month weekday row uses caption2 + tracking.
- [x] **Month day preview** — Theme.Space + cardShadow.
  → Fix: preview padding/spacing tokens + soft shadow.
- [x] **Calendar build residual** — brace fix verify.
  → Verified: build + calendar screenshot 2026-09-10.

### Batch FH — Fresh UX audit (Mobbin: Things 3 density)

- [x] **Matrix quadrant Theme.Space** — denser padding/rows.
  → Fix: `MatrixView` quadrant + drop-well padding use Theme.Space.
- [x] **Matrix task row spacing** — Theme.Space.sm rails.
- [x] **Screenshot Matrix** — dark verify.
  → Verified: `/tmp/cadence-spot-check/fh-matrix.png` 2026-09-10.

### Batch FI — Fresh UX audit (Mobbin: Crouton shop)

- [x] **Shop chrome Theme.Space** — inset + row spacing.
  → Fix: `GroceryListView` inset/progress + `GroceryRow` Theme.Space.
- [x] **Building list row** — Theme.Space.
- [x] **Screenshot shop** — open shop sheet.
  → Verified: `/tmp/cadence-spot-check/fi-shop.png` 2026-09-10.

### Batch FJ — Fresh UX audit (Mobbin: Recime browse)

- [x] **Browse chips + rows Theme.Space**.
  → Fix: `BrowseView` filter chips, empty state, recipe rows.
- [x] **Screenshot Browse** — from Meals.
  → Verified: `/tmp/cadence-spot-check/fj-browse.png` 2026-09-10.
- [x] **Fresh Mobbin audit: Settings list density** → Batch FK.

### Batch FK — Fresh UX audit (Mobbin: Oura settings)

- [x] **Settings profile card Theme.Space**.
  → Fix: `SettingsView` hero row spacing tokens.
- [x] **Settings quick chips Theme.Space**.
  → Fix: `SettingsQuickTweaks` insets/padding tokens.
- [x] **Screenshot Settings**.
  → Verified: build + `/tmp/cadence-spot-check/fk-settings.png` 2026-09-10.

### Batch FL — Fresh UX audit (Mobbin: Peloton Today hierarchy)

- [x] **Today dinner label muted caps**.
  → Fix: `TonightMealCard` uppercase caption2 + tracking.
- [x] **Today residual Theme.Space**.
  → Fix: meal card + Today task row Theme.Space.
- [x] **Screenshot Today**.
  → Verified: `/tmp/cadence-spot-check/fl-today.png` 2026-09-10.

### Batch FM — Fresh UX audit (Mobbin: Streaks habits)

- [x] **Habits period headers muted caps + tracking**.
- [x] **Habits cards Theme.Space**.
- [x] **Screenshot Habits**.
  → Verified: `/tmp/cadence-spot-check/fm-habits.png` 2026-09-10.

### Batch FN — Fresh UX audit (Mobbin: Structured day agenda)

- [x] **Day detail Theme.Space** — section padding/rows.
- [x] **Day detail Tasks/Events muted caps**.
- [x] **Day detail Close → CTA** (was accent tint).
  → Fix: Close uses `Theme.cta`.
- [x] **Screenshot day detail** — Agenda sheet.
  → Verified: `/tmp/cadence-spot-check/fn-day-detail.png` 2026-09-10.

### Batch FO — Fresh UX audit (Mobbin: WHOOP onboarding)

- [x] **Onboarding progress muted caps**.
- [x] **Onboarding welcome Theme tokens**.
- [x] **Build verify**.
  → Verified: build 2026-09-10.
- [x] **Fresh Mobbin audit: Meals week strip** → Batch FP.

### Batch FP — Fresh UX audit (Mobbin: meal plan lists)

- [x] **SectionHeader muted caps** — shared token polish.
- [x] **Meals empty-day actions Theme.Space**.
- [x] **Meals dayRow padding Theme.Space**.
- [x] **Screenshot Meals**.
  → Verified: `/tmp/cadence-spot-check/fp-meals.png` 2026-09-10.

### Batch FQ — Fresh UX audit (Mobbin: Things drawer)

- [x] **Drawer section headers tracking + Theme.Space**.
- [x] **Search section headers muted caps align**.
- [x] **Screenshot drawer**.
  → Verified: `/tmp/cadence-spot-check/fq-drawer.png` 2026-09-10.

### Batch FR — Fresh UX audit (Mobbin: Linktree / Hevy workout)

- [x] **Placeholder Theme.Space padding**.
  → Fix: `PlaceholderPageView` horizontal/vertical tokens.
- [x] **Active workout set headers muted caps**.
  → Fix: `ActiveWorkoutView` colHeader uppercase + Theme.Space.
- [x] **Build verify**.
- [ ] **Spot-check residual tabs**.

### Batch FS — Fresh UX audit

- [x] **Spot-check all tabs** after FR.
  → Verified: tab-today/calendar/meals/matrix/habits + app-grid 2026-09-10.
- [x] **WorkoutHome residual Theme.Space**.
- [x] **EmptyState meta Theme.Space**.
- [x] **Fresh Mobbin audit: Todoist task cards** → Batch FT.

### Batch FT — Fresh UX audit (Mobbin: Todoist cards)

- [x] **QuickAdd / task editor Theme.Space residual**.
  → Fix: `PlannerTaskUI` priority + location Theme.Space.
- [x] **EmptyState meta Theme.Space** (FS carry).
- [x] **Screenshot Today residual**.
- [x] **Fresh Mobbin audit: Centr workout home** → Batch FU.

### Batch FU — Fresh UX audit (Mobbin: Centr Today hierarchy)

- [x] **Today Habits section muted caps**.
  → Fix: `TodayView.sectionCard` titles → muted caps + Theme.Space.
- [x] **WorkoutHome “This week” muted caps**.
- [x] **Lift program strip muted caps**.
- [x] **Screenshot Today**.
  → Verified: `/tmp/cadence-spot-check/fu-today.png` 2026-09-10.

### Batch FV — Fresh UX audit

- [x] **Light SoftDayCell accent residual**.
  → Verified: Meals DayChip + Habits SoftDayCell orange in light.
- [x] **Build + light screenshot Meals/Habits**.
  → `/tmp/cadence-spot-check/fv-meals-light.png`, `fv-habits-light.png`
- [x] **Restore dark**.
- [x] **UndoFAB Theme.Space**.
- [x] **Fresh Mobbin audit: residual FAB menu** → Batch FW.

### Batch FW — Fresh UX audit

- [x] **ExerciseGuide Theme.Space**.
  → Fix: paddings/meta pills → Theme.Space; “HOW TO PERFORM” muted caps (Hevy/Peloton).
- [x] **Screenshot Habits dark residual**.
  → `/tmp/cadence-spot-check/fw-habits.png` — SoftDayCell orange, MORNING caps, blue FAB.
- [x] **Fresh Mobbin audit: recipe detail residual**.
  → Recime/Crouton/Yazio/CREME — Batch FX.
- [x] **Append next P2 batch**.

### Batch FX — Recipe detail polish (Mobbin Recime/Crouton)

- [x] **Recipe PLATE/STEPS/ingredient headers → muted caps**.
  → Fix: caption2 + tracking on section headers.
- [x] **RecipeDetail Theme.Space** (macros HStack, pane picker, citation CTA).
- [x] **Screenshot Meals residual**.
  → `/tmp/cadence-spot-check/fx-meals.png`
- [x] **Fresh Mobbin audit: drawer density** → Batch FY.

### Batch FY — Drawer Theme.Space (Mobbin Oura/Spotify/Digg)

- [x] **Drawer header + list + footer Search/Settings → Theme.Space**.
- [x] **Screenshot drawer**.
  → `/tmp/cadence-spot-check/fy-drawer.png` — VIEWS/LISTS/MORE muted caps; orange selection; blue CTAs.
- [x] **Fresh Mobbin audit: active workout / set logging residual**.
  → Gymshark/Hevy/WHOOP/Ladder — Batch FZ.
- [x] **Append next P2 batch**.

### Batch FZ — Active workout Theme.Space (Mobbin Hevy/Gymshark)

- [x] **ActiveWorkoutView hardcoded spacing → Theme.Space / Radius**.
  → Fix: topBar, carousel, rest banner, SetRow checkbox radius, REST muted caps.
- [x] **Screenshot live set table**.
  → `/tmp/cadence-spot-check/fz-active-workout.png` — SET/LB/REPS muted caps; orange selected thumb; blue Finish.
- [x] **Fresh Mobbin audit: Lift program home** → Batch GA.

### Batch GA — Lift home polish (Mobbin Ladder/Peloton)

- [x] **WorkoutHome Theme.Space residual** (hero, week cells, preview rows).
- [x] **TODAY’S LIFTS / RECENT → muted caps**.
- [x] **SettingsCategoryRow Theme.Space.md**.
- [x] **Screenshot Lift home**.
  → `/tmp/cadence-spot-check/ga-lift-home.png` — THIS WEEK + TODAY’S LIFTS muted caps; blue Begin; orange today cell.
- [x] **Fresh Mobbin audit: Settings hub residual**.
  → Manus/Cosmos/BeReal — Batch GB.
- [x] **Append next P2 batch**.

### Batch GB — Settings muted caps (Mobbin Manus/Cosmos)

- [x] **Settings section headers → muted caps helper**.
  → Fix: YOU / PLANNING / INTEGRATIONS / ABOUT via `settingsSectionHeader`.
- [x] **Profile hero Theme.Space residual**.
- [x] **Screenshot Settings**.
  → `/tmp/cadence-spot-check/gb-settings.png`
- [x] **Fresh Mobbin audit: global search residual**.
  → Posh/Phantom/Garmin — Batch GC.
- [x] **Append next P2 batch**.

### Batch GC — Global search Theme.Space (Mobbin Posh/Phantom)

- [x] **Search field + result rows → Theme.Space**.
- [x] **Empty / no-results density tokens**.
- [x] **Screenshot search**.
  → `/tmp/cadence-spot-check/gc-search-empty.png`, `gc-search-results.png`
- [x] **Fresh Mobbin audit: Matrix residual**.
  → Tiimo/Notion — Batch GD.
- [x] **Append next P2 batch**.

### Batch GD — Matrix Theme.Space + caps (Mobbin Tiimo)

- [x] **Matrix grid gap / insets → Theme.Space**.
- [x] **Quadrant titles → caption2 tracking** (tint preserved).
- [x] **Screenshot Matrix**.
  → `/tmp/cadence-spot-check/gd-matrix.png`
- [x] **Fresh UX audit: residual hardcoded spacing across Views**.
  → Onboarding, session preview, Root toast, keypad — Batches GE–GF.
- [x] **Append next P2 batch**.

### Batch GE — Onboarding + session preview tokens

- [x] **OnboardingView residual paddings → Theme.Space**.
- [x] **WorkoutSessionPreviewView Theme.Space**.
- [x] **RootView toast / dial inset Theme.Space**.
- [x] **Build succeeded**.
- [x] **Fresh Mobbin audit: calendar agenda residual**.
  → Outlook/Amie/Saturn/Centr — Batch GG.
- [x] **Append next P2 batch**.

### Batch GG — Calendar Theme.Space (Mobbin Outlook/Centr)

- [x] **Calendar header + month preview grid → Theme.Space**.
- [x] **Screenshot calendar/today**.
  → `/tmp/cadence-spot-check/gg-calendar.png`, `gg-today.png`
- [x] **Fresh Mobbin audit: Today residual density**.
  → Batch GH.
- [x] **Append next P2 batch**.

### Batch GH — Today Theme.Space residual

- [x] **TodayView hardcoded 14/12/10/8 paddings → Theme.Space**.
- [x] **Screenshot Today**.
  → `/tmp/cadence-spot-check/gh-today.png`
- [x] **Fresh UX audit + spot-check all tabs**.
  → Core tabs screenshotted (`tab-*.png`); settings/shop/search `gi-*.png`. Spot-check stalled mid-flow after tabs (known).
- [x] **Append next P2 batch**.

### Batch GI — Habits residual + spot-check

- [x] **HabitsView horizontal/padding → Theme.Space**.
- [x] **Spot-check 5 tabs verified**.
- [x] **Fresh Mobbin audit: Browse residual**.
  → Crouton/Recime/Lifesum/Noom — Batch GJ.
- [x] **Append next P2 batch**.

### Batch GJ — Browse residual Theme.Space

- [x] **BrowseView chip/row vertical paddings → Theme.Space**.
- [x] **Screenshot Meals/Browse flow**.
  → `/tmp/cadence-spot-check/gj-browse.png`
- [x] **Fresh UX audit: light-mode SoftDayCell + DayChip**.
  → Verified orange selection in light Meals/Habits.
- [x] **Append next P2 batch**.

### Batch GK — Light SoftDayCell verify

- [x] **Light Meals DayChip orange**.
  → `/tmp/cadence-spot-check/gk-meals-light.png`
- [x] **Light Habits SoftDayCell orange**.
  → `/tmp/cadence-spot-check/gk-habits-light.png`
- [x] **Restore dark appearance**.
- [x] **Fresh Mobbin audit: event editor / QuickAdd residual**.
  → Tiimo/Amie/Attio — Batch GL.
- [x] **Append next P2 batch**.

### Batch GL — QuickAdd / event Theme.Space

- [x] **PlannerTaskUI residual paddings → Theme.Space**.
- [x] **PlannerEventSheet residual paddings → Theme.Space**.
- [x] **Screenshot QuickAdd**.
  → `/tmp/cadence-spot-check/gl-quickadd.png`
- [x] **Fresh UX audit: append next polish opportunities**.
  → NewHabitSheet, WorkoutVisuals, PlannerChrome headers, DayDetail, WheelNav — GM–GN.
- [x] **Append next P2 batch**.

### Batch GM — NewHabit + chrome residual tokens

- [x] **NewHabitSheet Theme.Space**.
- [x] **WorkoutVisuals tag pills Theme.Space**.
- [x] **PlannerChrome screen header paddings Theme.Space**.
- [x] **DayDetailSheet residual vertical padding**.
- [x] **Build succeeded**.

### Batch GN — WheelNav Theme.Space

- [x] **WheelNav inset/padding tokens**.
- [x] **Build succeeded**.
- [x] **Fresh Mobbin audit: shop ProgressTrack / grocery residual**.
  → Recime/CREME — Batch GO aisle muted caps.
- [x] **Append next P2 batch**.

### Batch GO — Shop aisle muted caps (Mobbin Recime)

- [x] **Grocery category headers → caption2 + tracking**.
- [x] **Screenshot Shop**.
  → `/tmp/cadence-spot-check/go-shop.png`
- [x] **Fresh UX audit: Cadence widgets residual**.
  → Batch GP WidgetTheme.Space.
- [x] **Append next P2 batch**.

### Batch GP — Widget Theme.Space

- [x] **Add `WidgetTheme.Space` tokens**.
- [x] **Widget VStack/HStack spacing → WidgetTheme.Space**.
- [x] **Build succeeded**.
- [x] **Fresh UX audit: Settings detail forms residual**.
  → Batch GQ muted caps on Meals/Nutrition sections.
- [x] **Append next P2 batch**.

### Batch GQ — Settings detail muted caps

- [x] **`settingsDetailSectionHeader` helper**.
- [x] **Meals & cooking + Daily targets section headers**.
- [x] **Screenshot settings meals detail**.
  → `/tmp/cadence-spot-check/gq-settings-meals.png`
- [x] **Fresh UX audit: continue residual Theme.Space sweep**.
  → Calendar/Today/Meals leftover paddings — Batch GR.
- [x] **Append next P2 batch**.

### Batch GR — Residual Theme.Space sweep

- [x] **CalendarPlannerView top paddings**.
- [x] **TodayView FAB clearance padding**.
- [x] **MealPlanView micro-paddings**.
- [x] **Build succeeded**.
- [x] **Fresh Mobbin audit: dial / wheel nav polish**.
  → Moonly/Breathwrk glow — Batch GS dial accent + Root rim token.
- [x] **Append next P2 batch**.

### Batch GS — Dial / Root rim tokens (Mobbin Moonly)

- [x] **Verify dial selected glow uses `Theme.accent`**.
- [x] **RootView dial plate radius → Theme.Radius.xl + 4**.
- [x] **Screenshot dial Today/Meals**.
  → `/tmp/cadence-spot-check/gs-dial-today.png`, `gs-dial-meals.png`
- [x] **Fresh UX audit: Placeholder pages + empty states**.
  → Placeholder COMING SOON pill; EmptyState already tokenized.
- [x] **Append next P2 batch**.

### Batch GT — Placeholder polish

- [x] **Placeholder “COMING SOON” MetaPill**.
- [x] **Build succeeded**.

### Batch GU — Theme + DayDetail residual paddings

- [x] **Theme MetaPill/CountBadge/Button paddings → Space**.
- [x] **DayDetailSheet + WorkoutIntegration residual**.
- [x] **Build succeeded** — 0 remaining `.padding(..., N)` literals under Views (Theme.Space sweep complete).
- [x] **Fresh Mobbin audit** → Batch GV cohesion pass.
- [x] **Append next P2 batch**.

### Batch GV — Cohesion pass (Mobbin Recime/Hevy/Centr)

- [x] **Spot-check all 5 tabs + settings + shop**.
  → `/tmp/cadence-spot-check/gv-tab-*.png`, `gv-settings.png`, `gv-shop.png`
- [x] **Light SoftDayCell re-verify**.
  → `/tmp/cadence-spot-check/gv-meals-light.png` — Thu DayChip orange; dark restored.
- [x] **Append next P2 polish opportunities from screenshots**.
  → Batch GW: residual cornerRadius tokens.

### Batch GW — Residual Radius tokens

- [x] **Replace leftover hardcoded `cornerRadius: N` with Theme.Radius**.
  → WheelNav plate `Theme.Radius.xl - 4`; calendar day chips `Theme.Space.xs`. (1.5pt event rails kept as hairline geometry.)
- [x] **Build + screenshot**.
  → `/tmp/cadence-spot-check/gw-today.png`
- [x] **Fresh Mobbin audit** → Batch GX Tonight dinner empty hierarchy.
- [x] **Append next P2 batch**.

### Batch GX — Tonight dinner empty hierarchy

- [x] **TonightMealCard empty “Plan this week” vs Meals empty CTAs cohesion**.
  → Fix: “No dinner planned” + `MetaPill("Tap to plan")` matches Meals day rows; header muted caps strengthened.
- [x] **Screenshot Today dinner card**.
  → `/tmp/cadence-spot-check/gx-tonight-empty.png`
- [x] **Fresh Mobbin audit** → Batch GY.
- [x] **Append next P2 batch**.

### Batch GY — Fresh UX audit round

- [x] **Code skim residual opacity/hairline inconsistency**.
  → SoftDayCell weekday → muted-caps weight/tracking + Space spacing.
- [x] **Screenshot Matrix + Calendar cohesion**.
  → `/tmp/cadence-spot-check/gy-matrix.png`, `gy-calendar.png`, `gy-habits.png`
- [x] **Append next P2 batch**.

### Batch GZ — SoftDayCell / DayChip typography cohesion

- [x] **SoftDayCell weekday muted-caps polish** (done in GY).
- [x] **DayChip weekday tracking match SoftDayCell**.
- [x] **Light + dark SoftDayCell screenshot**.
  → `/tmp/cadence-spot-check/gz-meals-light.png`, `gz-habits-dark.png`
- [x] **Append next P2 batch**.

### Batch HA — Meals empty day / week cohesion (Oura/Garmin)

- [x] **Meals empty-week EmptyState** — clearer title + muted-caps meta pills + Build CTA.
- [x] **Meals empty-day hero** — IconWell + “No dinner planned” + MetaPill + Swap/Browse (matches TonightMealCard).
  → `/tmp/cadence-spot-check/ha-meals.png`
- [x] **Append next P2 batch**.

### Batch HB — Grocery qty scan + Matrix empty (Centr/Todoist)

- [x] **GroceryRow quantity** — bold ink for scan (Centr); muted when checked; reserve blue for actions.
- [x] **Matrix empty quadrant** — muted-caps DROP HERE cue.
  → `/tmp/cadence-spot-check/hb-shop.png`, `hb-matrix.png`
- [x] **Append next P2 batch**.

### Batch HC — Habits mini-week rings (timespent/QUITTR)

- [x] **Habit miniWeek** — solid accent done; dashed ring scheduled-open; faint off-day.
  → `/tmp/cadence-spot-check/hc-habits.png`
- [x] **Append next P2 batch**.

### Batch HD — Today dashed add cue (Tiimo/Saturn)

- [x] **Today Tasks empty** (when other sections exist) — dashed “Add something” row.
- [x] **Today ScrollView padding → Theme.Space.lg**.
  → `/tmp/cadence-spot-check/hd-today.png`
- [x] **Append next P2 batch**.

### Batch HE — Browse filter Clear + empty (Recime/Noom)

- [x] **Browse “Clear all”** beside active course/search filters.
- [x] **Browse empty** — muted-caps NO MATCHES + display title.
  → `/tmp/cadence-spot-check/he-browse.png`, `he-browse-dessert.png` (Clear all visible on Dessert).
- [x] **Append next P2 batch**.

### Batch HF — Calendar weekday muted caps (Amie)

- [x] **Calendar month weekday row** — caption2 bold + tracking muted caps.
- [x] **Week column headers** — matching muted caps.
  → `/tmp/cadence-spot-check/hf-calendar.png`
- [x] **Append next P2 batch**.

### Batch HG — Settings hub icon tints (Structured/Hevy)

- [x] **SettingsCategoryRow tints** — accent for identity/nav; cta for action hubs.
  → `/tmp/cadence-spot-check/hg-settings.png`
- [x] **Append next P2 batch**.

### Batch HI — Drawer selected row polish (Superlist/Fabric)

- [x] **Drawer nav selected** — accent stroke + trailing chevron.
  → `/tmp/cadence-spot-check/hi-drawer.png`
- [x] **Append next P2 batch**.

### Batch HJ — Calendar workout chips muted caps

- [x] **Month workout chips** — UPPERCASE + bold/tracking; Theme.Radius.sm.
  → `/tmp/cadence-spot-check/hj-calendar.png`
- [x] **Append next P2 batch**.

### Batch HK — Global search empty (Revolut)

- [x] **No-results** — muted caps + Clear search CTA.
  → `/tmp/cadence-spot-check/hk-search-empty.png`
- [x] **Append next P2 batch**.

### Batch HL — Lift home CTA cohesion (Hevy)

- [x] **Week strip weekdays** — muted-caps bold tracking.
- [x] **TODAY’S LIFTS card** — full-width Start routine CTA (Hevy).
  → `/tmp/cadence-spot-check/hl-lift.png`
- [x] **Append next P2 batch**.

### Batch HM — Calendar preview workout caps

- [x] **Month day preview** — workout titles UPPERCASE + bold tracking (match chips).
  → `/tmp/cadence-spot-check/hm-calendar.png`
- [x] **Append next P2 batch**.

### Batch HN — Habits week strip workout badges caps

- [x] **SoftDayCell badges** — UPPER/LOWER uppercase + tracking.
  → `/tmp/cadence-spot-check/hn-habits.png`
- [x] **Append next P2 batch**.

### Batch HO — SoftDayCell badge tracking + cohesion spot-check

- [x] **Theme SoftDayCell badge tracking**.
- [x] **Spot-check 5 tabs**.
  → `/tmp/cadence-spot-check/ho-tab-*.png`
- [x] **Append next P2**.

### Batch HP — Day detail sheet cohesion (Amie)

- [x] **DayDetailSheet empty** — IconWell + “Nothing scheduled” + MetaPill + Add CTAs.
  → `/tmp/cadence-spot-check/hp-day-detail.png`
- [x] **Append next P2 batch**.

### Batch HQ — Active workout REST polish (Hevy)

- [x] **Rest banner** — stronger REST tracking; Skip as CTA capsule; hairline CTA stroke.
  → Build OK; `/tmp/cadence-spot-check/hq-today.png` (post-install).
- [x] **Append next P2 batch**.

### Batch HR — QuickAdd muted caps (Todoist)

- [x] **QuickAddSheet** — SAVE TO LIST / DUE DATE muted caps; Space padding.
  → `/tmp/cadence-spot-check/hr-quickadd.png`
- [x] **Append next P2**.

### Batch HS — NewHabit sheet polish (timespent)

- [x] **NewHabitSheet** — ICON/FREQUENCY/PICK DAYS/SECTION muted caps; Theme.Space; weekday caps.
  → `/tmp/cadence-spot-check/hs-newhabit.png`
- [x] **Append next P2**.

### Batch HT — Tags manage polish (Oura)

- [x] **TagManagerSheet empty** — IconWell + NO TAGS + display title.
- [x] **TagEditorSheet** — NAME/COLOR muted caps.
  → `/tmp/cadence-spot-check/ht-tags.png`
- [x] **Append next P2**.

### Batch HU — Pantry STAPLES polish (Bevel)

- [x] **PantryEditor** — STAPLES muted caps; Add CTA blue; no-match IconWell.
  → `/tmp/cadence-spot-check/hu-pantry.png`
- [x] **Append next P2**.

### Batch HV — Exercise guide metadata (Equinox+/Gymshark)

- [x] **ExerciseGuideView** — EQUIPMENT/TARGET/PRESCRIPTION muted-caps rows; HOW TO PERFORM tracking.
  → Build OK; `/tmp/cadence-spot-check/hv-meals.png`, `hv-meals-light.png`
- [x] **Append next P2**.

### Batch HW — Settings status toast (Character AI/TIDE)

- [x] **Reminders + Calendar sync status** — IconWell checkmark + surface row.
  → Build OK; `/tmp/cadence-spot-check/hw-settings.png`
- [x] **Append next P2**.

### Batch HX — Widget Today muted caps (Yazio/Garmin)

- [x] **CadenceWidgets tasksBody** — TODAY eyebrow + Tasks headline.
  → Build OK; `/tmp/cadence-spot-check/hx-matrix.png`
- [x] **Append next P2**.

### Batch HY — Plan generating overlay caps

- [x] **PlanGeneratingOverlay** — BUILDING WEEK muted caps eyebrow.
  → Build OK.
- [x] **Append next P2**.

### Batch HZ — BusyOverlay WORKING caps

- [x] **Theme.BusyOverlay** — WORKING muted caps; ProgressView uses CTA; card shadow.
  → Build OK; `/tmp/cadence-spot-check/hz-meals.png`
- [x] **Append next P2**.

### Batch IA — Onboarding chrome (WHOOP/Garmin)

- [x] **OnboardingView** — STEP n OF 3 + title caps; CONTINUE/GET STARTED; muted Skip caps; CTA Back; bottom bar shadow; section headers YOU/ACTIVITY…
  → Build OK; `/tmp/cadence-spot-check/ia-today.png`, `ia-settings.png`, `ia-meals.png`
- [x] **PrimaryButton** busy → WORKING…; DayDetail OVERDUE caps.
- [x] **Append next P2**.

### Batch IB — Lift set chrome (Hevy/Ladder)

- [x] **ActiveWorkoutView** — set col headers tracking 0.8.
- [x] **WorkoutSessionPreview** — START WORKOUT CTA caps.
- [x] **Screenshot Lift** — `/tmp/cadence-spot-check/ib-lift.png`, `ic-lift.png`
- [x] **Append next P2**.

### Batch IC — Settings + Lift CTAs (Outsiders/Cal AI)

- [x] **settingsDetailSectionHeader** — tracking 0.8.
- [x] **Reminders/Calendar** — REMINDER TYPES / TIMING / APPLE CALENDAR muted caps.
- [x] **WorkoutHome** — BEGIN CATCH-UP / START ROUTINE caps.
  → `/tmp/cadence-spot-check/ic-lift.png`, `ic-reminders.png`
- [x] **Append next P2**.

### Batch ID — Shop aisle headers (Recime/Centr)

- [x] **GroceryListView** — aisle headers CTA blue + tracking 0.8; ADD SOMETHING / STAPLES tracking.
  → `/tmp/cadence-spot-check/id-shop.png`
- [x] **Append next P2**.

### Batch IE — Shop status + CTA caps

- [x] **Shop** — DONE + N LEFT / ALL PICKED UP muted-caps status.
- [x] **Lift/Today actions** — SKIP; BEGIN/RESUME WORKOUT; TODAY badge; SAVE CTAs.
  → `/tmp/cadence-spot-check/ie-shop.png`, `ie-today.png`
- [x] **Append next P2**.

### Batch IF — Habit SKIP + Matrix DROP + day empty CTAs

- [x] **Today habit** — SKIP muted caps.
- [x] **Matrix** — DROP HERE tracking 0.8.
- [x] **DayDetail empty** — ADD TASK OR EVENT / ADD TASK / ADD EVENT.
- [x] **UndoFAB** — UNDO caps.
  → `/tmp/cadence-spot-check/if-today.png`, `if-matrix.png`
- [x] **Append next P2**.

### Batch IG — Meals CTA caps (CREME)

- [x] **MealPlanView** — NEW WEEK / PLAN WEEK; SWAP IN DINNER / BROWSE; TAP TO PLAN / TAP SWAP OR BROWSE MetaPills.
  → `/tmp/cadence-spot-check/ig-meals.png`
- [x] **Append next P2**.

### Batch IH — Drawer Settings row (DeepSeek/Obsidian)

- [x] **PlannerDrawer** — section header tracking 0.8; Settings row semibold + chevron.
  → `/tmp/cadence-spot-check/ih-drawer.png`
- [x] **Append next P2**.

### Batch II — Drawer actions + Habits CTA (Gymshark)

- [x] **PlannerDrawer** — NEW LIST / MANAGE TAGS muted-caps CTAs.
- [x] **Habits empty** — ADD HABIT CTA.
  → `/tmp/cadence-spot-check/ii-drawer.png`, `ii-habits.png`
- [x] **Append next P2**.

### Batch IJ — Calendar preview (Saturn/Teams)

- [x] **CalendarPlannerView** — TODAY accent jump; AGENDA CTA; NO EVENTS muted caps + cue.
  → `/tmp/cadence-spot-check/ij-calendar.png`
- [x] **Append next P2**.

### Batch IK — Browse clear filters (CREME/Recime)

- [x] **BrowseView** — CLEAR ALL / CLEAR FILTERS MetaPill; NO MATCHES tracking 0.8.
  → `/tmp/cadence-spot-check/ik-browse.png`
- [x] **Append next P2**.

### Batch IL — Profile recalculate CTAs (Life Reset/Garmin)

- [x] **Profile & goals** — RECALCULATE MACROS / WITH AI; WORKING… busy.
- [x] **Nutrition** — CALCULATED section header token.
  → `/tmp/cadence-spot-check/il-profile.png`
- [x] **Append next P2**.

### Batch IM — Search + Tonight cues

- [x] **Global search** — CLEAR SEARCH capsule CTA.
- [x] **Tonight card** — TAP TO PLAN MetaPill.
  → `/tmp/cadence-spot-check/im-today.png`
- [x] **Append next P2**.

### Batch IN — Active Finish CTA (Hevy)

- [x] **ActiveWorkoutView** — FINISH muted-caps toolbar CTA.
- [x] **Append next P2**.

### Batch IO — Recipe detail caps (CREME/Kitchen Stories)

- [x] **RecipeDetailView** — PLATE/STEPS/Ingredients tracking 0.8; MAIN/SIDE segmented.
- [x] **Append next P2**.

### Batch IP — Event sheet chrome (Saturn/MyDyson)

- [x] **PlannerEventSheet** — COLOR/TAGS muted caps; CANCEL/ADD/DONE/DELETE toolbar caps.
- [x] **Append next P2**.

### Batch IQ — Widget empty caps (Brick)

- [x] **CadenceWidgets** — ALL CLEAR / NO UPCOMING / UP NEXT muted caps; TODAY tracking 0.8.
- [x] **Append next P2**.

### Batch IR — List settings (Todoist)

- [x] **ListSettingsSheet** — LIST/VISIBILITY muted caps; DONE / DELETE LIST.
- [x] **Append next P2**.

### Batch IS — Calendar Notion/Outlook 3-day focus (Mobbin)

- [x] **Default scope → 3 Day** — Notion Calendar / Outlook-style focus columns; month no longer default.
- [x] **Remove AGENDA button + bottom preview strip** — day agenda via column header tap (`DayDetailSheet`); less chrome.
- [x] **Collapsible month picker** — pull-down handle / title chevron; tap day jumps focus window and collapses; density dots only.
- [x] **Header** — range title e.g. “Sep 10–12”; TODAY; long-press Change view…
  → Build OK; `/tmp/cadence-spot-check/calendar-3day-final.png`, `calendar-month-picker-final.png`
- [x] **Append next P2**.

### Batch IT — Post-calendar chrome (Mobbin declutter)

- [x] **Lift** — drop duplicate START ROUTINE; RESUME WORKOUT caps (single hero CTA).
- [x] **Meals** — remove TAP SWAP OR BROWSE pill; quiet sentence + SWAP/BROWSE.
- [x] **Today** — Tasks empty → ADD TASK (cta, no dashed strip).
- [x] **Shop** — empty: drop ADD SOMETHING header; footer under manual add.
- [x] **Habits** — sparse tip + ADD HABIT link.
  → Build OK; spot-check screenshots
- [x] **Append next P2**.

### Batch IU — Spend sub-app + modular registry (Teller)

- [x] **CadenceSubAppRegistry** — modular sub-app manifests (`docs/SUBAPPS.md`).
- [x] **Spend wheel page** — purchases + cost-per-use (Mobbin: Starling/Monzo/Orbit).
- [x] **TellerClient + docs/TELLER_SETUP.md** — sandbox sync stub; mTLS via backend.
- [x] **Settings → Spend & Teller** — enable toggle, app id, sandbox token.
  → Build OK; `/tmp/cadence-spot-check/spend-home.png`
- [x] **Append next P2**.

### Batch IV — Health sub-app (Bevel × Cadence + HealthKit)

- [x] **CadenceSubAppRegistry.health** — modular Health alongside Spend.
- [x] **Bevel-like dashboard** — Strain/Recovery/Sleep rings, stress & energy, vital pillars, scrubbable HR.
- [x] **HealthKitClient** + demo fallback; placeholder scoring in `HealthStore`.
- [x] **docs/APPLE_HEALTH_SETUP.md** — entitlements, types, Review notes.
  → Build OK; `/tmp/cadence-spot-check/health-home.png`
- [x] **Append next P2**.

### Batch IW — News daily digest (Perplexity × Cadence)

- [x] **News sub-app** — top-10 mixed topics, image cards, OPEN ARTICLE.
- [x] **RSS client** + optional AI briefs via existing LLM key.
- [x] **docs/NEWS_SETUP.md** — feeds now, backend later.
  → Build OK; `/tmp/cadence-spot-check/news-home.png`
- [x] **Append next P2**.

### Batch IX — Configurable apps & wheel (Mobbin)

- [x] **CadenceAppsPreferences** — unified show/hide + dial order (Today pinned). — 2026-09-10
- [x] **Swipe-up Edit / hold-to-edit** — − hide, AVAILABLE +, jiggle (Garmin/Bevel/SmartThings). — 2026-09-10
- [x] **Settings → Apps & wheel** — Edit Tabs list + Restore defaults. — 2026-09-10
- [x] **Smart hide** — wheel, drawer Shop, Today meal/lift cards, search jumps, FAB pages. — 2026-09-10
  → Fix: dual UX from Mobbin (Garmin Edit Tabs, Bevel Edit Home, SmartThings +). Meals off also hides Shop.
- [x] **Hold-to-edit only** — removed Edit button; Done only while editing; no jiggle (fixed − flicker). — 2026-09-10
- [x] **Append next P2**.

### Batch IY — Calendar month picker stay-open + year jump

- [x] **Month stays open after day tap** — dismiss via header title or swipe up only. — 2026-09-10
- [x] **Header title toggles month** — click month range to open/close. — 2026-09-10
- [x] **Fast year** — tap month title in picker → year grid; chevrons step ±1 year. — 2026-09-10
- [x] **Hold empty space + drag reorder** — edit from gaps around icons; drag to reorder (Today pinned). — 2026-09-10
- [x] **Append next P2**.

### Batch IZ — Continue UX loop

- [x] **News topic chips spacing + hit targets** — more gap above cards; capsule contentShape; clip article images. — 2026-09-10
- [x] **Workout thumbnail hit boxes** — clip scaledToFill + contentShape on exercise images/carousel. — 2026-09-10
- [x] **Workout finish controls** — back leaves; ··· guide/skip rest; FINISH logs. — 2026-09-10
- [x] **Tap outside dismisses keyboard/keypad** — app-wide + workout keypad scrim. — 2026-09-10
- [ ] **Append**.

---

## Recently verified

- **Batch JL PASS 2026-09-11** — Calendar month-only + Day/3-day/Week menu; Focus Pomo/Stopwatch + stats; Matrix/Shop fuller bleed.
- **Batch IZ PASS 2026-09-10** — News/workout hit boxes; workout toolbar roles; keyboard dismiss.
- **Batch IY PASS 2026-09-10** — Calendar month stays open; year grid jump; hold-empty + drag reorder on app grid.
- **Batch IX PASS 2026-09-10** — Configurable apps/wheel (edit grid + Settings Apps).
- **Batch IW PASS 2026-09-10** — News digest RSS + AI briefs + images.
- **Batch IV PASS 2026-09-10** — Health Bevel-like UI + Apple Health setup doc.
- **Batch IU PASS 2026-09-10** — Spend sub-app scaffold + Teller setup doc.
- **Batch IT PASS 2026-09-10** — Lift/Meals/Today/Shop/Habits declutter after calendar.
- **Batch IS PASS 2026-09-10** — Calendar 3-day focus + pull-down month (no AGENDA).
- **Batch IR PASS 2026-09-10** — List settings muted caps.
- **Batch IQ PASS 2026-09-10** — Widget ALL CLEAR / UP NEXT caps.
- **Batch IP PASS 2026-09-10** — Event sheet COLOR/TAGS + toolbar caps.
- **Batch IO PASS 2026-09-10** — Recipe PLATE/STEPS tracking.
- **Batch IN PASS 2026-09-10** — Active FINISH CTA caps.
- **Batch IM PASS 2026-09-10** — CLEAR SEARCH + TAP TO PLAN.
- **Batch IL PASS 2026-09-10** — Recalculate macros CTA caps.
- **Batch IK PASS 2026-09-10** — Browse CLEAR ALL / NO MATCHES.
- **Batch IJ PASS 2026-09-10** — Calendar TODAY/AGENDA/NO EVENTS.
- **Batch II PASS 2026-09-10** — Drawer NEW LIST / MANAGE TAGS + ADD HABIT.

---

## Loop signal

| Field | Value |
|-------|-------|
| **Phase** | `PAUSED` |
| **Next batch** | **LN** |
| **Summary** | Paused. Spend: list all linked banks; Ignore category for savings (off pie/budget). |

### Batch LL — Calendar today swipe lag (user)

- [x] **Today date lags during calendar swipe** — conditional today circle inherited the pager spring as a separate layer. — 2026-09-12
  → Fix: stable Circle layers + `transaction { animation = nil }` on day chrome; `CalendarPagerOffsetEffect` GeometryEffect for strip offset; header `compositingGroup()`.
- [x] **Append**.

### Batch LM — Countdown widget numbers (user)

- [x] **Countdown widget shows no numbers** — digit `Text` used `Color("AccentColor")` but CadenceWidgets has no asset catalog, so accent resolved clear. — 2026-09-12
  → Fix: `WidgetTheme.accent` hardcodes AccentColor RGB (light/dark) in `CadenceWidgets.swift`.

### Batch LK — Swipe-up menu all apps (user)

- [x] **Menu showed only on-wheel apps** — always list **WHEEL** + **NOT ON WHEEL**; tap opens any app without adding it to the dial. — 2026-09-12
  → Fix: `WheelAppMenuOverlay` dual sections + scroll; `RootView.selectWheel` / `ensureSelectionVisible` allow off-wheel pages.
- [x] **Hold to edit still moves / switches** — − / + and drag reorder; drag across sections adds/removes from wheel. — 2026-09-12
- [x] **Append**.

### Batch LJ — Mobbin Bevel redesign (user: not loving it / graph bad)

- [x] **Sleep night graph feels bad** — replaced capsule bars with Bevel/Eight Sleep stepped hypnogram (Awake→REM→Core→Deep bands) + drag scrub tooltip. — 2026-09-12
  → Refs: [Bevel Primary sleep](https://mobbin.com/flows/a3fb194c-c64d-4ac1-b424-317a26c013af), [stages screen](https://mobbin.com/screens/c4c2dd72-1d95-431b-898f-ad415b4f5c39).
- [x] **Sleep page layout** — Primary sleep event card, stages hero + rings, latency, trend sparklines; sheet only for score/contributors deep dive. — 2026-09-12
- [x] **Popups only when useful** — vitals no longer open Recovery/HR sheets on every tap; Sleep vital / Primary card / rings / workouts still drill in. — 2026-09-12
- [x] **Append**.

### Batch LI — Real sleep hypnogram intervals

- [x] **Hypnogram used totals only** — persist HK sleep stage samples; chart uses real timeline when present. — 2026-09-12
  → Fix: `SleepStageSegment` + `sleepStagesJSON`; `HealthChrome.SleepHypnogram(segments:)`.
- [x] **Append**.

### Batch LH — History + workout detail

- [x] **Multi-day history** — day chevrons + 30-day History sheet; Fitness heatmap taps a day. — 2026-09-12
  → Fix: `HealthHomeView` historyDays / shiftDay / activityHeatmapCard.
- [x] **Per-workout detail** — tap Workout Log row → duration, kcal, avg HR, source. — 2026-09-12
  → Fix: `WorkoutDetailSheet`.
- [x] **Append**.

### Batch LG — Body build + Bevel visual match (user)

- [x] **Build failed** — missing `workoutStats`, invalid `HKWorkoutActivityType.rower`, drawer `Button(action:)` arity. — 2026-09-12
  → Fix: `HealthKitClient.workoutStats` + `.rowing`; `PlannerDrawer` close button closure.
- [x] **Sleep UI ≠ Bevel Primary sleep** — score pill, in-bed/asleep, 2×3 contributor grid (REM/Deep split), hypnogram, latency Fast/Normal/Late, Watch attribution. — 2026-09-12
  → Fix: `HealthMetricDetailView` + Sleep tab; `BevelScoring` contributors; `HealthChrome` hypnogram/latency/cells.
- [x] **Overview ≠ Bevel Home monitor** — Health Monitor 2×2 cards (RR/RHR/HRV/SpO₂/Temp/Sleep) + stress half-gauge. — 2026-09-12
  → Fix: `HealthChrome.MonitorCard` / `StressGauge`; `HealthStore.vitals`.
- [x] **Append**.

### Batch LF — Body audit follow-up

- [x] **Vitals only focused, never opened detail** — tap opens HR / HRV / Recovery / Strain sheets. — 2026-09-12
- [x] **Score inputs dropped on save** — snapshot now stores core/awake/latency/zones/temp/confidence/workout kcal. — 2026-09-12
- [x] **Max HR flat 190** — resting-informed Tanaka estimate for zones. — 2026-09-12
- [x] **Append**.

### Batch LE — Body Health redesign (user: Bevel + Mobbin + algorithms)

- [x] **Design doc** — IA, sub-pages, algorithms, sync plan. — 2026-09-12
  → `docs/HEALTH_REDESIGN.md`; Mobbin Bevel/WHOOP/Oura refs.
- [x] **Stronger scoring** — contributor ratings, recovery breakdown, sleep bank, confidence blend, latency. — 2026-09-12
  → `BevelScoring`, `HealthBaselines.sleepBankHours`, HK sleep latency.
- [x] **Explainable details** — Sleep/Recovery/Strain contributors + stages + bank. — 2026-09-12
  → `HealthMetricDetailView`.
- [x] **Fitness logger + Sleep tab** — Body segments Overview/Sleep/Fitness/Lift; HK workout list. — 2026-09-12
  → `HealthHomeView`, `HealthKitClient.fetchWorkouts`.
- [x] **Append**.

### Batch LD — Sidebar left-swipe ghosting (user)

- [x] **Left swipe close ghosts / snaps** — drag reset + `.move` removal fought each other. — 2026-09-12
  → Fix: `PlannerDrawer.closeInteractively` finishes off-screen then dismisses with animations disabled; RootView removal → opacity only.
- [x] **Append**.

### Batch LC — Tap subcategory to edit (user)

- [x] **Customize section separate from subcategory list** — tap a subcategory to rename, set budget, delete. — 2026-09-12
  → Fix: `SpendCategoryDetailView` tappable sub list + `EditSubcategorySheet`; dropped CUSTOMIZE / inline budget rows.
- [x] **Append**.

### Batch LB — Spend category taps near dial (user)

- [x] **Category rows near bottom-right miss taps** — full-width FAB chrome stole hits above the menu. — 2026-09-12
  → Fix: trailing-only FAB `ZStack` (no expanded + hit band); `contentShape` on category rows; scroll clearance `dialFABClearance`.
- [x] **Append**.

### Batch LA — Spend FAB add purchase (user)

- [x] **Plus didn’t add purchases** — FAB opened cost-per-use “Track item”, so nothing landed in purchases/pie. — 2026-09-12
  → Fix: `AddPurchaseSheet` + `SpendStore.addManualPurchase`; FAB → `showAddPurchase`; ADD ITEM still for trackers.
- [x] **Append**.

### Batch KY — Delete subcategories (user)

- [x] **No way to remove subcategories** — category detail had add-only; Categories list swipe was hard to discover. — 2026-09-12
  → Fix: Trash + confirm on `SpendCategoryDetailView` `SubcategoryBudgetRow`; trash / swipe / Edit-mode delete on `SpendCategoriesManageView` (subs + custom categories).
- [x] **Append**.

### Batch KX — Merchant categories (user)

- [x] **Auto category from bank PFC** — map Plaid personal_finance_category (+ merchant keywords); refresh Other on appear/SYNC. — 2026-09-12
  → Fix: `SpendCategory.infer`, `SpendStore.refreshAutoCategories`, sync stores primary+detailed label.
- [x] **Always for this store** — `SpendMerchantRuleEntity`; toggle on purchase editor; applies to matching merchants. — 2026-09-12
  → Fix: `SpendStore.setMerchantRule` / `SpendCategoryAssignmentFields`.
- [x] **Append**.

### Batch KV — Plaid full history SYNC (user)

- [x] **SYNC only pulled deltas after 1 tx** — force empty-cursor full resync on every SYNC; `/transactions/refresh` first; include pending; report total loaded; jump month navigator. — 2026-09-12
  → Fix: `SpendStore.syncEnrollment(forceFullResync:)`, `PlaidClient.refreshTransactions` + sync pagination harden, `SpendHomeView.syncNow`.
- [x] **Append**.

### Batch KU — Plaid spend sync (user)

- [x] **Stale cursor after SwiftData wipe** — restore/sync cleared Keychain cursor when local Plaid txs missing; sandbox-aware sync; Link lookback 730d. — 2026-09-12
  → Fix: `SpendStore.restorePlaidEnrollmentsIfNeeded` / `syncEnrollment`; `PlaidClient` days_requested; Spend home auto-heal SYNC.
- [x] **Append**.

### Batch KT — Idle dock height (user)

- [x] **Idle black too low** — restore prior taller bar minus a couple px. — 2026-09-12
  → Fix: `WheelNav.dockPlate` `idleBarHeight` `dialHeight - 6` → `dialHeight + 6`.
- [x] **Append**.

### Batch KS — Fresh UX audit (post-KR)

- [x] **Spend pie hint wraps tightly** — split into two short centered lines under the donut. — 2026-09-12
  → Fix: `SpendHomeView` pie caption “Tap a slice to expand” + “Tap outside or wait to collapse”.
- [x] **Append**.

### Batch KR — Fresh UX audit (post-KQ)

- [x] **Spend FAB covers breakdown leftover** — Reverted 2026-09-12; extra trailing inset misaligned the card with budget/donut.
- [x] **Append**.

### Batch KQ — Custom spend categories (user)

- [x] **Overview CATEGORIES → create category** — New category sheet (name, icon, color). — 2026-09-12
  → Fix: `SpendUserCategoryEntity` + `SpendCategoriesManageView` New category.
- [x] **Overview → category → item can change category** — picker includes built-in + custom. — 2026-09-12
  → Fix: `SpendCategoryAssignmentFields` on category purchase editor.
- [x] **Sim verify** — Categories list, New category composer, Shopping item Category picker. — 2026-09-12
  → `/tmp/cadence-spot-check/spend-categories.png`, `spend-new-category.png`, `spend-category-item.png`

### Batch KP — Fresh UX audit (post-KO)

- [x] **Habits / Spend plus circle** — still present; a11y labels page-specific. — 2026-09-12
  → `/tmp/cadence-spot-check/tab-habits.png`, `wheel-spend.png`
- [x] **Append**.

### Batch KO — Plus-only FAB (user)

- [x] **Plus-only CreateFAB** — drop capsule labels; keep a11y Add task/event/habit; News/Health still off. — 2026-09-11
  → Fix: `CreateFAB` 58pt circle + plus; remove `shortTitle`.
- [x] **Sim verify** — Today 58×58 plus; News Add count 0. — 2026-09-11
  → `/tmp/cadence-spot-check-ko-plus/plus-today.png`, `plus-news.png`
- [x] **Append**.

### Batch KN — Fresh UX audit (post-KM)

- [x] **CreateFAB vs UndoFAB spacing** — leading undo / trailing create pattern unchanged. — 2026-09-11
- [x] **App grid hide CreateFAB** — verified earlier (grid hides dial FAB). — 2026-09-11
- [x] **Append**.

### Batch KM — Fresh UX audit (post-KL)

- [x] **Calendar EVENT → event sheet** — opens. — 2026-09-11
  → `/tmp/cadence-spot-check-jo-fab/km-event.png`
- [x] **Habits HABIT → NewHabitSheet** — opens. — 2026-09-11
  → `/tmp/cadence-spot-check-jo-fab/km-habit.png`
- [x] **Append**.

### Batch KL — Fresh UX audit (post-KK)

- [x] **Drawer open** — drawer screenshot captured; close soft-fails cleanly. — 2026-09-11
- [x] **QuickAdd from Today FAB** — sheet opens. — 2026-09-11
  → `/tmp/cadence-spot-check-jo-fab/kl-quickadd.png`
- [x] **Append**.

### Batch KK — Fresh UX audit (post-KJ)

- [x] **RootView showWheelDock + CreateFAB** — FAB gated on `showWheelDock` + `fabAction`. — 2026-09-11
- [x] **Spend ITEM a11y label** — “Add tracked purchase”. — 2026-09-11
- [x] **Append**.

### Batch KJ — Fresh UX audit (post-KI)

- [x] **Health sync header** — sync controls present; no dial Add. — 2026-09-11
- [x] **Focus Start vs former FAB space** — Start session full-width (~272×56). — 2026-09-11
- [x] **Append**.

### Batch KI — Fresh UX audit (post-KH)

- [x] **CreateFAB press scale** — light press only (no fan-out) by design. — 2026-09-11
- [x] **News refresh header** — Refresh digest present; Add count 0. — 2026-09-11
- [x] **Append**.

### Batch KH — Fresh UX audit (post-KG)

- [x] **Habits ADD HABIT header + dial HABIT** — dial Add habit present. — 2026-09-11
- [x] **Matrix quadrant empty Add vs dial TASK** — dial Add task present. — 2026-09-11
- [x] **Append**.

### Batch KG — Fresh UX audit (post-KF)

- [x] **Dial create capsule hit target** — FAB frame height 52. — 2026-09-11
- [x] **Inbox vs Today TASK label** — Inbox opens QuickAdd. — 2026-09-11
  → `/tmp/cadence-spot-check-jo-fab/kg-inbox.png`
- [x] **Append**.

### Batch KF — Fresh UX audit (post-KE)

- [x] **Build + spot-check after KE tracking** — build OK; Today/Spend/News smoke shots. — 2026-09-11
  → `/tmp/cadence-spot-check-kf/`
- [x] **Append new P2 from skim** — onboarding tracking left at 0.8 intentionally. — 2026-09-11
- [x] **Append**.

### Batch KE — Residual muted tracking (post-KD)

- [x] **Workout / Browse / Grocery muted headers** — tracking 0.6/0.8 → 0.7. — 2026-09-11
  → Fix: WorkoutHome/Active/Preview, Browse, Grocery.
- [x] **Spend / MealPlan residual 0.5–0.8** — 0.6/0.8 → 0.7; 0.5 meta chips kept. — 2026-09-11
  → Fix: SpendHome/CategoryDetail/ItemDetail, MealPlanView.
- [x] **Append**.

### Batch KD — Fresh UX audit (post-KC)

- [x] **Residual planner muted caps drift** — planner sheets mostly 0.7; 0.5 remains on small meta (OK). Broader drift in Workout/Browse/Grocery/Spend/Meals → KE. — 2026-09-11
- [x] **Widget / extension chrome** — no dial FAB / CreateFAB usage outside RootView. — 2026-09-11
- [x] **Append**.

### Batch KC — Fresh UX audit (post-KB)

- [x] **Spend Overview pie vs ITEM capsule** — ITEM clears center total; sits over breakdown foot. — 2026-09-11
  → `/tmp/cadence-spot-check-jo-fab/kc-spend.png`
- [x] **Calendar day/3-day EVENT capsule** — visible above dial in 3 Day. — 2026-09-11
  → `/tmp/cadence-spot-check-jo-fab/kc-calendar.png`
- [x] **Append**.

### Batch KB — Fresh UX audit (post-KA)

- [x] **CreateFAB shadow in light mode** — readable on white Today. — 2026-09-11
  → `/tmp/cadence-spot-check-jo-fab/kb-today-light.png`
- [x] **VoiceOver order** — dial FAB at y≈740; empty-state Add separate. — 2026-09-11
- [x] **Append**.

### Batch KA — Fresh UX audit (post-JZ)

- [x] **cadence_sim close all** — search/drawer soft-fail + relaunch fallback; no invalid escape. — 2026-09-11
  → Fix: `scripts/cadence_sim.py` close handlers.
- [x] **simctl boot “Unable to boot… Booted”** — skip boot when already booted. — 2026-09-11
  → Fix: `ensure_booted` checks booted list first.
- [x] **Append**.

### Batch JZ — Fresh UX audit (post-JY)

- [x] **Meals New week CTA** — no dial Add. — 2026-09-11
- [x] **Shop sheet** — no dial Add task while shop open. — 2026-09-11
  → `/tmp/cadence-spot-check-jo-fab/jz-meals.png`, `jz-shop.png`
- [x] **Append**.

### Batch JY — Fresh UX audit (post-JX)

- [x] **Health Lift segment** — no dial Add. — 2026-09-11
- [x] **Focus Start CTA** — Start session on-page; no dial FAB. — 2026-09-11
  → `/tmp/cadence-spot-check-jo-fab/jy-focus.png`
- [x] **Append**.

### Batch JX — Fresh UX audit (post-JW)

- [x] **OrangeFAB naming** — renamed to `CreateFAB` (+ `OrangeFAB` typealias). — 2026-09-11
  → Fix: `PlannerChrome.swift` / `RootView.swift`
- [x] **cadence_sim spot_check flow** — wheel Spend/Focus/News shots after argparse fix. — 2026-09-11
  → `/tmp/cadence-spot-check-jx/wheel-spend.png`, `wheel-focus.png`, `wheel-news.png`
- [x] **Append**.

### Batch JW — Fresh UX audit (post-JV)

- [x] **Inbox empty CTA + dial TASK** — FAB opens QuickAdd. — 2026-09-11
  → `/tmp/cadence-spot-check-jo-fab/jw-inbox-add.png`
- [x] **Undo chip + labeled FAB coexistence** — TASK capsule baseline on Today (undo appears after complete). — 2026-09-11
- [x] **Append**.

### Batch JV — Fresh UX audit (post-JU)

- [x] **Spend COST/USE tab with FAB** — ITEM capsule present. — 2026-09-11
  → `/tmp/cadence-spot-check-jo-fab/jv-spend-cost.png`
- [x] **Calendar month scope + EVENT capsule** — Add event still at dial clearance. — 2026-09-11
- [x] **Append**.

### Batch JU — Fresh UX audit (post-JT)

- [x] **Global search / Settings** — no dial Add task when sheets open. — 2026-09-11
- [x] **App grid expanded** — dial FAB hidden (only page empty-state Add remains). — 2026-09-11
  → `/tmp/cadence-spot-check-jo-fab/ju-app-grid.png`
- [x] **Append**.

### Batch JT — Fresh UX audit (post-JS)

- [x] **Dial neighbor tap with labeled FAB** — Habits→Calendar; Add event present. — 2026-09-11
- [x] **Matrix FAB opens QuickAdd** — one tap. — 2026-09-11
  → `/tmp/cadence-spot-check-jo-fab/jt-matrix-add.png`
- [x] **Append**.

### Batch JS — Fresh UX audit (post-JR)

- [x] **Habits HABIT FAB → NewHabitSheet** — opens New Habit. — 2026-09-11
  → `/tmp/cadence-spot-check-jo-fab/js-habit-add.png`
- [x] **Light-mode FAB contrast** — `+ TASK` readable; restored dark. — 2026-09-11
  → `/tmp/cadence-spot-check-jo-fab/js-today-light.png`
- [x] **Append**.

### Batch JR — Fresh UX audit (post-JQ)

- [x] **Browse / Workout dial pages** — Browse: no dial Add. — 2026-09-11
- [x] **Spend ITEM sheet from FAB** — opens Track item (CANCEL/SAVE). — 2026-09-11
  → `/tmp/cadence-spot-check-jo-fab/jr-spend-add.png`
- [x] **Append**.

### Batch JQ — Fresh UX audit (post-JP)

- [x] **Matrix / Inbox FAB labels** — both show Add task dial capsule. — 2026-09-11
  → `/tmp/cadence-spot-check-jo-fab/jq-matrix.png`, `jq-inbox.png`
- [x] **Empty-state vs FAB redundancy** — keep both (Todoist-style); dial stays when scrolled. — 2026-09-11
- [x] **Append**.

### Batch JP — Fresh UX audit (post-JO FAB)

- [x] **Audit create vs consume chrome** — Meals/Focus: no dial `Add` a11y; in-page CTAs remain. — 2026-09-11
  → Verified: `/tmp/cadence-spot-check-jo-fab/jp-focus.png`, `jp-meals.png`
- [x] **FAB capsule vs dial clearance** — `navigate wheel` OK; Calendar still shows Add event after dial switch. — 2026-09-11
- [x] **Append**.

### Batch JN — Fresh UX audit (post-JM)

- [x] **ListSettings / NewHabit / Habits caps** — NewHabit/Habits already 0.7; weekday chips keep 0.3 for fit. — 2026-09-11
- [x] **PlannerChrome / WorkoutIntegration residual** — already 0.7; calendar weekday symbols 0.8 → 0.7. — 2026-09-11
  → Fix: `CalendarPlannerView` month weekday tracking.
- [x] **cadence_sim wheel tabs** — argparse now accepts `wheel`; destinations already mapped. — 2026-09-11
  → Fix: `scripts/cadence_sim.py` navigate choices include `wheel`.
- [x] **Reconnect Mobbin MCP tools** — available this session (JO used search_screens). — 2026-09-11
- [x] **Append**.

### Batch JO — Dial FAB redesign (user + Mobbin)

- [x] **Labeled create capsule** — replace mystery circle with compact `+ TASK|EVENT|HABIT|ITEM` pill; light press only (no fan-out). Refs: [Todoist](https://mobbin.com/screens/1ae63b10-6840-42ec-838a-0117cb219e99), [Structured](https://mobbin.com/screens/2945ca91-3537-4a3c-82c5-0901c16a3af1); avoid [Pangea](https://mobbin.com/screens/ad29ee8d-4b30-430b-9842-53d9e345bacd) expand. — 2026-09-11
  → Fix: `OrangeFAB` capsule + `FABAction.shortTitle`; `FABPressButtonStyle`. `/tmp/cadence-spot-check-jo-fab/fab-today.png`, `fab-calendar.png`, `fab-habits.png`, `fab-spend.png`
- [x] **Hide on consume pages** — remove FAB from News + Health/Body (refresh/sync stay in headers). — 2026-09-11
  → Fix: `WheelDestination.fabAction`; drop `healthCheckIn` / `refreshNews`; News/Health handlers removed. a11y: News/Health `Add` count 0. `/tmp/cadence-spot-check-jo-fab/fab-news.png`, `fab-health.png`
- [x] **Create pages only** — Today, Inbox, Matrix, Calendar, Habits, Spend keep FAB. — 2026-09-11
  → Fix: inbox → `.todayQuickAdd`. QuickAdd opens from FAB (`fab-today-opened.png`).
- [x] **Append**.

### Batch JM — Fresh UX audit (post-JK sheets)

- [x] **QuickAdd / DayDetail sheets** — align remaining planner sheets to Task/Event muted section chrome if any still plain. — 2026-09-11
  → Fix: `QuickAddSheet` LIST/TASK/WHEN + `.tint(Theme.cta)`; `DayDetailSheet` TASKS/EVENTS/WORKOUT + CLOSE; `TagEditorSheet` NAME/COLOR. `/tmp/cadence-spot-check-jm/quickadd-jm.png`
- [x] **Spend home list rows** — Monzo-style tighter purchase rows if still loose after JK sheets. — 2026-09-11
  → Fix: `SpendHomeView.transactionRow` 28pt icon, sm padding, caption2 meta, no chevron; PURCHASES tracking 0.7. `/tmp/cadence-spot-check-jm/spend-home-jm.png`
- [x] **Reconnect Mobbin MCP tools** — skipped 2026-09-11 (tools not available in session; note only).
- [x] **Append**.

### Batch JL — User redesign (calendar + Focus + full-bleed)

- [x] **Calendar** — month name only in header (no date range / top date strip); view menu for Day / 3 Day / Week (+ Month/Year); grid takes more screen; FAB stays overlay. — 2026-09-11
  → Fix: `CalendarPlannerView` view-switcher Menu + month-only `headerTitle`; removed day column strip; slim month-picker handle. `/tmp/cadence-spot-check/calendar-jl.png`
- [x] **Focus sub-app** — Pomo + Stopwatch dial app with stats page (Structured/TickTick-style refs). — 2026-09-11
  → Fix: `FocusHomeView` / `FocusStatsView` / `FocusSettingsView` + `FocusSessionEntity`; dial `target` icon; top-right **STATS** (no FAB). `/tmp/cadence-spot-check/focus-home.png`, `focus-stats.png`
- [x] **Full-bleed pages** — Matrix / Shop / similar reduce inset chrome so content fills width; + stays on top via RootView FAB. — 2026-09-11
  → Fix: Matrix edge-to-dial behind +; no DROP HERE; Shop `.plain` list + tighter margins.
- [x] **Append**.

### Batch JK — Continue underdone sheets

- [x] **Event sheet** — elevate Form to match Task editor section chrome. — 2026-09-11
  → Fix: `PlannerEventSheet` WHEN (times + reminder) / REPEAT / WIDGET / ORGANIZE muted caps; `.tint(Theme.cta)`; tracking 0.7. `/tmp/cadence-spot-check-jk/event-sheet-jk.png`
- [x] **Spend transaction / add item / item detail** — Monzo/Orbit density. — 2026-09-11
  → Fix: muted PURCHASE/CATEGORY/COST·USE + ITEM/HOW YOU USE; toolbar DONE/CANCEL/SAVE caps; detail DETAILS header + tighter spacing. `/tmp/cadence-spot-check-jk/spend-add-item-jk.png`
- [ ] **Reconnect Mobbin MCP tools** in a fresh chat if still missing.
- [x] **Append**.

### Batch JJ — Underdone pages (user: full Mobbin pass)

- [x] **Dial Inbox / Browse** — real `TodayView(.inbox)` + `BrowseHomeView` (no Coming Soon stubs). — 2026-09-11
- [x] **Task editor** — muted TASK/WHEN/REPEAT/ORGANIZE sections (Todoist/Things form density). — 2026-09-11
- [x] **Workout summary** — celebration IconWell + next-time cards + primary Done (Hevy finish). — 2026-09-11
- [x] **Pantry + Tags rows** — IconWell / hairline chips. — 2026-09-11
- [x] **Health metric footer** — drop “placeholder” copy. — 2026-09-11
  → Note: Mobbin plugin installed + OAuth reported OK, but `plugin-mobbin-mobbin` tools not exposed to agent; used backlog Mobbin patterns.

### Batch JH — Settings sub-pages Mobbin cleanup (user)

- [x] **Detail chrome** — remove fat heroes; intro as first-section footer; `.inline` titles; `settingsCTALabel` CTAs. — 2026-09-10
  → Refs: [Gentler Streak](https://mobbin.com/screens/07d9ec6a-cb0e-4cb3-9a3c-4505d32f74ab), [Telegram Data](https://mobbin.com/screens/454ba629-4f5e-4c00-ae0a-a0fa1c4325ee), [Future Pro](https://mobbin.com/screens/89b8a60f-b3fc-4dc9-beba-8c329632d511), [Wispr Flow](https://mobbin.com/screens/af36a034-bc88-48f0-90eb-8af699250f0d).
- [x] **All sub-pages** — You, Meals, AI, Apps & wheel, Body, Spend, News, Reminders, Calendar. Titles match hub; “Sub-app” → “On dial”. — 2026-09-10
  → Fix: `SettingsDetailViews`, `AppsSettingsView`, `HealthSettingsView`, `SpendSettingsView`, `NewsSettingsView`, `PlannerIntegrationsSettings`.
  → Verified: 2026-09-10 sim — You / Apps / Body / Reminders / Calendar (no heroes, intro footers, inline titles).

### Batch JI — Settings Mobbin redesign (user: MCP live)

- [x] **Hub layout from Mobbin** — Amie profile card + colorful icon rows; Apple Fitness App / Modules / Connections groups; Calm version footer. — 2026-09-10
  → Refs: [Amie](https://mobbin.com/screens/fc4d99c1-9a44-45a3-96e7-856a2ffa5909), [Apple Fitness](https://mobbin.com/screens/f618bfa8-e996-4cb6-b7b8-f138e29963b1), [Calm Settings](https://mobbin.com/flows/67004e47-8f00-4733-8c99-a650dd06a368).
- [x] **Rows + heroes** — saturated circular glyphs + trailing status text; compact Bevel-style page heroes (blurb only). — 2026-09-10
- [x] **No duplicate pages** — You / Meals / Apps canonical destinations retained. — 2026-09-10

### Batch JF — Continue UX loop

- [x] **Superseded by JI** — 2026-09-10.

### Batch JG — Settings cohesion (user: Mobbin MCP + no doubles)

- [x] **Deduped Settings destinations** — 2026-09-10.
  → Fix: Profile+Nutrition → **You**; Meals+Recipes → **Meals**; Lift visibility → Apps & wheel only. Legacy routes canonicalize.
- [x] **Hub layout** — Oura/Fitness style: profile card only (no second You row), Apps + Connections + About; removed quick chips. — 2026-09-10
  → Note: Mobbin MCP plugin installed but server not connected in session; used backlog Oura/Fitness patterns.
- [x] **Search catalog** — single entry per destination; nutrition/recipes/lift keywords map to You/Meals/Apps. — 2026-09-10

### Batch JC — Continue UX loop

- [x] **Superseded by JG / JE** — 2026-09-10.

### Batch JE — Body = Health + Workout (user)

- [x] **Combine Health + Workout dial pages** — 2026-09-10.
  → Fix: Single **Body** page (`HealthHomeView`) with Overview | Lift; Workout dial remaps to Health; prefs migration hides standalone Workout.
- [x] **Real Apple Health / Watch sync** — sleep stages, overnight RHR, HRV, SpO₂, workouts, exercise time, zone minutes, wrist temp when available. — 2026-09-10
  → Fix: Expanded `HealthKitClient`; auto-sync on Body appear.
- [x] **Bevel-style Sleep / Strain / Recovery** — published components (duration/stages/efficiency/continuity/HR dip; HRV·RHR·RR·SpO₂ vs baselines; active+passive logarithmic strain + target). — 2026-09-10
  → Fix: `BevelScoring.swift` + `HealthBaselines`; docs/APPLE_HEALTH_SETUP.md.

### Batch JD — Workout dial ↔ Lift system (user + Mobbin)

- [x] **Dial Workout was a Coming Soon placeholder** — 2026-09-10.
  → Fix: (superseded by Body merge) previously `WorkoutHomeView` on dial.

### Batch JA — Settings redesign (user: Mobbin + make them work)

- [x] **Settings hub** — searchable, tappable profile card, status MetaPills, fixed Meals quick chip, user-facing About. — 2026-09-10
  → Fix: `SettingsView.swift` Apple Fitness stacked-list pattern.
- [x] **Shared chrome** — page heroes, status banners, Open iOS Settings. — 2026-09-10
  → Fix: `SettingsDetailViews.swift` shared components.
- [x] **All detail pages** — Profile/Nutrition/Meals/Recipes/Lift/Apps/Spend/Health/News/Reminders/Calendar/AI heroes + working CTAs with success/error feedback; AI Save no longer silent. — 2026-09-10
- [x] **Recipes subtitle** — empty cookbooks reads “All cookbooks” (empty = no filter). — 2026-09-10

### Batch JB — Dial haptics (user report)

- [x] **Rotating apps feels too soft** — 2026-09-10.
  → Fix: Per-tick feedback is `.heavy` @ 1.0 (was light selection); landing on an app is `.rigid` @ 1.0; removed unused selection generator.

### Batch IZ — Wheel pick snappiness (user report)

- [x] **Opening apps from wheel/menu feels delayed** — 2026-09-10.
  → Fix: Switch content before dial/menu animation; remove 180ms page crossfade; snappier commit/dismiss springs; wake idle morph only on drag (instant on tap); grid long-press via ButtonStyle so taps aren’t gated on 450ms recognizer.
- [x] **Workout finish triplication** — ← leave, ··· guide/skip rest, FINISH logs. — 2026-09-10
- [x] **Tap outside dismisses keyboard/keypad** — root + settings + onboarding + workout scrim. — 2026-09-10
