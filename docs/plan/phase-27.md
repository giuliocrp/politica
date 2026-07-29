# Phase 27 — Stratified Votes Expansion + Lazy Loading [USER-GATED network]

> Read `docs/plan/00-baseline-and-rules.md` first. **Depends on:** 23
> (24's UI-test infrastructure is useful for the loading-state test but
> not blocking). **Network: USER-GATED** — the metadata probe and the
> real fetch both require explicit in-session approval, quoted verbatim.
> **Report:** `docs/v4/27-votes-stratified.md`.
> **Commit:** `feat(v4): phase 27 — stratified curated votes expansion + lazy vote loading`

## Objectives & deliverables

Execute the redesign Phase 21 recorded as the only viable path: replace
"N most recent" with **stratified selection** targeting the methodology
sample shape — ≥30 events across ≥10 sittings spanning ≥6 months, with
atto-bearing final votes preferred — expand `votes.json` under all
existing gates, and ship the lazy-loading work Phase 21 deferred (its
trigger, file growth, now fires). Re-measure the
`docs/v3/votes-methodology.md` gate table **in the same commit** (its own
re-evaluation protocol).

## Technical requirements

Selection architecture (minimal blast radius):
- A network **metadata-only** probe fetches a deep window (votazione URI
  + date + segreta + OPTIONAL attoLabel; Phase 21 proved a 300-event
  metadata window works; the depth needed for ≥6 months is measured;
  chunking/OFFSET behavior observed → Q3).
- A committed **offline selector** (`tools/select_votes_scope.py`)
  applies pinned, documented stratification rules to the probe output
  and writes the chosen URI list into `votes_scope.json`'s **existing
  `"explicit"` mode** — `fetch_camera_votes.py` needs no scope-logic
  change and the selection is reproducible from committed inputs.
- Detail fetch: the existing chunked-VALUES path (10 URIs/request).
- All limits (`maxVotes`, `maxPositionRecords`, byte projections) set
  from measured numbers + stated headroom; whole-event stopping stays.

Lazy loading:
- `VoteService` → `@Observable`; `loadIfNeeded() async` with
  idle→loading→loaded/failed state; decode in `Task.detached` carrying a
  DEBUG `!Thread.isMainThread` assertion; state applied on the
  MainActor.
- `ProgressView` loading states in Votazioni, VoteHistory, and the
  profile's recent-votes section; all `VoteService`-consuming tests
  updated to `await loadIfNeeded()` (deliberate, listed).
- Cold-decode duration recorded before (711,439 B file) and after (the
  expanded file) in the report.

## Known risks & edge cases

- The source may fail a diversity line even stratified (e.g. atto-bearing
  events scarce among non-secret electronic votes): **partial results
  ship honestly** — the gate table shows exactly which lines flipped;
  red lines stay red in writing (Phase 29 then cannot run).
- Older sittings → departed deputies → dropped positions: the selector
  counts drops per candidate sitting; any preference rule about drop
  rates is pinned and documented, never silent cherry-picking.
- Byte gates: 30 events measured ~1.78 MB at ~399 positions/event;
  atto-bearing titles are longer — the dry run measures the actual
  selection; if it crowds a gate (<5% headroom) the selector trims whole
  sittings per its pinned priority order.
- 12→N breaks the two pinned event-count test constants
  (`VoteBrowsingTests`) — deliberate documented updates.
- Full refetch protocol applies: XIX currency re-verified first,
  approval quoted, before/after counts diffed, manifest +
  `docs/DATA_SOURCES.md` + `tools/SOURCES.md` re-synced.

## Validation strategy

Generated-data protocol with a content-reconciliation script (every
position in the new file traceable to the raw cache); Phase 20
invariants re-validated over the expanded set; DEBUG-assertion (or
Instruments) evidence that the main thread never decodes; the
methodology table re-measured with per-line before/after.

## Test specifications (strict acceptance criteria)

1. Probe table + pinned selector rules committed; every config limit
   traces to a measurement plus stated headroom.
2. Validator green with deliberately updated constants; both byte gates
   satisfied with recorded headroom.
3. Invariant tests over the expanded data: per-event tally sums ==
   position counts; distinct `voteEventId` set == event-id set; the
   Votazioni scope line shows the new data-driven N.
4. Lazy tests: `loadIfNeeded` idempotent under concurrent callers;
   sample-fixture fallback still yields zero events; decode-off-main
   DEBUG assertion in place; a loading state exercised (unit-level state
   test, plus a Phase-24 UI test if that phase has landed).
5. Methodology gate table re-measured in the same commit, per-line
   before/after quoted.
6. No metric string in app code (grep); suite green vs the current
   baseline plus documented deliberate changes.

**Standing constraints (non-negotiable):**
- Never rename the Xcode project ("Politici"), target, scheme, or bundle identifier.
- All user-facing strings must be in Italian.
- The app runtime is strictly local-first: no network calls from the app.
- Developer tools may query official public endpoints only, and only inside tools/.
- Never fabricate political data, geography, or licensing information.
- If data is missing or ambiguous, stop and document it.

**Verification command trio:**
```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Politici.xcodeproj -scheme Politici -destination 'generic/platform=iOS Simulator' build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl list devices available | grep iPhone
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Politici.xcodeproj -scheme Politici -destination 'platform=iOS Simulator,name=<SimName>' test
```
