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

### Batch CB — Audit round 75 (next)

- [ ] **Global search empty hint a11y** — Empty-state scope line gets explicit accessibility label.
- [ ] **Drawer settings row label** — Settings footer gets explicit accessibility label (not just hint).
- [ ] **Calendar today a11y** — Month cell label still mentions today when badge is centered.
- [ ] **Shop manual refresh clears flag** — Rebuild shop list resets populate attempt for forced refresh.
- [ ] **PlannerScreenHeader doc** — Trailing-toolbar pattern comment on struct itself.

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

---

## Loop signal

| Field | Value |
|-------|-------|
| **Phase** | `RUNNING` |
| **Next batch** | **CB** |
| **Summary** | Batch CA done (footer targets, today circle, search copy, shop retry). Loop RUNNING. |
