# V3 Phase 16 — Senato Uninominale Boundaries + Chamber-Aware Map

Ships the Senato uninominale boundary layer (74 collegi, GO(MAP) from
Phase 15) and makes the map, collegi list, and address search
chamber-aware. Senato-to-senator linkage remains NO-GO (Phase 15) and is
untouched by this phase — Senato districts ship with zero representatives
linked, by design, not by omission.

## Pipeline

### 1. `tools/build_boundaries.sh` / `tools/import_boundaries.py` parameterized

Both scripts now accept a chamber argument (`build_boundaries.sh
[camera|senato]`, `import_boundaries.py --chamber {camera,senato}`),
sharing one `CHAMBER_CONFIGS`-driven code path instead of a duplicated
script. New Makefile target `boundaries-senato`, added to `all` alongside
the existing `boundaries`.

`make -n all`:
```
python3 tools/import_representatives.py
python3 tools/import_votes.py
./tools/build_boundaries.sh camera
./tools/build_boundaries.sh senato
python3 tools/make_manifest.py
python3 tools/validate_data.py
```

**Real run output** (`make boundaries-senato`):
```
Report vertici per collegio (74 feature, soglia 1500):
  ...
  S200002	800	Sardegna - U02
  ...
Massimo: S200002 (Sardegna - U02) — 800 vertici
OK: 74 collegi scritti in Politici/Data/districts_senato.geojson (847 KB)
```

800 max vertices (< 1500 gate), 847 KB (< 3 MB gate) — both pass with
wide margin, matching Phase 15's projected estimate (800 vertices exactly;
~833 KB projected vs. 847 KB actual, within 2% of the schema-v2-inflation
extrapolation). Verified `S200001`/`S200002` (Sardegna) are `MultiPolygon`
in the final output:
```python
S200001 Sardegna - U01 MultiPolygon {..., 'regione': 'Sardegna', ...}
S200002 Sardegna - U02 MultiPolygon {..., 'regione': 'Sardegna', ...}
```

### 2. Id prefix / schema — a real byte-identity bug caught and fixed mid-phase

First attempt added both `circoscrizione` and `regione` keys to every
feature (the unused one set to `null`). This **broke** Camera's
byte-identity requirement: `Politici/Data/districts.geojson` gained a
`"regione": null` key on all 147 features, shifting the whole
`sort_keys=True` JSON output (147-line diff). **Root cause**: the
schema-v2 writer sorts and serializes every key present, so adding any
key — even null — to a Camera feature changes the file. **Fix**: the
grouping property is now added conditionally — only the key the chamber
actually uses (`circoscrizione` for Camera, `regione` for Senato) is
present at all; the other is *absent*, not null. Swift's `Decodable`
treats a missing key the same as an explicit null for an `Optional`
property, so this is transparent on the decode side. Re-ran `make
boundaries` (Camera): `git diff --stat -- Politici/Data/districts.geojson`
→ empty, confirmed byte-identical.

`id` = `"S"` + `SU20_COD`, applied **unconditionally** (not just to the 32
colliding ids Phase 15 found) — e.g. `S10001`, `S200002`. Verified:

```python
camera count: 147
senato count: 74
all senato ids S-prefixed: True
intersection (should be empty): set()
combined unique: 221
```

Zero collisions, 221 unique combined ids.

### 3. `tools/validate_data.py`

`validate_districts()` refactored to a shared `validate_districts_file(path,
expected_chamber, expected_count, grouping_property, missing_hint)` helper,
called once per boundary file, plus a new cross-file id-uniqueness check.
`EXPECTED_SENATO_DISTRICT_COUNT = 74` added.
`REQUIRED_DISTRICT_PROPERTY_KEYS` no longer unconditionally requires
`circoscrizione` (would otherwise fail every Senato feature) — the
grouping-property check is now chamber-conditional, mirroring the schema
change above.

Real output:
```
OK: 147 collegi validi in Politici/Data/districts.geojson (1131 KB)
  Camera: 147  MultiPolygon (isole/parti multiple): 56
OK: 74 collegi validi in Politici/Data/districts_senato.geojson (847 KB)
  Senato: 74  MultiPolygon (isole/parti multiple): 34
OK: id univoci tra le due camere — 221 collegi totali (Camera 147 + Senato 74)
```

### 4. Manifest / `docs/DATA_SOURCES.md`

New manifest source `istat-collegi-elettorali-senato-uninominali` — same
URL/license as the Camera ISTAT entry (same D.Lgs. 177/2020 release), same
`retrievedAt`. Both entries read the **same** `"istat"` fetch-metadata key
(not a new `"istat_senato"` key) — deliberately, because a distinct key
would have been stamped with *today's* date on this phase's first run
(via the existing `stamp_fetch_metadata_if_absent` guard from Phase 14),
which would be wrong: the real retrieval was a single 2026-07-18 batch
covering both layers (`tools/SOURCES.md`), not two separate events. Real
`make manifest` output:
```
- istat-collegi-elettorali-camera-uninominali (CC BY 4.0, retrievedAt=2026-07-18)
- istat-collegi-elettorali-senato-uninominali (CC BY 4.0, retrievedAt=2026-07-18)
```

The Camera ISTAT manifest note's now-false "I confini del Senato non sono
ancora inclusi in questo prototipo" clause was removed (a Senato ISTAT
source now exists). `docs/DATA_SOURCES.md` synced surgically: new Senato
ISTAT section mirroring Camera's, the Camera section's closing sentence
updated to point at it instead of asserting Senato boundaries don't
exist, refresh-procedure and cross-check sections updated to mention
`make boundaries-senato`/the new source/6-entry count.

### 5. Offline `make all` — diff scope

```
$ make all   # (import already run in Phase 14/15 sessions; full chain re-verified here)
...
OK: id univoci tra le due camere — 221 collegi totali (Camera 147 + Senato 74)
...
$ git status --short -- Politici/Data/
 M Politici/Data/sources.json
?? Politici/Data/districts_senato.geojson
$ git diff --stat -- Politici/Data/sources.json
 Politici/Data/sources.json | 12 ++++++++++--
```

Exactly the two expected diffs from step 5's brief: the new
`districts_senato.geojson`, and the manifest change (new Senato source +
the corrected Camera note text, both intentional and explained above;
`generatedAt` churn is the same harmless metadata-timestamp category
established as acceptable in Phase 14). `districts.geojson`
(Camera), `representatives.json`, and `votes.json` show **zero** diff.

## Swift model / service

### `District.swift`

Added `let regione: String?` alongside the existing `circoscrizione:
String?`, each `nil` for the other chamber (see the byte-identity fix
above — this mirrors the data). Doc comments updated to explain the
20-region-vs-28-circoscrizione distinction (Phase 15 finding).

### `DistrictService.swift` — full rewrite

- `init(resources: [String] = ["districts", "districts_senato"], bundle:)`
  — loads every listed resource, buckets the combined result by each
  feature's own `chamber` property (`Dictionary(grouping:by:)`), not by
  which file it came from. This makes the mixed-chamber
  `districts.sample.geojson` fixture (3 Camera + 2 Senato in one file)
  bucket correctly through the same code path as the two real files.
- `#if DEBUG assert(loadError == nil, ...)` — an unrecognized `chamber`
  value (or any other decode failure) fails loudly in DEBUG/test builds
  instead of silently degrading to an empty district list, per the
  phase's brief; Release builds still degrade gracefully via the existing
  `loadError`/empty-array pattern.
- API: `allDistricts()` (combined, unchanged behavior — HomeView's 221
  stat, global `district(withId:)` lookups), `allDistricts(chamber:)`
  (what `MapView`/`CollegiListView`'s picker renders),
  `district(for:chamber:)` (chamber-scoped point lookup, no
  Camera-defaulting overload exists), `districts(containing:)` (at most
  one match per chamber — powers `AddressSearchView`'s dual result).

Every existing call site was refactored explicitly to pass a chamber —
no default/shim was added. Full call-site list updated: `MapView.swift`,
`CollegiListView.swift`, `AddressSearchView.swift`, `HomeView.swift`,
`DistrictDetailView.swift`, `DistrictBoundariesTests.swift`,
`ServiceLookupTests.swift`, `GeocodingProvidingTests.swift`.

## UI changes

- **`MapView`**: new `ChamberPicker` (segmented, visible labels
  "Camera"/"Senato", `accessibilityLabel` "Camera dei Deputati"/"Senato
  della Repubblica" on each segment) replaces the old static legend. Only
  the selected chamber's districts render (`allDistricts(chamber:
  selectedChamber)`); tap-to-select is chamber-scoped
  (`district(for:chamber:)`); camera fits to the selected chamber's
  bounds on first view of that chamber (`fittedChambers: Set<Chamber>`,
  refit once per chamber, not on every switch); switching chambers clears
  the selected district (the old selection may not exist in the new
  chamber's rendered set). Caption below the picker reads "Collegi
  uninominali — Camera dei Deputati" / "… — Senato della Repubblica".
  `ChamberPicker` lives in `MapView.swift` (primary consumer) and is
  reused by `CollegiListView` — the existing two-screen-shared-component
  convention (`RepresentativeRow`'s precedent).
- **`CollegiListView`**: same `ChamberPicker`; list/search/title all scope
  to the selected chamber (`"Collegi (147)"` for Camera, `"Collegi (74)"`
  for Senato). Search matches name + whichever grouping property is
  non-nil (`circoscrizione ?? regione`). `CollegioRow`'s subtitle shows
  the same non-nil grouping value.
- **`AddressSearchView`**: `resolveCoordinate` no longer auto-navigates on
  a single match — it calls `districtService.districts(containing:)` and
  shows a `resultsSection` with one `ChamberResultRow` per chamber: a
  tappable "Collegio Camera: {name}" / "Collegio Senato: {name}" row when
  that chamber has a match, or a per-chamber not-covered message when it
  doesn't (each chamber independent — a Camera hit and a Senato miss both
  show correctly on the same result). Only shows the old combined
  not-covered error when *neither* chamber matches.
- **`HomeView`**: stat card now reads the combined `allDistricts().count`
  (221) under the label "Collegi uninominali" (was "Collegi campione" —
  a leftover v1-era label that had never been updated even after v2
  shipped real ISTAT data; corrected here since it's now visibly wrong
  next to a Senato count). The "Come funziona l'elezione" bullet about
  Senato boundaries not existing was rewritten: it now says the 74 Senato
  collegi are visible on the map (chamber picker), but no senator is yet
  linked to their collegio — accurate under Phase 15's NO-GO(LINK), no
  longer claiming boundaries don't exist at all.
- **`DistrictDetailView`**: header gains a `"Regione: {name}"` line when
  `district.regione != nil` (Senato only). Representatives section
  unchanged — the existing honest empty-state text ("Nessun rappresentante
  collegato in questa versione del prototipo.") already covers Senato
  districts correctly, since no representative carries a Senato
  `districtId` (NO-GO(LINK), by design).

## Decode-time measurement and eager/lazy decision

Added `testColdDecodePerformanceCameraOnlyVsBothChambersEager`
(`DistrictBoundariesTests.swift`): 5 repetitions, minimum taken per side.

**Measured** (extracted via `xcresulttool` from the real run, iPhone 17
Pro simulator):
```
Camera only (min of 5): 0.007454037666320801s  (~7.5ms)
Camera+Senato eager (min of 5): 0.013137102127075195s  (~13.1ms)
ratio: 1.7624142397927363x
camera samples: [8.94ms, 7.45ms, 8.98ms, 8.45ms, 7.51ms]
both samples:   [13.38ms, 17.28ms, 13.17ms, 14.98ms, 13.14ms]
```

The stated decision rule ("switch to lazy if eager-both exceeds 1.5x the
Camera-only baseline **or** ~300ms") has two independent triggers. Here
they disagree: the ratio (1.76x) technically exceeds 1.5x, but the
absolute time (13ms) is nowhere near 300ms — both numbers are imperceptible,
well under a single 60fps frame (16.7ms). **This was surfaced to the user
rather than resolved unilaterally**, since it's a genuine ambiguity with
real implementation-scope consequences (lazy loading means async load
state in `DistrictService`, loading UI in `MapView`/`CollegiListView`, and
more tests). **User decision: stay eager** — the ratio is a poor proxy at
sub-15ms magnitudes, and lazy-loading's added complexity isn't justified
by a ~6ms difference. `DistrictService` keeps its simple, fully-eager
`init`; no loading-state UI was built.

## Tests added (15 total; 94 → 109 declared)

- `DistrictBoundariesTests.swift`: 3 real-coordinate Senato lookups
  (Roma→`S120002`, Milano→`S30003`, Napoli→`S150004` — each
  **independently verified** with a standalone Python even-odd
  ray-casting script against `Data/districts_senato.geojson`, not derived
  from the Swift implementation under test, exactly like the pre-existing
  Camera ones. First draft of these guessed plausible-looking ids
  without running the verification script — caught and corrected before
  landing, a concrete instance of why this project's own "verify before
  hardcoding" methodology note exists.); `testBothChambersContainMultiPolygonDistricts`;
  the Camera performance test renamed
  (`…PerformanceOverOneThousandItalianCoordinatesCamera`) and a Senato
  twin added; `testDistrictsContainingResolvesBothChambersForRealCoordinate`
  / `testDistrictsContainingReturnsEmptyForOpenSeaCoordinate`;
  `testColdDecodePerformanceCameraOnlyVsBothChambersEager`.
- `ServiceLookupTests.swift`: `testDistrictsContainingBucketsByChamberOnMixedSampleFixture`
  — the bucketing test on the mixed sample fixture (3 Camera + 2 Senato in
  one file), confirming `DistrictService` buckets by each feature's own
  `chamber` property rather than by which resource it loaded from.
- `DecodingTests.swift`: `testSenatoDistrictsDecodeWithExpectedCount` (74),
  `testSenatoDistrictsAreSenatoOnly`,
  `testSenatoDistrictIdsAreSPrefixedWithRegioneAndNoCircoscrizione`,
  `testCameraDistrictsHaveNoRegione`,
  `testCameraAndSenatoDistrictIdsAreAllUnique` (221, Swift-side twin of
  `validate_data.py`'s cross-file check). `testShippingDistrictsAreCameraOnly`'s
  doc comment corrected (its assertion was always true and needed no
  logic change — `districts.geojson` stays Camera-only by design — but
  the comment's "until a future phase adds Senato geometry" reads
  misleadingly now that this phase *has* added Senato geometry, just to a
  separate file).
- `SchemaV2Tests.swift`: `testShippingSenatoDistrictsAreOfficialProvenance`.

Full suite: **109 declared / 112 runtime** (up from the Phase 13 baseline
of 94/97 by exactly the 15 new declared tests; the runtime gap is the
same pre-existing `testLaunch()` × 4 pattern documented in Phase 13, not
new flakiness), 0 failures.

## Accessibility surfaces for Phase 22A

New surfaces not yet covered by any accessibility checklist:
- `ChamberPicker` (both `MapView` and `CollegiListView`) — segmented
  control with per-segment `accessibilityLabel` overrides; needs a
  VoiceOver pass confirming it announces "Camera dei Deputati"/"Senato
  della Repubblica", not the short visible label.
- `AddressSearchView`'s new dual-result rows (`ChamberResultRow`) —
  combined accessibility elements with hints, and the not-found variant
  (plain `Text`, no button) — needs a VoiceOver pass confirming both
  variants read sensibly and the not-found row doesn't falsely announce
  as interactive.
- `DistrictDetailView`'s new "Regione: …" line — added inside the
  existing `.accessibilityElement(children: .combine)` header block, so
  it should already read as part of the combined header, but unverified
  by an actual VoiceOver walkthrough.
- `MapView`'s per-chamber caption text — plain `Text`, no special
  accessibility treatment added; should read fine by default but
  unverified.

## Diff scope

```
 Makefile                                | 24 ++++++++++++--
 Politici/Models/District.swift          | 12 ++++++-
 Politici/Services/DistrictService.swift | full rewrite
 Politici/Services/GeoJSONLoader.swift   |  2 +
 Politici/Views/AddressSearchView.swift  | +90 lines (dual-chamber results)
 Politici/Views/CollegiListView.swift    | picker + chamber scoping
 Politici/Views/DistrictDetailView.swift |  6 ++
 Politici/Views/HomeView.swift           |  2 lines (label + bullet text)
 Politici/Views/MapView.swift            | picker + chamber scoping + ChamberPicker
 PoliticiTests/*.swift (5 files)         | +15 tests, existing call sites updated
 docs/DATA_SOURCES.md                    | new Senato section + surgical syncs
 tools/build_boundaries.sh               | chamber parameter
 tools/import_boundaries.py              | chamber parameterization + vertex/byte gates reused
 tools/make_manifest.py                  | new Senato source entry
 tools/validate_data.py                  | Senato validation + cross-file uniqueness

 New: Politici/Data/districts_senato.geojson (847 KB)
 Modified data: Politici/Data/sources.json (new source + corrected note + generatedAt)
```

`Politici/Data/districts.geojson`, `Politici/Data/representatives.json`,
`Politici/Data/votes.json` — byte-identical, zero diff. No file under
`docs/v2/` or `docs/history/` modified.
