# Phase 28 — Group-Membership History, Camera [GO-STORICO, USER-GATED network]

> Read `docs/plan/00-baseline-and-rules.md` first. **Depends on:** 23.
> **Network: USER-GATED** — exploration probe + minimal-scope fetch, both
> approved explicitly, quoted verbatim.
> **Report:** `docs/v4/28-membership-history.md`.
> **Commit:** `feat(v4): phase 28 — Camera group-membership history import (gated)`

## Objectives & deliverables

Methodology gate line 6: import per-deputy parliamentary-group
membership **intervals** so group-at-vote-date is computable.
Exploration first: the v2 Camera query's
`MINUS { ?aderisce ocd:endDate ?end }` proves end dates exist in the
graph; start dates and group-entity shapes are **verified by probe, not
assumed** (Q4). Under GO: a new generated artifact
(`memberships_camera.json`: deputy id, group name/sigla, start,
end|null), scoped to XIX and to deputies present in
`representatives.json`; a pure `membershipAt(representativeId:date:)`
lookup. **No UI in this phase** — infrastructure for Phase 29 and honest
data in its own right. Senato: out of scope (votes are Camera-only).

## Technical requirements

- New pinned `.rq` under `tools/queries/`; fetch under the refetch
  protocol, minimal-scope (this query only).
- Interval validation (importer + validator): per-deputy intervals
  non-overlapping; dates parseable; every serving deputy has exactly one
  open (end==null) interval; the open interval's group is consistent
  with the record's `parliamentaryGroup` under a documented
  normalization (the v2-disclosed truncation-at-parenthesis quirk means
  prefix-comparison, spelled out in the report) — mismatches fail
  loudly.
- A byte gate for the new artifact proposed from measurement at import
  time (expected small: ~400 deputies × 1–3 intervals).

## Known risks & edge cases — the GO-STORICO gate

NO-GO conditions (any one suffices): missing start dates; ambiguous
overlapping intervals that can't be resolved by a documented,
source-backed rule; group entities that can't be reconciled to the
shipped group names. Gruppo Misto sub-components may appear as separate
memberships — the probe enumerates the actual vocabulary and every
mapping decision is disclosed. NO-GO → report only; the metric stays
structurally blocked and Phase 29 records NOT-RUN.

## Validation strategy

Probe with quoted samples from both sides (graph values ↔ shipped group
names) before any importer code; generated-data protocol; referential
integrity (every membership's deputy exists in `representatives.json`).

## Test specifications (strict acceptance criteria)

1. GO/NO-GO evidence per condition, quoted, both outcomes supported.
2. Under GO: validator invariants above all green.
3. `membershipAt` pure-function tests: mid-interval; boundary dates
   (the inclusive/exclusive rule pinned in the report and tested on
   both edges); date before first interval → nil; open-ended current
   interval; a group-switcher fixture with two intervals.
4. Shipping test: for every deputy appearing in `votes.json`,
   `membershipAt(today)` equals their record's group under the
   documented normalization.
5. Suite green vs the current baseline plus documented additions.

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
