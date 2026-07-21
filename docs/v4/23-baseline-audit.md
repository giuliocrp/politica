# V4 Phase 23 — Baseline Audit & Hygiene

Freezes the V4 starting point. Every number below is reproduced by a
quoted command and its actual output, run in this session on
**2026-07-21**. **No app, pipeline, or data file was changed** — the
diff of this phase is this report plus the status flip in
`docs/plan/README.md`.

Network acts: **none**. All work was offline (local git, local Xcode
build/test, local shapefiles under the gitignored `tools/raw/`, local
`make validate`).

---

## 1. Branch ancestry and working tree

```
$ git status --porcelain
(no output)

$ git rev-parse --abbrev-ref HEAD
v4

$ git rev-parse HEAD
390768913d7208322c6cfc1966ce261375012153

$ git log --oneline -3 v4
3907689 docs(v4): commit V4 master plan (per-phase specs, baseline/rules, session workflow) + CLAUDE.md pointers
3dc224e docs(v3): post-22B record — user pushed v3 + tag, merged PR #2, published GitHub release, created v1.0.0
0baedaa Merge pull request #2 from giuliocrp/v3

$ git rev-parse v4^
3dc224e57946b2a101455fcd7c099002b53acb19

$ git merge-base --is-ancestor origin/main v4 && echo YES || echo NO
YES

$ git log --oneline origin/main ^v4
(no output)

$ git log --oneline v4 ^origin/main
3907689 docs(v4): commit V4 master plan (per-phase specs, baseline/rules, session workflow) + CLAUDE.md pointers
```

**Reconciliation with the plan's baseline row.** The baseline table
states `v4` = `origin/v4` = `origin/main` = `3dc224e`. That was true when
the plan was prepared; since then the plan itself was committed on `v4`
as `3907689`. The verified relationship today is:

- `v4` tip = `3907689`, whose **parent is exactly `3dc224e`** = `origin/main`
  = `origin/v4`.
- `origin/main` is an **ancestor** of `v4`; there are **zero** commits on
  `origin/main` that are not on `v4` — no divergence, no rebase needed.
- `v4` is **1 ahead** of `origin/v4` (the unpushed plan commit). Pushing
  is the user's action, never this session's.

The phase file's stop condition ("if `v4` ≠ `origin/main` tip, or the
working tree is dirty: stop") is therefore **not** triggered: the
inequality is the single, expected, in-plan commit, ancestry is linear,
and the working tree is clean. Documented here rather than treated as a
precondition failure.

**Tags — untouched, re-verified:**

```
$ for t in v1.0.0 v2.0-prototype v3.0-prototype; do printf "%s -> %s\n" "$t" "$(git rev-list -n1 $t)"; done
v1.0.0 -> 6d3b866fb85947506b2d03a0b289a6e791de3086
v2.0-prototype -> 72448dc22c69ef8dfdb5ae33376186e14450bdf7
v3.0-prototype -> f90f1940e98bbf05aa031f6160bd9776b84b6d66
```

All three match the baseline table exactly.

---

## 2. Build and test baseline (re-pinned)

### Build

```
$ DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Politici.xcodeproj -scheme Politici -destination 'generic/platform=iOS Simulator' build
…
** BUILD SUCCEEDED **
```

### Simulator discovery

```
$ DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl list devices available | grep iPhone
    iPhone 17 Pro (1E08DF67-1B41-41BB-8B7A-3FEB6068906E) (Booted)
    iPhone 17 Pro Max (2FC60B3C-4451-4DAD-B422-B8E3A7B1B5E2) (Shutdown)
    iPhone 17e (E2D5B5AC-9885-45B5-80CE-C3A8DE59B558) (Shutdown)
    iPhone Air (3F4F7ACE-9271-4E28-84B2-7AAB2545A106) (Shutdown)
    iPhone 17 (A8B89ACF-36DB-449D-A885-70D78057E2AC) (Shutdown)
```

### Test — one fresh full run

```
$ DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Politici.xcodeproj -scheme Politici -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -resultBundlePath <scratch>/p23.xcresult test
…
** TEST SUCCEEDED **        (exit code 0)

$ grep -c "^Test case .* passed" p23-test.log
139
$ grep -c "^Test case .* failed" p23-test.log
0
$ grep -oE "Test case '[A-Za-z0-9_./]+\(\)'" p23-test.log | sort -u | wc -l
     136
```

`.xcresult` summary (authoritative):

```
$ xcrun xcresulttool get test-results summary --path p23.xcresult
  "devicesAndConfigurations": [{ … "failedTests": 0, "passedTests": 139, "skippedTests": 0 … }],
  "failedTests" : 0,
  "passedTests" : 136,
  "result" : "Passed",
  "skippedTests" : 0,
  "statistics" : [
    { "subtitle" : "4 test runs",  "title" : "1 test ran with dynamic parameters" },
    { "subtitle" : "1 test run",   "title" : "1 test collected performance metrics" }
  ],
  "totalTestCount" : 136
```

**Result: 136 declared / 139 runtime, 0 failures — exactly the baseline
row.** No flake occurred this run (the known template `PoliticiUITests`
simulator-clone flake did not reproduce; no re-run was needed).

### Declared-count arithmetic, re-derived from source

Static count at HEAD (XCTest `func test…` + Swift Testing `@Test func`,
both test targets):

```
$ grep -rcE "^[[:space:]]*func test[A-Za-z0-9_]*\(" PoliticiTests --include="*.swift" | sort
PoliticiTests/CircoscrizioneTests.swift:5
PoliticiTests/DateFormattingTests.swift:5
PoliticiTests/DecodingTests.swift:14
PoliticiTests/DistrictBoundariesTests.swift:16
PoliticiTests/FavoritesStoreTests.swift:7
PoliticiTests/GeocodingProvidingTests.swift:7
PoliticiTests/InitialsTests.swift:8
PoliticiTests/MandateTypeTests.swift:4
PoliticiTests/PartyStyleServiceTests.swift:6
PoliticiTests/PointInPolygonTests.swift:7
PoliticiTests/PoliticiTests.swift:0
PoliticiTests/SchemaV2Tests.swift:26
PoliticiTests/ServiceLookupTests.swift:13
PoliticiTests/VoteBrowsingTests.swift:8
PoliticiTests/VoteChoiceAccessibilityTests.swift:6
                                        (sum = 132)

$ grep -rn "@Test" PoliticiTests --include="*.swift"
PoliticiTests/PoliticiTests.swift:13:    @Test func example() async throws {          (+1)

$ grep -rnE "func test[A-Za-z0-9_]*\(" PoliticiUITests --include="*.swift"
PoliticiUITests/PoliticiUITests.swift:26:    func testExample() throws {
PoliticiUITests/PoliticiUITests.swift:37:    func testLaunchPerformance() throws {
PoliticiUITests/PoliticiUITestsLaunchTests.swift:21:    func testLaunch() throws {   (+3)
```

132 + 1 + 3 = **136 declared**, matching `.xcresult`'s `totalTestCount`.

Per-commit walk of the same counting rule across the v3 line (declared
methods in the tree at each commit vs. at its parent):

```
v2 tag 72448dc -> 94
5f6650a feat(v3): phase 16 — Senato uninominale boundaries + chamber-aware map -> 109 (parent 94)
c491548 feat(v3): phase 17 — senator mandates (MandateType) + Senato collegio linkage (GO-LINK) -> 115 (parent 109)
0d75506 feat(v3): phase 18 — plurinominale/estero representation context (gated) -> 121 (parent 115)
873fc5f feat(v3): phase 19 — Preferiti (local favorites) -> 128 (parent 121)
89e0b16 feat(v3): phase 20 — vote browsing (source-backed event identity) + voting-methodology gate -> 136 (parent 128)
HEAD -> 136
```

| Origin | Declared | Runtime |
|---|---|---|
| v3 Phase 13 baseline (= v2 tag tree) | 94 | 97 |
| Phase 16 — Senato boundaries | +15 | +15 |
| Phase 17 — mandates + linkage | +6 | +6 |
| Phase 18 — plurinominale/estero context | +6 | +6 |
| Phase 19 — Preferiti | +7 | +7 |
| Phase 20 — vote browsing | +8 | +8 |
| **Total deliberate additions** | **+42** | **+42** |
| **V4 starting baseline** | **136** | **139** |

94 + 42 = 136; 97 + 42 = 139. Phases 21 and 22/22A/22B added no test
methods (21 was a probe-only early exit; 22 was release documentation).

**The 136 → 139 gap is the same single cause as in v3**, unchanged and
re-confirmed by this run's own statistics block: `"1 test ran with
dynamic parameters" / "4 test runs"` —
`PoliticiUITestsLaunchTests.testLaunch()` runs once per
target-application UI configuration because the unmodified Xcode template
overrides `runsForEachTargetApplicationUIConfiguration` to `true`. 4 runs
− 1 declared = 3 = 139 − 136. Nothing else is unaccounted for.

> Phase 24 deliberately redefines this baseline; the arithmetic above is
> the "before" side that Phase 24's report must start from.

---

## 3. Bundle-size inventory

Measured with `find Politici/Data -type f -exec stat -f "%z %N" {} \;`.
Gates: 3 MiB (3,145,728 B) per boundaries file
(`import_boundaries.py::MAX_OUTPUT_BYTES` = `3 * 1024 * 1024`;
`validate_data.py::MAX_DISTRICTS_FILE_BYTES` = same); 2 MiB (2,097,152 B)
for votes (`import_votes.py::MAX_OUTPUT_BYTES` /
`validate_data.py::MAX_VOTES_FILE_BYTES`); 1500 vertices per feature;
~10 MiB soft bundle ceiling (`probe_votes_scope.py::SOFT_BUNDLE_BYTES` =
`10 * 1024 * 1024`).

| File | Bytes | Gate | % of gate |
|---|---:|---|---:|
| `districts.geojson` | 1,158,457 | 3 MiB / file | **36.83 %** |
| `districts_senato.geojson` | 867,362 | 3 MiB / file | **27.57 %** |
| `votes.json` | 711,439 | 2 MiB | **33.92 %** |
| `representatives.json` | 459,584 | — | — |
| `votes.sample.json` | 6,423 | — (test fixture) | — |
| `representatives.sample.json` | 4,569 | — (test fixture) | — |
| `sources.json` | 3,488 | — | — |
| `districts.sample.geojson` | 2,187 | — (test fixture) | — |
| `parties.json` | 1,620 | — | — |
| **Total `Politici/Data/`** | **3,215,129** | ~10 MiB soft | **30.66 %** |
| … of which real (non-`*.sample.*`) | 3,201,950 | ~10 MiB soft | 30.54 % |

**Reconciliation with the plan's baseline row.** The baseline says
"3,201,950 B total; `Data/` minus votes = 2,490,511 B". Both numbers
reproduce exactly — but only when the three `*.sample.*` fixtures
(13,179 B combined) are excluded: 3,215,129 − 13,179 = 3,201,950, and
3,201,950 − 711,439 = 2,490,511. The baseline figure is therefore the
**real-data** subtotal, not the on-disk `Data/` total. Recorded here so
later phases compare like with like; the `votes.json` percentage (33.92 %
vs. the baseline's "33.9 %") is unaffected.

Vertex gate (measured directly from the shipped GeoJSON):

```
Politici/Data/districts.geojson:        features=147 total_vertices=10790 max=695 (gate 1500 -> 46.3%) mean=73.4
Politici/Data/districts_senato.geojson: features=74  total_vertices=8147  max=800 (gate 1500 -> 53.3%) mean=110.1
```

Offline validator, run unchanged as a read-only integrity check:

```
$ make validate
python3 tools/validate_data.py
OK: 601 record validi in Politici/Data/representatives.json
  Camera: 400  Senato: 201
  provenance official: 601  sample: 0
  con districtId assegnato: 220
  mandati Senato: elettivo 196  a vita 5  emerito 0
  deputati per tipo: uninominale 147  plurinominale 245  estero 8
OK: 147 collegi validi in Politici/Data/districts.geojson (1131 KB)
  Camera: 147  MultiPolygon (isole/parti multiple): 56
OK: 74 collegi validi in Politici/Data/districts_senato.geojson (847 KB)
  Senato: 74  MultiPolygon (isole/parti multiple): 34
OK: id univoci tra le due camere — 221 collegi totali (Camera 147 + Senato 74)
OK: 4788 posizioni in 12 votazioni valide in Politici/Data/votes.json (695 KB)
OK: collegamento coerente — 147/147 collegi uninominali Camera con un deputato corrente
OK: collegamento coerente — 73/74 collegi uninominali Senato con un senatore corrente
OK: circoscrizioni deputati coerenti — 29 valori osservati (29 ammessi: 28 da districts.geojson + 'Estero')
OK: integrità referenziale voti coerente — 4788 posizioni, 399 rappresentanti coinvolti
(exit 0)
```

---

## 4. `tools/raw/` inventory and the five layer dumps (answers Q2)

### 4.1 Inventory

`tools/raw/` is gitignored and present locally (`du -sh`):

| Path | Size | Nature |
|---|---:|---|
| `tools/raw/collegi/` | 172 M | ISTAT 2020 collegi shapefile package (7 layers, see below) |
| `tools/raw/camera_votazioni_sparql.json` | 10 M | Camera votes fetch cache |
| `tools/raw/camera_deputati_sparql.json` | 1.4 M | Camera deputies fetch cache |
| `tools/raw/senato_commissioni_sparql.json` | 760 K | Senato committees fetch cache |
| `tools/raw/camera_collegi_uninominali_wgs84.geojson` | 456 K | pipeline-derived, reprojected |
| `tools/raw/senato_senatori_sparql.json` | 448 K | Senato senators fetch cache |
| `tools/raw/senato_collegi_uninominali_wgs84.geojson` | 336 K | pipeline-derived, reprojected |
| `tools/raw/senato_gruppi_sparql.json` | 220 K | Senato groups fetch cache |
| `tools/raw/SOURCES.txt`, `tools/raw/.fetch_metadata.json` | 4 K | fetch bookkeeping |

Fetch bookkeeping, unchanged by this phase:

```
$ cat tools/raw/.fetch_metadata.json
{ "camera": {"fetchedAt": "2026-07-18"}, "camera_votazioni": {"fetchedAt": "2026-07-18"},
  "istat": {"fetchedAt": "2026-07-18"}, "senato": {"fetchedAt": "2026-07-21"} }

$ grep -i retrieved tools/raw/SOURCES.txt
RetrievedAt: 2026-07-18
RetrievedAt: 2026-07-21
RetrievedAt: 2026-07-18
```

Consistent with `Politici/Data/sources.json` (`retrievedAt`: 1×
2026-07-17, 4× 2026-07-18, 1× 2026-07-21 — the 2026-07-21 entry is the
Phase 17 Senato refetch). No drift found.

`tools/raw/collegi/` contains **seven** shapefile layers: the two
uninominale layers already imported in v2/v3
(`CAMERA_CollegiUNINOMINALI_2020`, `SENATO_CollegiUNINOMINALI_2020`) and
the **five not-yet-imported** layers dumped below.

### 4.2 `CAMERA_CollegiPLURINOMINALI_2020`

```
$ ogrinfo -ro -so tools/raw/collegi/CAMERA_CollegiPLURINOMINALI_2020/CAMERA_CollegiPLURINOMINALI_2020.shp CAMERA_CollegiPLURINOMINALI_2020
INFO: Open of `…/CAMERA_CollegiPLURINOMINALI_2020.shp'
      using driver `ESRI Shapefile' successful.

Layer name: CAMERA_CollegiPLURINOMINALI_2020
Metadata:
  DBF_DATE_LAST_UPDATE=2022-07-28
Geometry: Polygon
Feature Count: 50
Extent: (313279.251400, 3933682.932500) - (1312016.150600, 5220292.292200)
Layer SRS WKT:
PROJCRS["WGS 84 / UTM zone 32N",
    BASEGEOGCRS["WGS 84",
        DATUM["World Geodetic System 1984",
            ELLIPSOID["WGS 84",6378137,298.257223563,
                LENGTHUNIT["metre",1]]],
        PRIMEM["Greenwich",0,
            ANGLEUNIT["degree",0.0174532925199433]],
        ID["EPSG",4326]],
    CONVERSION["UTM zone 32N",
        METHOD["Transverse Mercator",
            ID["EPSG",9807]],
        PARAMETER["Latitude of natural origin",0,
            ANGLEUNIT["Degree",0.0174532925199433],
            ID["EPSG",8801]],
        PARAMETER["Longitude of natural origin",9,
            ANGLEUNIT["Degree",0.0174532925199433],
            ID["EPSG",8802]],
        PARAMETER["Scale factor at natural origin",0.9996,
            SCALEUNIT["unity",1],
            ID["EPSG",8805]],
        PARAMETER["False easting",500000,
            LENGTHUNIT["metre",1],
            ID["EPSG",8806]],
        PARAMETER["False northing",0,
            LENGTHUNIT["metre",1],
            ID["EPSG",8807]]],
    CS[Cartesian,2],
        AXIS["(E)",east,
            ORDER[1],
            LENGTHUNIT["metre",1]],
        AXIS["(N)",north,
            ORDER[2],
            LENGTHUNIT["metre",1]],
    ID["EPSG",32632]]
Data axis to CRS axis mapping: 1,2
OBJECTID: Integer64 (10.0)
CP20_COD: Integer64 (10.0)
CP20_DEN: String (150.0)
CP20_C1: String (254.0)
Shape_Leng: Real (19.11)
Shape_Area: Real (19.11)
POP_2011: Real (19.11)
```

Sample attribute rows (`ogrinfo -ro -al -geom=NO -limit 3`):

```
OGRFeature(CAMERA_CollegiPLURINOMINALI_2020):0
  OBJECTID (Integer64) = 1
  CP20_COD (Integer64) = 0
  CP20_DEN (String) = (null)
  CP20_C1 (String) = (null)
  Shape_Leng (Real) = 325836.36810099997
  Shape_Area (Real) = 3260854220.03999996185
  POP_2011 (Real) = 126806.00000000000

OGRFeature(CAMERA_CollegiPLURINOMINALI_2020):1
  OBJECTID (Integer64) = 2
  CP20_COD (Integer64) = 10101
  CP20_DEN (String) = Piemonte 1 - P01
  CP20_C1 (String) = P01
  Shape_Leng (Real) = 150200.73599799999
  Shape_Area (Real) = 508371093.39999997616
  POP_2011 (Real) = 1241100.00000000000

OGRFeature(CAMERA_CollegiPLURINOMINALI_2020):2
  OBJECTID (Integer64) = 3
  CP20_COD (Integer64) = 10102
  CP20_DEN (String) = Piemonte 1 - P02
  CP20_C1 (String) = P02
  Shape_Leng (Real) = 743590.40530600003
  Shape_Area (Real) = 6318536930.59000015259
  POP_2011 (Real) = 1006680.00000000000
```

### 4.3 `SENATO_CollegiPLURINOMINALI_2020`

```
$ ogrinfo -ro -so tools/raw/collegi/SENATO_CollegiPLURINOMINALI_2020/SENATO_CollegiPLURINOMINALI_2020.shp SENATO_CollegiPLURINOMINALI_2020
INFO: Open of `…/SENATO_CollegiPLURINOMINALI_2020.shp'
      using driver `ESRI Shapefile' successful.

Layer name: SENATO_CollegiPLURINOMINALI_2020
Metadata:
  DBF_DATE_LAST_UPDATE=2022-07-28
Geometry: Polygon
Feature Count: 27
Extent: (313279.251400, 3933682.932500) - (1312016.150600, 5220292.292200)
Layer SRS WKT:
PROJCRS["WGS 84 / UTM zone 32N",
    BASEGEOGCRS["WGS 84",
        DATUM["World Geodetic System 1984",
            ELLIPSOID["WGS 84",6378137,298.257223563,
                LENGTHUNIT["metre",1]]],
        PRIMEM["Greenwich",0,
            ANGLEUNIT["degree",0.0174532925199433]],
        ID["EPSG",4326]],
    CONVERSION["UTM zone 32N",
        METHOD["Transverse Mercator",
            ID["EPSG",9807]],
        PARAMETER["Latitude of natural origin",0,
            ANGLEUNIT["Degree",0.0174532925199433],
            ID["EPSG",8801]],
        PARAMETER["Longitude of natural origin",9,
            ANGLEUNIT["Degree",0.0174532925199433],
            ID["EPSG",8802]],
        PARAMETER["Scale factor at natural origin",0.9996,
            SCALEUNIT["unity",1],
            ID["EPSG",8805]],
        PARAMETER["False easting",500000,
            LENGTHUNIT["metre",1],
            ID["EPSG",8806]],
        PARAMETER["False northing",0,
            LENGTHUNIT["metre",1],
            ID["EPSG",8807]]],
    CS[Cartesian,2],
        AXIS["(E)",east,
            ORDER[1],
            LENGTHUNIT["metre",1]],
        AXIS["(N)",north,
            ORDER[2],
            LENGTHUNIT["metre",1]],
    ID["EPSG",32632]]
Data axis to CRS axis mapping: 1,2
OBJECTID: Integer64 (10.0)
SP20_COD: Integer64 (10.0)
SP20_DEN: String (150.0)
SP20_C1: String (254.0)
Shape_Leng: Real (19.11)
Shape_Area: Real (19.11)
POP_2011: Real (19.11)
```

Sample attribute rows:

```
OGRFeature(SENATO_CollegiPLURINOMINALI_2020):0
  OBJECTID (Integer64) = 1
  SP20_COD (Integer64) = 0
  SP20_DEN (String) = (null)
  SP20_C1 (String) = (null)
  Shape_Leng (Real) = 1185709.50649000006
  Shape_Area (Real) = 16865575799.89999961853
  POP_2011 (Real) = 1156281.00000000000

OGRFeature(SENATO_CollegiPLURINOMINALI_2020):1
  OBJECTID (Integer64) = 2
  SP20_COD (Integer64) = 10001
  SP20_DEN (String) = Piemonte - P01
  SP20_C1 (String) = P01
  Shape_Leng (Real) = 533322.50073299999
  Shape_Area (Real) = 4296956942.46000003815
  POP_2011 (Real) = 1854111.00000000000

OGRFeature(SENATO_CollegiPLURINOMINALI_2020):2
  OBJECTID (Integer64) = 3
  SP20_COD (Integer64) = 10002
  SP20_DEN (String) = Piemonte - P02
  SP20_C1 (String) = P02
  Shape_Leng (Real) = 1427182.98209999991
  Shape_Area (Real) = 21089739385.59999847412
  POP_2011 (Real) = 2509805.00000000000
```

### 4.4 `Circo_Camera_2020` (folder `Circoscrizioni_Camera`)

```
$ ogrinfo -ro -so tools/raw/collegi/Circoscrizioni_Camera/Circo_Camera_2020.shp Circo_Camera_2020
INFO: Open of `…/Circo_Camera_2020.shp'
      using driver `ESRI Shapefile' successful.

Layer name: Circo_Camera_2020
Metadata:
  DBF_DATE_LAST_UPDATE=2022-07-28
Geometry: Polygon
Feature Count: 28
Extent: (313279.251400, 3933682.932500) - (1312016.150600, 5220292.292200)
Layer SRS WKT:
PROJCRS["WGS 84 / UTM zone 32N",
    BASEGEOGCRS["WGS 84",
        DATUM["World Geodetic System 1984",
            ELLIPSOID["WGS 84",6378137,298.257223563,
                LENGTHUNIT["metre",1]]],
        PRIMEM["Greenwich",0,
            ANGLEUNIT["degree",0.0174532925199433]],
        ID["EPSG",4326]],
    CONVERSION["UTM zone 32N",
        METHOD["Transverse Mercator",
            ID["EPSG",9807]],
        PARAMETER["Latitude of natural origin",0,
            ANGLEUNIT["Degree",0.0174532925199433],
            ID["EPSG",8801]],
        PARAMETER["Longitude of natural origin",9,
            ANGLEUNIT["Degree",0.0174532925199433],
            ID["EPSG",8802]],
        PARAMETER["Scale factor at natural origin",0.9996,
            SCALEUNIT["unity",1],
            ID["EPSG",8805]],
        PARAMETER["False easting",500000,
            LENGTHUNIT["metre",1],
            ID["EPSG",8806]],
        PARAMETER["False northing",0,
            LENGTHUNIT["metre",1],
            ID["EPSG",8807]]],
    CS[Cartesian,2],
        AXIS["(E)",east,
            ORDER[1],
            LENGTHUNIT["metre",1]],
        AXIS["(N)",north,
            ORDER[2],
            LENGTHUNIT["metre",1]],
    ID["EPSG",32632]]
Data axis to CRS axis mapping: 1,2
OBJECTID: Integer64 (10.0)
CIRC_COD: Integer64 (10.0)
CIRC_DEN: String (254.0)
Shape_Leng: Real (19.11)
Shape_Area: Real (19.11)
POP_2011: Real (19.11)
```

Sample attribute rows:

```
OGRFeature(Circo_Camera_2020):0
  OBJECTID (Integer64) = 1
  CIRC_COD (Integer64) = 1
  CIRC_DEN (String) = Piemonte 1
  Shape_Leng (Real) = 593389.66930800001
  Shape_Area (Real) = 6826908023.98999977112
  POP_2011 (Real) = 2247780.00000000000

OGRFeature(Circo_Camera_2020):1
  OBJECTID (Integer64) = 2
  CIRC_COD (Integer64) = 2
  CIRC_DEN (String) = Piemonte 2
  Shape_Leng (Real) = 1392232.79900999996
  Shape_Area (Real) = 18559788304.09999847412
  POP_2011 (Real) = 2116136.00000000000

OGRFeature(Circo_Camera_2020):2
  OBJECTID (Integer64) = 3
  CIRC_COD (Integer64) = 3
  CIRC_DEN (String) = Lombardia 1
  Shape_Leng (Real) = 360011.62809900002
  Shape_Area (Real) = 1873839345.19000005722
  POP_2011 (Real) = 3805895.00000000000
```

**28 features — exactly the 28 `circoscrizione` values already carried on
Camera district features and deputy records** (the validator's "29
ammessi: 28 da districts.geojson + 'Estero'" line). The layer is the
polygon form of a vocabulary the app already ships as strings.

### 4.5 `Regioni_Senato_2020` (folder `Regioni_Senato`)

```
$ ogrinfo -ro -so tools/raw/collegi/Regioni_Senato/Regioni_Senato_2020.shp Regioni_Senato_2020
INFO: Open of `…/Regioni_Senato_2020.shp'
      using driver `ESRI Shapefile' successful.

Layer name: Regioni_Senato_2020
Metadata:
  DBF_DATE_LAST_UPDATE=2022-07-28
Geometry: Polygon
Feature Count: 20
Extent: (313279.251400, 3933682.932500) - (1312016.150600, 5220292.292200)
Layer SRS WKT:
PROJCRS["WGS 84 / UTM zone 32N",
    BASEGEOGCRS["WGS 84",
        DATUM["World Geodetic System 1984",
            ELLIPSOID["WGS 84",6378137,298.257223563,
                LENGTHUNIT["metre",1]]],
        PRIMEM["Greenwich",0,
            ANGLEUNIT["degree",0.0174532925199433]],
        ID["EPSG",4326]],
    CONVERSION["UTM zone 32N",
        METHOD["Transverse Mercator",
            ID["EPSG",9807]],
        PARAMETER["Latitude of natural origin",0,
            ANGLEUNIT["Degree",0.0174532925199433],
            ID["EPSG",8801]],
        PARAMETER["Longitude of natural origin",9,
            ANGLEUNIT["Degree",0.0174532925199433],
            ID["EPSG",8802]],
        PARAMETER["Scale factor at natural origin",0.9996,
            SCALEUNIT["unity",1],
            ID["EPSG",8805]],
        PARAMETER["False easting",500000,
            LENGTHUNIT["metre",1],
            ID["EPSG",8806]],
        PARAMETER["False northing",0,
            LENGTHUNIT["metre",1],
            ID["EPSG",8807]]],
    CS[Cartesian,2],
        AXIS["(E)",east,
            ORDER[1],
            LENGTHUNIT["metre",1]],
        AXIS["(N)",north,
            ORDER[2],
            LENGTHUNIT["metre",1]],
    ID["EPSG",32632]]
Data axis to CRS axis mapping: 1,2
OBJECTID: Integer64 (10.0)
COD_REG: Integer64 (10.0)
DEN_REG: String (50.0)
Shape_Leng: Real (19.11)
Shape_Area: Real (19.11)
POP_2011: Real (19.11)
```

Sample attribute rows:

```
OGRFeature(Regioni_Senato_2020):0
  OBJECTID (Integer64) = 1
  COD_REG (Integer64) = 1
  DEN_REG (String) = Piemonte
  Shape_Leng (Real) = 1333427.92992000002
  Shape_Area (Real) = 25386696328.09999847412
  POP_2011 (Real) = 4363916.00000000000

OGRFeature(Regioni_Senato_2020):1
  OBJECTID (Integer64) = 2
  COD_REG (Integer64) = 2
  DEN_REG (String) = Valle d'Aosta
  Shape_Leng (Real) = 325836.36810099997
  Shape_Area (Real) = 3260854220.03999996185
  POP_2011 (Real) = 126806.00000000000

OGRFeature(Regioni_Senato_2020):2
  OBJECTID (Integer64) = 3
  COD_REG (Integer64) = 3
  DEN_REG (String) = Lombardia
  Shape_Leng (Real) = 1511131.90360999992
  Shape_Area (Real) = 23863097455.79999923706
  POP_2011 (Real) = 9704151.00000000000
```

**20 features = the 20 administrative regions**, the grouping level v3
established for Senato collegi (`regione`, unsplit). Note `DEN_REG` here
is the short form (`Valle d'Aosta`, `Trentino-Alto Adige`) — **not**
ISTAT's bilingual names used in the uninominale layer; any future use of
this layer must reconcile that naming, not assume it.

### 4.6 `UT_Collegi2020`

```
$ ogrinfo -ro -so tools/raw/collegi/UT_Collegi2020/UT_Collegi2020.shp UT_Collegi2020
INFO: Open of `…/UT_Collegi2020.shp'
      using driver `ESRI Shapefile' successful.

Layer name: UT_Collegi2020
Metadata:
  DBF_DATE_LAST_UPDATE=2022-09-12
Geometry: Polygon
Feature Count: 8213
Extent: (313279.251400, 3933682.932500) - (1312016.150600, 5220292.292200)
Layer SRS WKT:
PROJCRS["WGS 84 / UTM zone 32N",
    BASEGEOGCRS["WGS 84",
        DATUM["World Geodetic System 1984",
            ELLIPSOID["WGS 84",6378137,298.257223563,
                LENGTHUNIT["metre",1]]],
        PRIMEM["Greenwich",0,
            ANGLEUNIT["degree",0.0174532925199433]],
        ID["EPSG",4326]],
    CONVERSION["UTM zone 32N",
        METHOD["Transverse Mercator",
            ID["EPSG",9807]],
        PARAMETER["Latitude of natural origin",0,
            ANGLEUNIT["Degree",0.0174532925199433],
            ID["EPSG",8801]],
        PARAMETER["Longitude of natural origin",9,
            ANGLEUNIT["Degree",0.0174532925199433],
            ID["EPSG",8802]],
        PARAMETER["Scale factor at natural origin",0.9996,
            SCALEUNIT["unity",1],
            ID["EPSG",8805]],
        PARAMETER["False easting",500000,
            LENGTHUNIT["metre",1],
            ID["EPSG",8806]],
        PARAMETER["False northing",0,
            LENGTHUNIT["metre",1],
            ID["EPSG",8807]]],
    CS[Cartesian,2],
        AXIS["(E)",east,
            ORDER[1],
            LENGTHUNIT["metre",1]],
        AXIS["(N)",north,
            ORDER[2],
            LENGTHUNIT["metre",1]],
    ID["EPSG",32632]]
Data axis to CRS axis mapping: 1,2
COD_REG: Integer64 (10.0)
OBJECTID: Integer64 (10.0)
DEN_REG: String (50.0)
COD_PRO: Integer64 (10.0)
DEN_P_CM: String (254.0)
COD_CM: Integer64 (10.0)
PRO_COM: Integer64 (10.0)
DEN_COM: String (254.0)
CAP20_DEN: String (50.0)
POP_2011: Integer64 (10.0)
ASC_COD: Integer64 (10.0)
ASC_COD1: Integer64 (10.0)
ASC_COD2: String (254.0)
ASC_NOME: String (254.0)
ASC_TIPO: String (254.0)
CIRC_COD: Integer64 (10.0)
CIRC_DEN: String (254.0)
CU20_COD: Integer64 (10.0)
CP20_COD: Integer64 (10.0)
SU20_COD: Integer64 (10.0)
SP20_COD: Integer64 (10.0)
CU20_DEN: String (150.0)
CP20_DEN: String (150.0)
SU20_DEN: String (150.0)
SP20_DEN: String (150.0)
CU20_C1: String (254.0)
CP20_C1: String (254.0)
SU20_C1: String (254.0)
SP20_C1: String (254.0)
```

Sample attribute rows (first 3 features, and one Roma sub-comunal row to
show the `ASC_*` block populated):

```
OGRFeature(UT_Collegi2020):0
  COD_REG (Integer64) = 2
  OBJECTID (Integer64) = 1
  DEN_REG (String) = Valle d'Aosta
  COD_PRO (Integer64) = 7
  DEN_P_CM (String) = Aosta
  COD_CM (Integer64) = 0
  PRO_COM (Integer64) = 7053
  DEN_COM (String) = Pré-Saint-Didier
  CAP20_DEN (String) = (null)
  POP_2011 (Integer64) = 1012
  ASC_COD (Integer64) = 0
  ASC_COD1 (Integer64) = 0
  ASC_COD2 (String) = (null)
  ASC_NOME (String) = (null)
  ASC_TIPO (String) = (null)
  CIRC_COD (Integer64) = 27
  CIRC_DEN (String) = Valle d'Aosta/Vallée d'Aoste
  CU20_COD (Integer64) = 20001
  CP20_COD (Integer64) = 0
  SU20_COD (Integer64) = 20001
  SP20_COD (Integer64) = 0
  CU20_DEN (String) = Valle d'aosta/Vallée d'Aoste - U01
  CP20_DEN (String) = (null)
  SU20_DEN (String) = Valle d'aosta/Vallée d'Aoste - U01
  SP20_DEN (String) = (null)
  CU20_C1 (String) = U01
  CP20_C1 (String) = (null)
  SU20_C1 (String) = U01
  SP20_C1 (String) = (null)

OGRFeature(UT_Collegi2020):1
  … PRO_COM = 7054, DEN_COM = Quart, POP_2011 = 3872 — same collegio fields as above …

OGRFeature(UT_Collegi2020):2
  … PRO_COM = 7010, DEN_COM = Bionaz, POP_2011 = 234 — same collegio fields as above …

OGRFeature(UT_Collegi2020):75          # ogrinfo -where "PRO_COM = 58091"
  COD_REG (Integer64) = 12
  OBJECTID (Integer64) = 76
  DEN_REG (String) = Lazio
  COD_PRO (Integer64) = 58
  DEN_P_CM (String) = Roma
  COD_CM (Integer64) = 258
  PRO_COM (Integer64) = 58091
  DEN_COM (String) = Roma
  CAP20_DEN (String) = Roma
  POP_2011 (Integer64) = 6472
  ASC_COD (Integer64) = 58091005
  ASC_COD1 (Integer64) = 5
  ASC_COD2 (String) = 10d
  ASC_NOME (String) = Pignatelli
  ASC_TIPO (String) = Zona Urbanistica
  CIRC_COD (Integer64) = 15
  CIRC_DEN (String) = Lazio 1
  CU20_COD (Integer64) = 120104
  CP20_COD (Integer64) = 120102
  SU20_COD (Integer64) = 120004
  SP20_COD (Integer64) = 120001
  CU20_DEN (String) = Lazio 1 - U04
  CP20_DEN (String) = Lazio 1 - P02
  SU20_DEN (String) = Lazio - U04
  SP20_DEN (String) = Lazio - P01
  CU20_C1 (String) = U04
  CP20_C1 (String) = P02
  SU20_C1 (String) = U04
  SP20_C1 (String) = P01
```

**What `UT_Collegi2020` actually is (Q2's main unknown): the
comune-level "unità territoriali" base table from which every collegi
layer is aggregated.** Measured, not assumed:

```
features: 8213
distinct PRO_COM: 7904
distinct DEN_COM: 7898
comuni appearing >1 time: 6   max repeats: 155
most repeated: 58091 (Roma) ×155, 15146 (Milano) ×88, 63049 (Napoli) ×30
```

8,213 features over **7,904 distinct comuni**: six large comuni are split
into sub-comunal polygons (`ASC_TIPO = "Zona Urbanistica"` and similar),
because a single comune can straddle more than one collegio. Each row
carries its comune identity (`PRO_COM`, `DEN_COM`, `POP_2011`) **and**
all four collegio memberships (Camera uninominale/plurinominale, Senato
uninominale/plurinominale) plus `CIRC_COD`/`CIRC_DEN`.

> **Note for Phase 30 (Q5).** This layer is a comune-level geometry set
> already present locally under the same ISTAT collegi package this
> project already documents and attributes — a candidate source for
> comuni centroids that would need **no new acquisition and no new
> licence**. It is *evidence for* Phase 30 to evaluate, not a decision:
> its comune list is ISTAT-2020 vintage with 6 comuni split into multiple
> rows, and Phase 30 owns the choice of product, licence check, and
> centroid method. Nothing here pre-empts that.

### 4.7 Evidence bearing on Q1 (owned by Phase 25 — evidence only)

Full code listings were extracted from both plurinominale layers
(`ogr2ogr -f CSV … -sql "SELECT OBJECTID, CP20_COD, CP20_C1, CP20_DEN,
POP_2011 …"`, written to the session scratchpad, never to the repo):

- **Camera: 50 features = 1 null-attribute row + 49 named collegi.** The
  49 named rows carry `CP20_DEN` values of the form `"{CIRC} - P0N"`
  (`Piemonte 1 - P01` … `Sardegna - P01`), i.e. the same shape as the
  Phase-18 deputy coverage codes. The odd row is `OBJECTID = 1`,
  `CP20_COD = 0`, `CP20_DEN`/`CP20_C1` **null**, `POP_2011 = 126806`.
- **Senato: 27 features = 1 null-attribute row + 26 named collegi.** The
  odd row is `OBJECTID = 1`, `SP20_COD = 0`, `SP20_DEN`/`SP20_C1`
  **null**, `POP_2011 = 1156281`.

Cross-checked against `Regioni_Senato_2020`'s own `POP_2011` values:

```
Valle d'Aosta=126806 + Trentino-Alto Adige=1029475 -> 1156281
Senato null-feature POP_2011 = 1156281 ; match = True
Camera null-feature POP_2011 = 126806  ; match VdA = True
```

The Camera null row's `Shape_Leng`/`Shape_Area`
(`325836.36810099997` / `3260854220.03999996185`) are also byte-identical
to `Regioni_Senato_2020`'s Valle d'Aosta row. Consistent with this, the
Camera layer *does* contain `Trentino-Alto Adige/Südtirol - P01`
(`CP20_COD = 40001`) while the Senato layer contains no
Trentino-Alto Adige feature at all.

**Reading (for Phase 25 to confirm or reject, not settled here):** each
layer's null row appears to be a residual polygon covering the territory
that has no plurinominale collegio in that chamber — Valle d'Aosta for
Camera, Valle d'Aosta + Trentino-Alto Adige for Senato — which matches
the plan's placeholder hypothesis and yields the expected 49 (Camera) and
26 (Senato) real collegi. Phase 25's GO-PLURI condition (b) still owns
the decision; this phase only supplies the attribute evidence it asked
for.

---

## 5. Methodology gate — restated, not re-derived

`Politici/Data/votes.json` is **byte-identical** to the file committed in
v3 Phase 20:

```
$ git show 89e0b16:Politici/Data/votes.json | shasum -a 256
c70cfd8dcf90195daefd4228ee05384f79da6be35634a905cb49301af550feba  -
$ shasum -a 256 Politici/Data/votes.json
c70cfd8dcf90195daefd4228ee05384f79da6be35634a905cb49301af550feba  Politici/Data/votes.json

$ git log --oneline -- Politici/Data/votes.json
89e0b16 feat(v3): phase 20 — vote browsing (source-backed event identity) + voting-methodology gate
6625944 feat(v2): curated official Camera votes with per-deputy positions
8b16be1 fix(v2): reconcile bundle integrity, honest empty states, sigla styling, pipeline hygiene
6d3b866 Complete Prototype v1: all phases, icon, display name rename
```

Phase 21 was an early exit that changed no data, so
`docs/v3/votes-methodology.md`'s re-evaluation protocol is **not**
triggered and its table is **not stale**. Re-measured from the current
file where the shipped schema allows:

| # | Requirement | Re-measured now | Status |
|---|---|---|---|
| 1 | ≥ 30 events | **12 events**, 4,788 positions | ✗ |
| 2 | ≥ 3 distinct sittings | **1** — all 12 ids are `vs19_690_…` (seduta 690) | ✗ |
| 3 | ≥ 6 months span | **1 day** — single distinct `date`: `2026-07-15` | ✗ |
| 4 | ≥ 2 distinct atti | all 12 titles are `Votazione Ordine del giorno 9/2822-A E ABB/N` — Phase 20's "0 atto-bearing events" classification restated, unchanged data | ✗ |
| 5 | `astenuto` its own category | `VoteChoice` has a distinct `case astenuto = "Astenuto"`; distribution: Contrario 2,938 / Assente 980 / Favorevole 836 / **Astenuto 34** — never folded | ✓ |
| 6 | Group membership at vote date | `representatives.json` still carries only the current `parliamentaryGroup` (601 occurrences); zero `groupHistory`/interval fields | ✗ |

**Still 1 of 6. No vote-derived metric may ship.** Phase 29 remains
blocked on Phase 27 (lines 1–4) and Phase 28 (line 6), and remains a
legitimate NOT RUN.

---

## 6. Commissioning-brief gap (Q6) — still open

Repeated the Phase 13 §10 search against today's tree:

```
$ find . -iname "*commission*" -not -path "./.git/*"
./docs/history/HISTORY_PACK_COMMISSIONING_BRIEF.md
./tools/queries/senato_commissioni.rq
./tools/raw/senato_commissioni_sparql.json
$ find . -iname "*brief*" -not -path "./.git/*"
./docs/history/HISTORY_PACK_COMMISSIONING_BRIEF.md
```

The only commissioning brief in the repo remains the **historical
documentation pack**'s brief (`docs/history/HISTORY_PACK_COMMISSIONING_BRIEF.md`),
which its own header says is not a V3 architecture task. No V3 (or V4)
commissioning brief exists in the tree, the working directory, or the
untracked/ignored set. **Nothing was fabricated in its place.** Q6 stays
open and is restated in Phase 32A; if the user provides the document, it
can be archived verbatim under `docs/history/`, labelled user-provided.

---

## 7. Hygiene findings

No hygiene issue found in this audit met the "trivially safe to fix" bar,
so **nothing was fixed**. All four items are listed with their evidence
and disposition:

1. **Test-only `*.sample.*` fixtures ship inside the app bundle**
   (13,179 B: `districts.sample.geojson` 2,187 + `representatives.sample.json`
   4,569 + `votes.sample.json` 6,423). Confirmed in the built product:
   ```
   $ find …/Debug-iphonesimulator/Politici.app -name "*.json" -o -name "*.geojson"
   sources.json  districts.sample.geojson  districts_senato.geojson  representatives.json
   votes.sample.json  parties.json  votes.json  representatives.sample.json  districts.geojson
   ```
   Cause: the target uses `PBXFileSystemSynchronizedRootGroup`, so every
   file under `Politici/` is a bundled resource.
   **Disposition: leave as is — this is load-bearing, not an oversight.**
   Every service resolves resources from `Bundle.main`
   (`DistrictService(resources:…, bundle: Bundle = .main)`, likewise
   `VoteService`, `RepresentativeService`, `PartyStyleService`,
   `ManifestService`), and the unit tests run in the app process, so
   `DistrictService(resources: ["districts.sample"])` and
   `VoteService(resource: "votes.sample")` would fail to load if the
   fixtures were excluded. The cost is 0.41 % of `Data/`; the fixtures
   are never referenced by any shipping view and are `provenance:
   "sample"`. Any future exclusion belongs in a deliberate phase with a
   test-bundle-resource migration, not in a hygiene pass.
2. **Baseline bundle figure is the real-data subtotal, not the `Data/`
   total** — see §3. No code or data implication; recorded so later
   phases don't "discover" a 13,179 B discrepancy.
3. **`Regioni_Senato_2020.DEN_REG` uses short region names** while the
   shipped Senato districts use ISTAT's bilingual forms (the v3
   `"VALLE D'AOSTA"` alias exists precisely because of this). Not a
   defect — a documented trap for whichever phase first uses that layer.
4. **`.DS_Store` files present** at repo root, `docs/history/`, and
   `tools/raw/collegi/`. All are already covered by `.gitignore`'s
   `.DS_Store` rule (`git status --porcelain --ignored` lists them as
   ignored); none is tracked. No action.

Checks that came back clean and needed no entry above: `git status`
clean; `.gitignore` covers `tools/raw/` and `tools/probes/output/`;
`tools/raw/.fetch_metadata.json`, `tools/raw/SOURCES.txt` and
`Politici/Data/sources.json` agree on retrieval dates; `make validate`
exits 0 with the counts quoted in §3.

---

## 8. Acceptance criteria

| # | Criterion | Outcome |
|---|---|---|
| 1 | Full suite green at exactly 136 declared / 139 runtime, arithmetic restated | **Met** — §2: `** TEST SUCCEEDED **`, `totalTestCount 136`, `passedTests 139` per device, 0 failures; 94 + 42 = 136 and 97 + 42 = 139 with the per-phase table |
| 2 | Report contains the five-layer `ogrinfo` dumps verbatim + bundle table with bytes and gate percentages | **Met** — §4.2–4.6 (full `-so` dumps including SRS and field lists, plus 2–3 sample attribute rows each), §3 |
| 3 | `git status` clean except the report and the README status flip | **Met** — see §9 |
| 4 | Report committed in the phase commit with the pinned message | **Met** — `chore(v4): phase 23 — baseline audit (branch, tests, bundle, raw-layer inventory)` |

Additional deliverables from the objectives: Q2 answered (§4.4–4.6);
Q1 evidence supplied without pre-empting Phase 25 (§4.7); methodology
gate restated (§5); Q6 restated as still open (§6).

**Deviations from the phase file:** one, documented in §1 — `v4` is one
commit ahead of `origin/main` (the V4 plan commit itself, `3907689`),
rather than equal to it. Ancestry is linear with zero divergence, so the
phase's stop condition was judged not triggered; this is recorded rather
than silently normalised.

---

## 9. Diff scope for this commit

```
docs/v4/23-baseline-audit.md   (new — this report)
docs/plan/README.md            (Phase 23 status row: pending -> done)
```

No file under `Politici/`, `tools/`, `docs/v2/`, `docs/v3/`, or
`docs/history/` was modified. No generated data file was regenerated —
the generated-data protocol has nothing to report because no pipeline
step that writes ran (`make validate` is read-only).

Remote actions are the user's. Not run here:

```
git push origin v4
```
