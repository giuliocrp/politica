# Phase 25 — Plurinominale Geography, Both Chambers [GO-PLURI]

> Read `docs/plan/00-baseline-and-rules.md` first. **Depends on:** 23
> (layer schema dumps). **Network:** none — both plurinominale shapefile
> layers are already local under `tools/raw/collegi/`.
> **Report:** `docs/v4/25-plurinominale-geography.md`.
> **Commit:** `feat(v4): phase 25 — plurinominale collegi geography + deputy linkage (gated)`

## Objectives & deliverables

Give the 245 plurinominale deputies real geography:

- Import `CAMERA_CollegiPLURINOMINALI_2020` (and, under the same gate
  evidence, `SENATO_CollegiPLURINOMINALI_2020`) as new boundary
  artifacts (e.g. `districts_plurinominali_camera.geojson` +
  `districts_plurinominali_senato.geojson`).
- Link each plurinominale deputy to their plurinominale collegio via the
  Phase-18 coverage suffix (`"{CIRC} - P0N"`; 49 distinct codes over
  397/400 deputies) — shipping the `collegioPlurinominale` field Phase 18
  deferred (its blocker — no UI consumer, not uniformly derivable — is
  resolved by this phase's UI and the disclosed 3-record absence).
- UI: a collegio-type selector on the map (uninominale/plurinominale per
  chamber, mutually exclusive overlay sets); plurinominale-collegio
  detail pages listing their deputies; `CollegiListView` gains a type
  filter (the accessible alternative, as ever).

## Technical requirements

- Extend `build_boundaries.sh` / `import_boundaries.py` with two new
  layer configs reusing the existing simplify/vertex-gate machinery;
  tolerance re-measured for the new layers (per the Phase 14 note).
- Id policy: unconditional prefixes for the new files (exact prefix
  decided in-phase), collision-checked against all existing ids;
  validator enforces global uniqueness across all boundary files.
- `collegioType: "plurinominale"` — finally exercising the existing enum
  case end-to-end; `DistrictService` bucketing driven by each feature's
  own chamber+type properties (never by source file).
- Linkage in `import_representatives.py` keyed on
  `(normalize(circoscrizione), P-code)` against the shipped file;
  loud-fail outside the Phase-18-documented bare cases.
- `validate_data.py`: expected counts from gate evidence; per-file 3 MB
  gate; cross-file uniqueness; cross-check that each linked deputy's
  `circoscrizione` equals their P-collegio's.

## Known risks & edge cases — the GO-PLURI gate (all conditions required)

(a) Layer schema fields identified from Phase 23's dumps — no name-based
guessing.
(b) **Q1 fully explained from feature attributes**: 50-vs-49 (Camera) and
27-vs-26 (Senato) — expected placeholder rows (Valle d'Aosta /
Trentino-Alto Adige hypothesis); whatever is found is documented; an
unexplained extra feature is **NO-GO**.
(c) Every one of the 49 deputy P-codes matches exactly one Camera
feature under the established normalization + existing aliases — no new
ad-hoc aliases.
(d) Byte/vertex maxima **measured before** committing to ship both
chambers: plurinominale polygons are unions of uninominale ones and may
be large. If a file breaches 3 MB at current tolerance: either a coarser
tolerance for the new layers only (existing uninominale files must stay
**byte-identical**) or the Senato file is descoped — both outcomes
documented, neither silent.
(e) Estero deputies and the 3 bare-coverage records carry no
`collegioPlurinominale` (chamber/field-conditional-key convention);
senators carry none.

Additional risk: map rendering three overlay sets — the type selector is
exclusive by design; VoiceOver path is the CollegiList type filter.

## Validation strategy

Committed offline probe **before** any importer change: parse both
layers, enumerate codes, run the full match against
`representatives.json`, print the would-be linkage table plus byte and
vertex measurements. Generated-data protocol on every artifact; all
existing boundary files byte-identical.

## Test specifications (strict acceptance criteria)

1. Probe output quoted in the report with gate conditions (a)–(e)
   individually evidenced; GO or NO-GO stated (NO-GO path: report +
   probe only, zero other diff).
2. Validator green with new expected counts taken from the gate evidence
   (not from this plan).
3. Shipping-data tests: every `electionType == .plurinominale` deputy
   carries a `collegioPlurinominale` resolving to a shipped
   plurinominale district **and** consistent with their
   `circoscrizione`; estero + the 3 bare records and all senators carry
   none; global district-id uniqueness across all boundary files.
4. `DistrictService` tests: type-filtered lookups (sample fixture
   extended only per the `*.sample.*` naming convention);
   point-in-polygon returns both a uninominale and its containing
   plurinominale for one probe-verified coordinate (expected ids
   verified by standalone script before hardcoding).
5. UI strings pinned in the report, all Italian.
6. Suite green; additions counted against the Phase-24 baseline.

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
