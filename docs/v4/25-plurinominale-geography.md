# V4 Phase 25 — Plurinominale Geography, Both Chambers [GO-PLURI: **GO**]

Gives the 245 plurinominale deputies real geography. Ships both ISTAT
plurinominale collegi layers (Camera 49, Senato 26) as new boundary
artifacts, the `collegioPlurinominale` field Phase 18 deferred (389 of 400
deputies), a map collegio-type selector and plurinominale-collegio detail
pages, and the validator/tests that pin all of it.

**Network acts: none.** Both plurinominale shapefiles were already local
under the gitignored `tools/raw/collegi/` (Phase 23 §4.1); every ogr2ogr
run processed those local files. No SPARQL fetch, no download, no user
network gate was needed or invoked.

---

## 1. Preconditions

| Precondition | Verified how | Result |
|---|---|---|
| Phase 23 done (schema dumps — the phase's dependency) | `docs/plan/README.md` row 23 links `../v4/23-baseline-audit.md`; that report carries the two plurinominale `ogrinfo` dumps (§4.2–4.3) and the Q1 evidence (§4.7) | **met** |
| Working tree clean at start | `git status --porcelain` → empty | **met** |
| Branch / tip | `v4`, tip `4bcd006` (Phase 24's commit) | **met** |
| Both plurinominale shapefiles local | `tools/raw/collegi/CAMERA_CollegiPLURINOMINALI_2020/…shp` (50 feat) + `SENATO_CollegiPLURINOMINALI_2020/…shp` (27 feat) present | **met** |
| Camera deputies cache local | `tools/raw/camera_deputati_sparql.json` (1.4 MB) present | **met** |
| GDAL/ogr2ogr available | `ogr2ogr --version` → GDAL 3.13.1 | **met** |

---

## 2. The GO-PLURI gate — per-condition evidence

A committed, re-runnable offline probe —
`tools/probes/probe_plurinominale_geography.py` (output gitignored per the
probes convention) — was written and run **before** any importer/model/UI
change. It runs the same ogr2ogr reproject+simplify the build script will
run, enumerates both layers, runs the full deputy→collegio match, measures
vertices and would-be byte size, and collision-checks the new ids. Verbatim
output:

```
========================================================================
Fase 25 — sonda geografia plurinominale (GO-PLURI)
========================================================================

[camera-plurinominale] 50 feature grezze = 49 con denominazione + 1 segnaposto
  segnaposto: OBJECTID=1 CP20_COD=0 CP20_DEN=None POP_2011=126806.0
    POP_2011 == Valle d'Aosta (126806.0) ✓

[senato-plurinominale] 27 feature grezze = 26 con denominazione + 1 segnaposto
  segnaposto: OBJECTID=1 SP20_COD=0 SP20_DEN=None POP_2011=1156281.0
    POP_2011 == Valle d'Aosta + Trentino-Alto Adige (126806.0+1029475.0=1156281.0) ✓

--- (d) misure a tolleranza 1000m ---
[camera-plurinominale] output ~766581 B (749 KB, 24.4% del gate 3 MB); max vertici 994 (CP200001 Sardegna - P01, 66.3% del gate 1500); MultiPolygon 28
[senato-plurinominale] output ~608842 B (595 KB, 19.4% del gate 3 MB); max vertici 994 (SP200001 Sardegna - P01, 66.3% del gate 1500); MultiPolygon 18

--- id: collisioni tra file di confine ---
  shipped uninominali: 221  nuovi plurinominali: 75 (Camera 49 + Senato 26)
  nessuna collisione — 296 id univoci su tutti i file di confine

--- (c) collegamento deputato -> collegio plurinominale ---
  deputati con coverage P-suffix collegati: 389
    per electionType: {'uninominale': 144, 'plurinominale': 245}
  valori P-suffix distinti: 49 (collegi Camera plurinominali con nome: 49)
  feature plurinominali Camera coperte: 49/49

--- (e) record senza collegioPlurinominale ---
  estero (coverage macro-circoscrizione): 8
  bare (nessun P-code): 3  ["VALLE D'AOSTA", 'VENETO 2', 'VENETO 2']
  senatori: esenti per costruzione (linkage Camera-only)

========================================================================
GO-PLURI: condizioni (a)-(e) verificate.
```

Condition by condition:

- **(a) Schema fields from Phase 23's dumps, no name guessing — PASS.** The
  probe asserts `CP20_COD/CP20_DEN/CP20_C1` (Camera) and `SP20_*` (Senato)
  are present in the ogr output before parsing — the exact fields Phase 23
  §4.2–4.3 recorded. No field is inferred from a name.

- **(b) Q1 fully explained (50-vs-49, 27-vs-26) — PASS.** Each layer has
  exactly **one** null-attribute placeholder (`OBJECTID=1, COD=0,
  DEN/C1 null`), leaving 49 (Camera) / 26 (Senato) named collegi. Each
  placeholder's `POP_2011` matches the Regioni_Senato hypothesis exactly:
  Camera = Valle d'Aosta (126 806), Senato = Valle d'Aosta + Trentino-Alto
  Adige (126 806 + 1 029 475 = 1 156 281). The placeholder-count check would
  make any *other* extra feature a NO-GO; there is none.

- **(c) Every distinct P-code matches exactly one Camera feature, no new
  alias — PASS.** The 49 distinct deputy P-suffix coverage values map
  1:1 onto the 49 named Camera plurinominale features under the existing
  `normalize_circoscrizione` (imported from `import_representatives.py`, not
  re-implemented) — 49 distinct values, all 49 features covered. 389
  deputies (144 uninominale + 245 plurinominale) resolve, and every
  resolution agrees with the deputy's shipped `circoscrizione`.

- **(d) Byte/vertex maxima measured before shipping — PASS, both chambers
  ship.** At the current 1000 m tolerance: Camera **749 KB / 994 vtx**
  (24.4 % / 66.3 % of gate), Senato **595 KB / 994 vtx** (19.4 % / 66.3 %).
  Both clear both gates with wide margin, so **no coarser tolerance and no
  Senato descope were needed** — the two `if … > gate` branches the plan
  called for stayed untaken. (The max-vertex feature is Sardegna P01 for
  both chambers: Sardinia is a single plurinominale collegio per chamber,
  so the two share essentially the island's outline.)

- **(e) Estero + 3 bare + senators carry none — PASS.** 8 estero deputies
  (macro-constituency coverage) and the 3 bare records
  (`VALLE D'AOSTA`, two `VENETO 2` suppletiva) have no resolvable P-code;
  senators are Camera-linkage-exempt by construction.

**Decision: GO.** All five conditions verified; probe exits 0.

### A baseline number corrected by the probe (not trusted from the plan)

The plan's objective text and `00-baseline-and-rules.md` both say "49
distinct P0N codes over **397/400** deputies". The probe's actual
enumeration is **389/400** with a P-suffix coverage (144 uninominale + 245
plurinominale), the other 11 being 8 estero + 3 bare. Phase 18's prose
("cleanly derivable for 397 of 400 … absent for the 3 bare") had silently
folded the 8 estero into the "derivable" side. Every count that ships in
this phase (validator constant, tests, the field's 389-record presence) is
taken from the probe's measurement, per test spec 2 — **not** from the
plan's 397.

---

## 3. `collegioPlurinominale` — the field policy, and why "3-record absence"

`collegioPlurinominale` is present on a deputy **iff their `dc:coverage` is
a `"{CIRC} - P0N"` literal** (389 deputies), absent otherwise. This is the
maximally source-faithful policy — the field is populated exactly where the
source provides the datum — and it is what makes test spec 3's "carries
none" list (estero + the 3 bare + senators) *exhaustive*: among deputies
with a real domestic `circoscrizione`, only the 3 bare records lack it
(Valle d'Aosta has no plurinominale collegio; the two suppletiva by-election
records carry bare coverage), which is exactly the "disclosed 3-record
absence" the objective names. Estero (`circoscrizione: "Estero"`) and
senators are the other, already-understood structural absences. This is the
field-conditional-key convention: the key is **omitted** where absent, never
written as `null` (condition e).

The **UI** is deliberately narrower than the field: a plurinominale-collegio
page lists only the deputies **elected there by proportional list**
(`electionType == .plurinominale`). A uninominale deputy also carries the id
(their seat sits geographically inside that plurinominale collegio), but
they belong on their own uninominale collegio page, not on the plurinominale
one — so the grouping function filters on `electionType`, verified with 1–9
plurinominale deputies per Camera collegio (49/49 non-empty).

---

## 4. Pipeline changes

### 4.1 Boundaries (`build_boundaries.sh` / `import_boundaries.py`)

Two new layer configs added, reusing the existing simplify/vertex/byte
machinery (`--chamber camera-plurinominale` / `senato-plurinominale`; new
Makefile targets `boundaries-plurinominale-camera` /
`-senato`). Generalizations, each measured not guessed:

- `collegioType` is now **config-driven** (was hardcoded `"uninominale"`).
- **Placeholder skipping**: each config declares `expected_placeholders`
  (0 for uninominale, 1 for each plurinominale). A null-attribute row
  (code `0`/no denominazione) is skipped and counted; the run fails loudly
  if the count differs from expected — so an *unexpected* extra feature can
  never be silently shipped, and the uninominale layers (0 expected) still
  fail on any missing-id/name feature exactly as before.
- **Id prefixes** `"CP"` / `"SP"`, applied unconditionally, decided
  in-phase and collision-checked (§2 condition d, and validator).
- Tolerance re-measured for the new layers per the Phase 14 note; the
  1000 m calibration held (§2 condition d), so it was reused, its comment
  updated with the Phase 25 measurements.

Real build output (`make boundaries-plurinominale-camera`, tail):

```
Massimo: CP200001 (Sardegna - P01) — 994 vertici
OK: 49 collegi scritti in Politici/Data/districts_plurinominali_camera.geojson (749 KB)
…
Massimo: SP200001 (Sardegna - P01) — 994 vertici
OK: 26 collegi scritti in Politici/Data/districts_plurinominali_senato.geojson (595 KB)
```

### 4.2 Linkage (`import_representatives.py`)

New `load_plurinominale_index()` reads
`districts_plurinominali_camera.geojson` into
`(normalize(circoscrizione), P-code) -> id`; new
`derive_collegio_plurinominale()` resolves each deputy's coverage,
loud-failing on any P-suffix that doesn't resolve or whose collegio's
circoscrizione disagrees with the deputy's. The `PLURINOMINALE_COVERAGE_RE`
gained a `<sub>` capture for the P-code (the `<circ>` group Phase 18 used is
unchanged). Real run:

```
Collegio plurinominale -> deputato: 389 deputati collegati a 49 collegi plurinominali (11 senza collegio: Estero + record bare)
```

Because `make all` now needs `districts_plurinominali_camera.geojson`
present when `import` runs, the four boundary targets were moved **before**
`import` in `all` (they had already been reading the committed uninominale
files; this makes the dependency explicit and correct for the new file too).

### 4.3 Validator (`validate_data.py`)

- `validate_districts_file` generalized to take the file's own
  `collegioType`; every feature must be that chamber **and** type.
- `validate_districts` now checks all four files and their pairwise id
  uniqueness (296 total).
- Per-record: `collegioPlurinominale` forbidden on senators; on deputies,
  present-non-empty when present, required on every plurinominale deputy,
  forbidden on estero deputies. Aggregate: exactly **389** carry it.
- New `validate_collegio_plurinominale()`: every value resolves to a real
  plurinominale district whose circoscrizione equals the deputy's, and all
  49 collegi are covered.

Real `make validate` (relevant new lines):

```
  deputati con collegioPlurinominale: 389
OK: 49 collegi validi in Politici/Data/districts_plurinominali_camera.geojson (749 KB)
  Camera: 49  MultiPolygon (isole/parti multiple): 28
OK: 26 collegi validi in Politici/Data/districts_plurinominali_senato.geojson (595 KB)
  Senato: 26  MultiPolygon (isole/parti multiple): 18
OK: id univoci tra tutti i file di confine — 296 collegi totali (districts.geojson 147 + districts_senato.geojson 74 + districts_plurinominali_camera.geojson 49 + districts_plurinominali_senato.geojson 26)
…
OK: collegi plurinominali coerenti — 49/49 collegi Camera con almeno un deputato, circoscrizioni concordi
```

### 4.4 Generated-data protocol — every change explained

`make all` (fully offline) is reproducible and green. The complete
`Politici/Data/` diff:

| File | Change | Explanation |
|---|---|---|
| `representatives.json` | **+389, −0** | every changed line is a new `"collegioPlurinominale"` (classified: 389 added, 0 removed, 0 added lines that aren't `collegioPlurinominale`) — sorts between `circoscrizione` and `committees` under `sort_keys=True` |
| `sources.json` | **+18, −1** | two new ISTAT plurinominale source entries + the `generatedAt` bump `2026-07-21 → 2026-07-22` (the harmless metadata-timestamp category) |
| `districts_plurinominali_camera.geojson` | **new (749 KB)** | the Camera plurinominale layer |
| `districts_plurinominali_senato.geojson` | **new (595 KB)** | the Senato plurinominale layer |
| `districts.sample.geojson` | extended | test fixture (see §6) — `collegioType` added to the 5 uninominale rectangles + 2 new plurinominale rectangles; `*.sample.*` convention, never shipped in UI |
| `districts.geojson`, `districts_senato.geojson`, `votes.json` | **byte-identical, zero diff** | confirmed by `git diff --stat` (empty) and re-running both uninominale builds under GDAL 3.13.1 (sha256 unchanged) |

### 4.5 A latent bug this phase surfaced and fixed

This was the first `make manifest` run since Phase 20 normalized
`votes.json` to `{"events":…,"positions":…}`.
`make_manifest.py::votazioni_scope_note` still iterated the old flat list
and crashed (`'str' object has no attribute 'get'`). Fixed to read the
`events` array (handling both shapes). The generated votes note is
**byte-identical** ("12 votazioni…") — only the crash was removed. Recorded
here rather than worked around, per the report-inconvenient-findings rule.

### 4.6 Attribution synced

Two new manifest sources (`istat-collegi-elettorali-camera-plurinominali`,
`…-senato-plurinominali`, CC BY 4.0, `retrievedAt` 2026-07-18 via the shared
`"istat"` key — same download batch). `docs/DATA_SOURCES.md` gained two
matching sections, its now-false "Camera plurinominali boundaries remain out
of scope" line was corrected, and its header count and cross-check list were
updated (6 → 8 entries). `tools/SOURCES.md` (and the gitignored
`tools/raw/SOURCES.txt`) note the plurinominale layers.

> Out-of-scope finding, **not** fixed here: the generated Senato *uninominale*
> source note still reads "Nessun senatore è ancora collegato al proprio
> collegio" — stale since Phase 17 linked 73 senators. It predates this
> phase and is unrelated to plurinominale geography; fixing it would add an
> unrelated `sources.json` change. Flagged for a future doc-sync.

---

## 5. App changes (all user-facing strings Italian)

- **`Representative.collegioPlurinominale: String?`** — decoded/encoded
  `IfPresent`, absent-tolerant like `mandate`/`circoscrizione`.
- **`DistrictService`** — loads all four files, buckets by
  `(chamber, collegioType)`. New `allDistricts(collegioType:)`,
  `allDistricts(chamber:collegioType:)`,
  `district(for:chamber:collegioType:)`; the 2-arg `district(for:chamber:)`
  is now a uninominale convenience, and `districts(containing:)` stays
  uninominale-scoped (address search answers "which collegio directly
  elects here"). `collegioType` finally exercised end-to-end.
- **`RepresentativeService.deputies(inPlurinominaleCollegio:)`** — pure
  static grouping (`camera && .plurinominale && collegioPlurinominale == id`,
  name-sorted).
- **`MapView` / `CollegiListView`** — a shared segmented
  **`CollegioTypePicker`** below the chamber picker (so the chamber picker
  stays the first segmented control). Mutually-exclusive overlay sets; the
  selection card is cleared on type change.
- **`DistrictDetailView`** — a plurinominale collegio now gets its own
  section listing the deputies elected there (Camera) or an honest empty
  state (Senato, no linkage). Uninominale pages unchanged.
- **`HomeView`** — the "Collegi uninominali" stat stays 221
  (`allDistricts(collegioType: .uninominale)`, since `allDistricts()` is now
  296); the "Come funziona" explainer updated for the new geography.

### Pinned Italian strings (new/changed)

| Where | String |
|---|---|
| `CollegioTypePicker` segments | "Uninominali" / "Plurinominali" (VoiceOver: "Collegi uninominali" / "Collegi plurinominali") |
| Map caption | "Collegi {uninominali\|plurinominali} — {Camera dei Deputati\|Senato della Repubblica}" |
| Plurinominale collegio section (Camera) | "Deputati eletti in questo collegio plurinominale" |
| …caption | "Eletti con il sistema proporzionale nelle liste di questo collegio plurinominale." |
| Plurinominale collegio section (Senato) | "Rappresentanti eletti" + empty state "Nessun rappresentante collegato in questa versione del prototipo." |
| Home explainer (Camera) | "…I 49 collegi plurinominali della Camera sono ora visibili sulla mappa (seleziona \"Plurinominali\" nel selettore): la pagina di ciascuno elenca i deputati eletti in quel collegio…" |
| Home explainer (Senato) | "…Sono visibili anche i 26 collegi plurinominali del Senato, come geografia, ma nessun senatore è ancora collegato al proprio collegio in questo prototipo…" |

---

## 6. Tests

Sample fixture `districts.sample.geojson` extended per the `*.sample.*`
convention: the 5 uninominale rectangles gained `collegioType: "uninominale"`
(+ circoscrizione/regione/subCode) so the now-uninominale-scoped
`district(for:chamber:)` still resolves them, and two plurinominale
rectangles were added (`IT-RM-CP01` containing Roma Centro; `IT-TO-SP01`).

Deliberate additions (**+14** vs the Phase 24 baseline of 144), all in
`PoliticiTests`:

| Test | Pins |
|---|---|
| `DecodingTests.testCameraPlurinominaleDistrictsDecodeWithExpectedCount` | 49, Camera/plurinominale/"CP"/circoscrizione |
| `DecodingTests.testSenatoPlurinominaleDistrictsDecodeWithExpectedCount` | 26, Senato/plurinominale/"SP"/regione |
| `DecodingTests.testAllFourBoundaryFilesHaveGloballyUniqueIds` | 296 unique across all four files |
| `DistrictBoundariesTests.testRomaCoordinateResolvesUninominaleAndItsContainingPlurinominale` | one real coordinate → 120101 / CP120101 / S120002 / SP120001 (ids verified by a standalone even-odd ray-cast script) |
| `DistrictBoundariesTests.testResolvedUninominaleAndPlurinominaleShareTheSameCircoscrizione` | both report "Lazio 1" though from different files |
| `ServiceLookupTests.testAllDistrictsFilterByChamberAndCollegioTypeOnSampleFixture` | (chamber, type) bucketing; 5 uninominale / 7 total |
| `ServiceLookupTests.testSampleFixtureNestedUninominaleAndPlurinominaleForOneCoordinate` | nested sample lookup |
| `SchemaV2Tests.testShippingPlurinominaleDistrictsAreOfficialProvenance` | official/plurinominale/ISTAT |
| `SchemaV2Tests.testShippingDeputiesCarryConsistentCollegioPlurinominale` | 389 carry it; resolves + circoscrizione-consistent; estero/senators none; 49 covered |
| `PlurinominaleGeographyTests` (new file, 5) | field decode present/absent; pure grouping returns only that collegio's plurinominale deputies, excludes matching-id uninominale, unknown → empty |

The nested-coordinate ids were verified against the four shipping GeoJSON
files by a standalone even-odd ray-casting script (matching
`PointInPolygon`) **before** hardcoding — not read off the implementation
under test.

### Suite result

One full run on `iPhone 17 Pro` (iOS 26.5), result bundle authoritative:

```
$ xcrun xcresulttool get test-results summary --path p25.xcresult
  "failedTests" : 0,
  "passedTests" : 158,
  "result" : "Passed",
  "skippedTests" : 0,
  "totalTestCount" : 158
```

Exit code 0; `** TEST SUCCEEDED **`. `totalTestCount` **158** = the Phase 24
baseline **144** + the **14** deliberate additions above (all 14 confirmed
present in the bundle by name; declared count re-derived from source with
the Phase 23/24 rule: 146 `func test` + 1 `@Test` + 11 UITests = 158).
Declared == runtime, as since Phase 24. All seven Phase 24 UI smoke flows
passed unchanged — including the two that drive the shared `ChamberPicker`
via `selectChamber`, confirming the new `CollegioTypePicker` (placed below
it) doesn't shadow the chamber selector.

---

## 7. Acceptance criteria walk

1. **Probe output quoted with (a)–(e) individually evidenced; GO/NO-GO
   stated** — §2, GO. (NO-GO would have been report + probe only.)
2. **Validator green with counts from gate evidence, not the plan** — §4.3;
   the 389 (not 397), 49, 26, 296 all come from the probe's measurement.
3. **Shipping-data tests**: every plurinominale deputy carries a resolving,
   circoscrizione-consistent `collegioPlurinominale`; estero + 3 bare +
   senators none; global 296 id uniqueness — §6
   (`testShippingDeputiesCarryConsistentCollegioPlurinominale`,
   `testAllFourBoundaryFilesHaveGloballyUniqueIds`).
4. **`DistrictService` tests**: type-filtered lookups on the extended sample
   fixture; point-in-polygon returns both a uninominale and its containing
   plurinominale for a probe-verified coordinate (ids verified by standalone
   script) — §6.
5. **UI strings pinned, all Italian** — §5.
6. **Suite green; additions counted against Phase 24 baseline** — §6:
   144 → **158** (+14 deliberate).

### Deviations, stated plainly

1. **The plan's "397/400" was wrong; ships 389.** Documented in §2; the
   field's presence, the validator constant, and the tests all use the
   probe's measured 389.
2. **Attribution + a latent `make_manifest.py` bug** (§4.5–4.6) were touched
   beyond the phase file's explicit deliverable list, because shipping new
   geography requires attributing it and `make manifest` had to run to do so.
   One pre-existing, unrelated stale note (Senato uninominale linkage) was
   left unfixed and flagged rather than bundled in.
