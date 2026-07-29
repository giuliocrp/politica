# Phase 29 — Alignment Metric [STRICTLY CONDITIONAL]

> Read `docs/plan/00-baseline-and-rules.md` first. **Depends on:** 27
> **and** 28. **Network:** none.
> **Report:** `docs/v4/29-alignment-metric.md`.
> **Commit:** `feat(v4): phase 29 — group-alignment metric under the methodology gate`
> (or, on the NOT-RUN path: `docs(v4): phase 29 — metric gate re-evaluated: NOT RUN`)

## Objectives & deliverables

Runs **only if the re-measured `docs/v3/votes-methodology.md` table
shows all six lines green** after Phases 27–28. Otherwise this phase's
entire output is a report stating which lines remain red — a planned,
first-class outcome, not a failure.

Under full-green: per-deputy **"Allineamento nel campione di votazioni
importate"** (the pinned label, verbatim, its only permitted name): the
share of the deputy's *expressed* positions
(favorevole/contrario/astenuto only) matching the majority expressed
position of their group-at-vote-date, over the shipped sample.
Profile-only UI with the sample-scope caption and the denominator count
visible. **Never** on lists, never ranked, never colored as judgment.

## Technical requirements

- A pure function over `(positions, events, memberships)` — no service
  state, fully unit-testable.
- Denominators per the standing rules: absences excluded; astenuto its
  own category; secret ballots already excluded at source.
- Pinned edge rules requiring **explicit user sign-off before
  implementation (Q7)**, recorded verbatim in the report:
  - group-majority tie → that vote is excluded from that member's
    denominator;
  - minimum denominator threshold below which no metric renders
    (proposed ≥10 — the number is the user's call);
  - Gruppo Misto handling exactly per Phase 28's documented mapping.
- The label string exists in app code exactly once, as a pinned
  constant.

## Known risks & edge cases

- Small-group distortion (a 2-member group is trivially "aligned") —
  addressed in the caption wording decision, disclosed not hidden.
- Group-switchers are evaluated against the group they belonged to at
  each vote's date — the entire point of Phase 28.
- Below-threshold deputies show an honest absence (no line), never
  "0%".
- Senators: no metric, ever, in this phase (votes are Camera-only).

## Validation strategy

A hand-computed fixture matrix, written into the report **before**
implementation (the verify-expectations-independently rule), covering
every rule; grep proves the label appears exactly once; the methodology
doc's status table updated to "metric shipped under gate" with the six
green lines quoted — or left untouched on the NOT-RUN path.

## Test specifications (strict acceptance criteria)

1. Six-line gate re-verified and quoted. If any line is red: the
   NOT-RUN report is committed and criteria 2–5 are n/a.
2. Pure-function tests against the pre-recorded hand-computed values:
   unanimous group; split group; tie-exclusion; absence-exclusion;
   astenuto-as-own-category; threshold boundary (denominator 9 vs 10, or
   the user-approved threshold ±1); a group-switcher whose alignment
   differs by interval.
3. UI: metric absent for senators and below-threshold deputies; caption
   pinned; Italian throughout.
4. Grep: the pinned label appears exactly once in `Politici/` (the
   constant) and nowhere else.
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
