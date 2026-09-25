# Lunch Lady

Rock Hills Ranch feed wagon app. One self-contained `index.html` — no build step, no dependencies, no server, no accounts. Each phone keeps its own data in localStorage and works with zero signal.

## What it does

- **Rations** as recipes: each ingredient a % of the mix (as-fed), plus one reference total (lb as-fed/hd/day). Ingredients carry a DM%.
- **Pens** (mixer workflow): head count, anchor weight + ADG projection, intake targeting by %BW, flat lb DM/hd/day, or "ration as entered."
- **Loads**: cumulative scale targets per ingredient that rebase off actual readings — overshoot one ingredient and every target after it corrects. Combined loads split across pens proportionally. Each load has its own optional comment box.
- **Field Deliveries** (no-mixer workflow): bale grazing, unmetered feeders. Lightweight **Groups** (name, head count, flat as-fed lb/hd/day target — no ADG). Each delivery covers an explicit number of days and takes per-ingredient lines as either count × unit weight (3 bales × 1250 lb) or a direct lb estimate. Variance judged against head × rate × days.
- **Daily report**: per-day text (email) and CSV (Save-to-Drive share sheet), manual and deliberate, with per-device attribution via the Settings name. Includes a day-level comment box, per-load comments, per-load totals with lb/hd, and a day roll-up of total lb delivered per ingredient. Past days missing a report get a banner.
- **History + CSV exports** for ingredient detail and per-pen summaries.

## Default ingredients

A fresh install (or Settings → Clear All Data) seeds:

| Ingredient | Starting DM% |
|---|---|
| Ground Hay | 88 |
| Silage | 35 |
| DDGS | 90 |
| Oats | 89 |
| Corn | 87 |
| Flax screenings | 90 |
| R1800 | 90 — **placeholder, not the product's real DM%** |

All are generic textbook values from `DM_GUESS_TABLE`, not lab results. Correct them in Settings with feed tests or known moisture — silage especially. The seeded example ration (Silage / DDGS / Ground Hay / R1800) is a placeholder too; edit or delete it.

Defaults only apply when no data exists under the storage key. Changing `defaultState()` does nothing to a phone that already has data.

## Daily report format

### Drive CSV

One row per ingredient per load, then a summary row under each load, then a blank row before the next load. Field deliveries follow the same pattern.

| Col | Header | Notes |
|---|---|---|
| A | Date | |
| B | Logged By | Name from Settings |
| C | Load # | `1`, `2`… for mixer loads; `FD1`, `FD2`… for field deliveries |
| D | Pens | Group name for field deliveries |
| E | Total Head | |
| F | Ration | Coverage window for field deliveries |
| G | Ingredient | `(load total)` / `(delivery total)` on summary rows |
| H | Target lb | |
| I | Actual lb | Blank on ingredient rows with no reading |
| J | Variance lb | |
| K | Variance % | |
| L | Skipped | |
| M | Lb per Head | Summary rows only. Load: delivered ÷ total head. Field delivery: delivered ÷ head for the whole delivery, **not** per day |
| N | Load Comment | Repeats on every row of its load so filtering/sorting never loses it |

After the load/delivery rows: an **Ingredient Totals** block (mixer target, mixer actual, field delivered, total delivered, count of weigh-ups counted at target), then the day's **Comments**.

### Email text

Same data as plain text via `mailto:`. Order: header → ingredient totals → each load (ingredient lines, load total with lb/hd, load comment) → field deliveries → mixer/field day totals → day comments.

**Known limitation:** the body is truncated at 1,800 characters (`MAX` in `emailReport()`), because `mailto:` length is unreliable across mail apps. A normal day of three loads plus a field delivery runs ~2,100+ characters, so the tail — field deliveries, day totals, day comments — gets cut. Ingredient totals are placed first so they survive. The Drive CSV is always complete. `mailto:` is plain text only; tables/formatting aren't possible through it.

### Missing scale readings

In every report total (ingredient totals, load totals, mixer day total), a weigh-up with **no reading entered** counts at its **target** — unless "not fed today" is checked, in which case it counts zero in both target and actual. Totals that include a target stand-in are labeled (`counted at target`). Individual ingredient rows keep a blank actual, so column I won't always sum to the load total row; the label explains the gap.

Because readings are cumulative, a missed mid-load reading pushes its real deviation onto the next ingredient that *was* read. A large variance right after a missing reading is usually an artifact; the load total is still correct. The Today screen's day total still uses weighed pounds only, so it can read lower than the report on a day with a missed reading.

## Install on a phone

Copy `index.html` to the phone (Drive, USB, whatever), open it in Chrome (Android) or Safari (iPhone), then "Add to Home Screen." It launches fullscreen like an app. Data stays on that phone — export a JSON backup from Settings occasionally, and always before switching phones.

After renaming or updating the app, a home-screen shortcut keeps its old label until it's deleted and re-added.

## Storage key

`STORAGE_KEY = 'lunchlady_v1'`. Earlier builds (as "Rock Hills Feed Wagon") used `rhr_feedwagon_v1`. There is **no** automatic copy from the old key — any data entered under it won't appear in this build. Restore it via a JSON backup exported from the old build if needed. Don't change the key again without adding a one-time migration.

## Ranch Savvy sync (optional, read-only)

Pens and Groups can link their head count to a Ranch Savvy herd. Counts pull on app open / return-to-foreground (when >6 h stale) / manual Refresh, and are cached — Ranch Savvy being unreachable costs nothing but a stale count. Nothing is ever written back.

Setup, once:

1. Run `ranch-savvy-sync.sql` in the Ranch Savvy Supabase SQL editor, after replacing the placeholder key with a long random string.
2. Near the top of `index.html`, set `RS_ANON_KEY` (the Supabase anon key) and `RS_APP_KEY` (the same string from step 1). `RS_URL` is already set.
3. Redistribute the updated `index.html` to the phones.

Leave the two keys empty and the feature is invisible; the app runs fully standalone.

The request header is still named `x-feedwagon-key`. It must match what `get_herd_summary()` checks for server-side — rename both together or neither.

**Security posture, stated plainly:** this repo is public, so the app key in the source is a bot filter and a kill switch, not a secret. What it exposes if leaked: active herd names and head counts. Everything else in Ranch Savvy stays behind RLS. Rotate the key in the SQL function to cut access instantly.

## Design decisions worth knowing before editing

- **Local-only on purpose.** A Supabase sync layer for feed data was built and deliberately reverted; the daily manual report satisfies the "lose at most one day" risk tolerance. Don't reintroduce a live backend dependency casually.
- **Migration discipline:** `migrateState()` captures `fromVersion` before any step mutates it — version guards must always compare against the original. Purely additive fields (like `load.comments`) use plain defaults, no version bump. (A re-run bug here once corrupted ration recipes on every launch; don't recreate it.)
- **Never re-render over an open editor.** Load entry patches DOM nodes in place (`patchLoadEntryUI`); full innerHTML replacement mid-tap eats the tap. Load comments save on every keystroke for the same reason — tapping Done before blur must not lose text. The background sync respects the same rule via `anyEditorOpen()`.
- **Dates are local**, built by hand (`todayStr()`), never `toISOString()` — evening entries must not land on tomorrow's UTC date. Day rollover on suspended Android apps is handled in the `visibilitychange` listener.
- **Snapshots at record time.** Loads freeze pen/ration/ingredient names when marked done; field deliveries freeze group name/count/rate and ingredient names at save. Deleting roster items never breaks history.
- **Field deliveries stay separate from mixer day totals** in reports — a 4-day bale drop lumped into one day's mixer total would misstate both. In the ingredient roll-up, field-delivery lb count in full on the day dropped.
- **CSV columns only get appended, never inserted.** Daily CSVs accumulate in Drive; shifting existing columns breaks anything that stacks them. New columns go at the end.
- **"Repeat from yesterday" doesn't copy comments or call adjustments** — both describe that day's conditions.
- **One place for report totals.** `loadDeliveredSummary()` and `dayIngredientTotals()` own the target-fill rule; the text report, CSV, and day totals all call them. Don't recompute totals inline.

## Dev notes

Syntax check: extract the `<script>` body and run `node --check`. The report builders (`buildDailyReportText`, `buildDailyReportCsv`) can be exercised headlessly under jsdom by loading `index.html` with `runScripts: 'dangerously'`, pushing loads into `getOrCreateFeedCall(date)`, and calling the builders directly — that's how the sample reports in the Drive folder were generated.
