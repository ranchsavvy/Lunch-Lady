# Lunch Lady

Rock Hills Ranch feed wagon app. One self-contained `index.html` — no build step, no dependencies, no server, no accounts. Each phone keeps its own data in localStorage and works with zero signal.

## What it does

- **Rations** as recipes: each ingredient a % of the mix (as-fed), plus one reference total (lb as-fed/hd/day). Ingredients carry a DM%.
- **Pens** (mixer workflow): head count, anchor weight + ADG projection, intake targeting by %BW, flat lb DM/hd/day, or "ration as entered."
- **Loads**: cumulative scale targets per ingredient that rebase off actual readings — overshoot one ingredient and every target after it corrects. Combined loads split across pens proportionally.
- **Field Deliveries** (no-mixer workflow): bale grazing, unmetered feeders. Lightweight **Groups** (name, head count, flat as-fed lb/hd/day target — no ADG). Each delivery covers an explicit number of days and takes per-ingredient lines as either count × unit weight (3 bales × 1250 lb) or a direct lb estimate. Variance judged against head × rate × days.
- **Daily report**: per-day text (email) and CSV (Save-to-Drive share sheet), manual and deliberate, with per-device attribution via the Settings name. Past days missing a report get a banner.
- **History + CSV exports** for ingredient detail and per-pen summaries.

## Install on a phone

Copy `index.html` to the phone (Drive, USB, whatever), open it in Chrome (Android) or Safari (iPhone), then "Add to Home Screen." It launches fullscreen like an app. Data stays on that phone — export a JSON backup from Settings occasionally, and always before switching phones.

## Ranch Savvy sync (optional, read-only)

Pens and Groups can link their head count to a Ranch Savvy herd. Counts pull on app open / return-to-foreground (when >6 h stale) / manual Refresh, and are cached — Ranch Savvy being unreachable costs nothing but a stale count. Nothing is ever written back.

Setup, once:

1. Run `ranch-savvy-sync.sql` in the Ranch Savvy Supabase SQL editor, after replacing the placeholder key with a long random string.
2. Near the top of `index.html`, set `RS_ANON_KEY` (the Supabase anon key) and `RS_APP_KEY` (the same string from step 1). `RS_URL` is already set.
3. Redistribute the updated `index.html` to the phones.

Leave the two keys empty and the feature is invisible; the app runs fully standalone.

**Security posture, stated plainly:** this repo is public, so the app key in the source is a bot filter and a kill switch, not a secret. What it exposes if leaked: active herd names and head counts. Everything else in Ranch Savvy stays behind RLS. Rotate the key in the SQL function to cut access instantly.

## Design decisions worth knowing before editing

- **Local-only on purpose.** A Supabase sync layer for feed data was built and deliberately reverted; the daily manual report satisfies the "lose at most one day" risk tolerance. Don't reintroduce a live backend dependency casually.
- **Migration discipline:** `migrateState()` captures `fromVersion` before any step mutates it — version guards must always compare against the original. Purely additive fields use plain defaults, no version bump. (A re-run bug here once corrupted ration recipes on every launch; don't recreate it.)
- **Never re-render over an open editor.** Load entry patches DOM nodes in place (`patchLoadEntryUI`); full innerHTML replacement mid-tap eats the tap. The background sync respects the same rule via `anyEditorOpen()`.
- **Dates are local**, built by hand (`todayStr()`), never `toISOString()` — evening entries must not land on tomorrow's UTC date. Day rollover on suspended Android apps is handled in the `visibilitychange` listener.
- **Snapshots at record time.** Loads freeze pen/ration/ingredient names when marked done; field deliveries freeze group name/count/rate and ingredient names at save. Deleting roster items never breaks history.
- **Field deliveries stay separate from mixer day totals** in reports — a 4-day bale drop lumped into one day's mixer total would misstate both.

## Dev notes

Syntax check: extract the `<script>` body and run `node --check`. A headless test harness (DOM stubs + ~50 assertions over migration, load math, FD math, sync, and report content) lives in the development session history; regenerate as needed.
