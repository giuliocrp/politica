# Phase 26 — Senato Regione Context + Senator `electionType` Decision [GO-REG]

> Read `docs/plan/00-baseline-and-rules.md` first. **Depends on:** 23.
> **Network:** none — runs from the existing Phase-17 cache
> (`regioneElezione` verified present for all 196 elective serving
> senators). **Report:** `docs/v4/26-senato-regione.md`.
> **Commit:** `feat(v4): phase 26 — Senato regione context (+ electionType decision) (gated)`

## Objectives & deliverables

The Phase-18 analog for the Senato:

- Every elective senator gains `regione` — derived from
  `osr:regioneElezione`, canonicalized against
  `districts_senato.geojson`'s 20 shipped regione values (same
  canonical-casing pattern as Phase 18's circoscrizione).
- Senato collegio pages gain "Senatori proporzionali della regione
  {name}" with an explanatory caption; senator profiles gain
  "Regione: {name}".
- **The deferred senator-`electionType` decision is taken here** (its
  owning phase). Recommendation, flagged to the user before
  implementation with keep-null as the alternative: map
  `"Eletto uninominale…"` → `.uninominale`,
  `"Eletto proporzionale…"` → `.plurinominale` (a disclosed
  cross-chamber best fit — the `"Non ha votato"` → `.assente` precedent
  class), `"circoscrizioni estere"` → `.estero`; a-vita unchanged
  (absent → `.sconosciuto` at decode).

## Technical requirements

- `Representative.regione: String?` — Senato-only key, exact mirror of
  the Camera-only `circoscrizione`; validator enforces both directions.
- The 2 estero senators' `regioneElezione` values are estero
  constituency names: they map to a pinned `"Estero"` value or stay
  key-absent (in-phase decision, documented) — they must never match a
  geographic regione.
- Grouping as a static pure function (the Phase 18/`RepresentativeService`
  pattern): proporzionale senators of one regione, name-sorted.

## Known risks & edge cases — the GO-REG gate (all conditions required)

(a) 196/196 elective coverage re-verified at import time (a-vita:
key omitted).
(b) Every domestic `regioneElezione` value matches exactly one of the 20
shipped regione values under the strict-uppercase + Valle d'Aosta-alias
rule; any new variant fails loudly (alias table extends only with
per-entry verified evidence — bilingual names are the likely candidates).
(c) For all 73 linked senators, derived regione == their collegio's
shipped `regione` property (import-time cross-check + validator, exact
string equality on canonical values).

If the `electionType` mapping is approved:
`SchemaV2Tests.testSenatoLinkageMatchesPhase17Import`'s
"electionType stays `.sconosciuto`" assertion becomes a **deliberate,
documented update** — listed per-test in the report, never silently
flipped.

## Validation strategy

Committed offline probe evaluating (a)–(c) with quoted values before any
importer change. Generated-data protocol: expected diff is `regione`
additions on ≤196 senator records, plus `electionType` changes only if
the user approved the mapping (approval quoted verbatim in the report).

## Test specifications (strict acceptance criteria)

1. Probe evidence per gate condition, both outcomes supported.
2. Shipping tests: all elective senators carry a non-nil canonical
   `regione` within the shipped set (∪ the estero decision's value);
   a-vita senators nil; all deputies nil; linked-senator equality per
   (c).
3. Pure grouping tests on hand-built fixtures: proporzionale-only;
   excludes uninominale senators of the same regione, a-vita, estero;
   name-sorted; unknown regione → empty.
4. If the mapping shipped: distribution test (73 uninominale / 121
   plurinominale / 2 estero) + the user approval quoted; if keep-null:
   grep-verified zero senators with non-null `electionType`, as today.
5. UI strings pinned, Italian; suite green against the current baseline.

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
