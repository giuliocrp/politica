# V4 Phase 30 — Offline Geocoding: Comuni Centroids

Replaces the five-city offline geocoding ceiling with a bundled table of
**all 7,904 Italian comuni** and their ISTAT-derived interior points, so any
comune name resolves to a coordinate — and through the existing
point-in-polygon path to a collegio — **entirely offline**.

**GO-COMUNI: GO**, on the evidence in §2–§5. Every number below was measured
in-session on **2026-07-23** against the actual repository state.

**Network acts: none.** **New downloads: none.** The decisive finding of this
phase is that the comuni product it needed was **already in the repository**,
inside the ISTAT collegi package this project has downloaded, documented and
attributed since v2 — so the phase's user-gated *acquisition* resolved to "no
acquisition required" (§1).

---

## 1. The acquisition gate — asked, answered, and resolved to "no acquisition"

The phase file binds this session to state "**exactly which file it needs and
from which official URL/page**, and get approval quoted verbatim — the same
shape as the collegi-shapefile acquisition, no downloading first and
reconciling later."

Before writing any bundled artifact, an offline feasibility probe of
already-local data (§2) established that the needed product was
`tools/raw/collegi/UT_Collegi2020` — the comune-level base table **inside the
already-downloaded ISTAT collegi package**, flagged as a candidate by
[`23-baseline-audit.md`](23-baseline-audit.md) §4.6 precisely because it
"would need **no new acquisition and no new licence**."

The user was presented with that finding and the alternative (a fresh,
separately-acquired, current-vintage ISTAT comuni product), including the
vintage-mismatch risk the alternative carries. **The user's decision,
verbatim:**

> **Use local UT_Collegi2020 (Recommended)**

with the option text they selected reading, in full:

> "Derive centroids from the ISTAT 2020 collegi package already in
> tools/raw/collegi/ — no new download, no network, same CC BY 4.0 licence
> already documented in-repo, vintage identical to the shipped collegi bases.
> Measured: 99.92% resolution, 0.08% nil, 568 KiB. This is the file/URL:
> tools/raw/collegi/UT_Collegi2020 from
> istat.it/notizia/le-basi-geografiche-dei-nuovi-collegi-elettorali-2 (CC BY
> 4.0)."

No fetch, no download, and no network call of any kind ran in this phase.
`tools/raw/.fetch_metadata.json`'s `istat` key still reads its real historical
value and was **not** advanced:

```
$ python3 -c "import json;print(json.load(open('tools/raw/.fetch_metadata.json'))['istat'])"
{'fetchedAt': '2026-07-18'}
```

> **Scope of this approval — the approval predates the centroid method
> change.** The figures quoted in the approval text (99.92 % / 0.08 % nil,
> 568 KiB) are the **first** probe pass, using a whole-comune-union interior
> point; the shipped configuration uses largest-polygon-part centroids and
> different numbers (99.94 % / 0.06 %). What the user approved is the
> **choice of source** — local `UT_Collegi2020` over a fresh acquisition —
> which the method change does not affect. §4 documents the change and
> publishes both passes; it **strictly improved every measure** (Camera and
> Senato resolution both up, both-chamber nil 2 → 1, accuracy unchanged, size
> unchanged), so under the standing rule now recorded in
> `docs/plan/00-baseline-and-rules.md` (rule 10) it is disclosed here rather
> than sent back for re-approval. Had any measure worsened, or had the basis
> of the source decision shifted, it would have gone back first.

---

## 2. The GO-COMUNI gate, condition by condition

### (a) Product identified, licence verified CC BY-compatible, quoted

**Product:** the `UT_Collegi2020` layer of *Basi geografiche dei collegi
elettorali (D.Lgs. 177/2020)*, ISTAT.

**Page:** <https://www.istat.it/notizia/le-basi-geografiche-dei-nuovi-collegi-elettorali-2>

**Licence: CC BY 4.0.** This is *not* a newly-asserted licence needing fresh
verification against a product page: it is the **same file, from the same
release, from the same single manual download batch** that already backs the
four bundled boundary files, whose CC BY 4.0 licence is recorded in the
committed provenance record `tools/SOURCES.md`:

```
# ISTAT — Collegi Elettorali
Name: Basi geografiche dei collegi elettorali (D.Lgs. 177/2020)
URL: https://www.istat.it/notizia/le-basi-geografiche-dei-nuovi-collegi-elettorali-2
License: CC BY 4.0
LicenseURL: https://creativecommons.org/licenses/by/4.0/
RetrievedAt: 2026-07-18
Notes: Shapefile format, one manual download batch covering every layer. …
```

and in `docs/DATA_SOURCES.md` for all four existing ISTAT entries as
"**CC BY 4.0** — verified at
[creativecommons.org/licenses/by/4.0](https://creativecommons.org/licenses/by/4.0/)".

The phase file's live constraint — "if the actual ISTAT product page does not
carry a verifiable, CC-BY-compatible licence quotable verbatim, the GO-COMUNI
gate fails" — is satisfied **without needing to re-reach the network**,
because the licence for this exact product was verified and quoted when it was
acquired, and this phase adds no new product. Nothing about the licence was
reconstructed, assumed, or inferred. **Condition (a): PASS.**

### (b) Vintage consistency with the 2020 collegi bases

This is the condition the chosen source satisfies most strongly, and the
reason it was preferred. `UT_Collegi2020` is **not a separate comuni product
that has to be reconciled against the collegi bases — it is the table the
collegi bases are aggregated from**, shipped in the same package
([`23-baseline-audit.md`](23-baseline-audit.md) §4.6). Its comune list is
therefore the ISTAT-2020 vintage **by construction**, identical to the
vintage of `districts.geojson`, `districts_senato.geojson` and both
plurinominale files.

**Consequently there are no mergers or renames to enumerate between the
comuni table and the collegi bases** — the enumeration the gate asks for is
empty, and empty for a structural reason, not because it was skipped. Every
comune row carries its own collegio memberships (`CU20_COD`, `SU20_COD`,
`CP20_COD`, `SP20_COD`), which §5 uses as ground truth.

The honest limitation to state: **both** the comuni table and the collegi
bases are 2020-vintage, so comuni that have merged or been renamed *in
reality* since 2020 appear under their 2020 identity in this app. That is a
property of the whole dataset, disclosed, and not a drift *between* the two
files. **Condition (b): PASS.**

### (c) Full-table dry run, nil rate measured, disclose-vs-snap decided

Committed probe: [`tools/probes/probe_comuni_centroids.py`](../../tools/probes/probe_comuni_centroids.py).
It resolves **every** comune's interior point against **both** shipped
uninominale boundary files and cross-checks against the source's own collegio
code. Output on the shipped method (§4):

```
================ PHASE 30 GO-COMUNI PROBE SUMMARY ================
source layer         : tools/raw/collegi/UT_Collegi2020 (ISTAT 2020, CC BY 4.0)
distinct comuni      : 7904
interior-point method: OGR PointOnSurface of the comune's LARGEST polygon part
centroid-outside self-check (plain Centroid fell outside the chosen part): 89

comuni_candidate.json (compact {name,province,lat,lon}, 5 dp): 581848 bytes = 568.2 KiB

--- Camera uninominale dry run ---
resolved (hit)  : 7899  (99.94%)
nil (outside)   : 5  (0.06%)
  of hits: match source CU20_COD : 7897  (99.97% of hits)
          mismatch               : 2  (0.03% of hits)
          comune had no CU code   : 0

--- Senato uninominale dry run ---
resolved (hit)  : 7902  (99.97%)
nil (outside)   : 2  (0.03%)

both-chambers nil: 1  (0.01%)

--- sample Camera mismatches (resolved vs source codes) ---
    ('Carbonara di Nola', 'Napoli', '150204', ['150106'])
    ("Torre de' Roveri", 'Bergamo', '30302', ['30301'])

--- sample both-nil comuni (outside every shipped polygon) ---
    ('Isole Tremiti', 'Foggia', 42.11467, 15.4871)
=================================================================
```

**Measured nil rate: 0.06 % (Camera), 0.03 % (Senato), 0.01 % both chambers —
a single comune, Isole Tremiti.** The gate names "a high nil rate" as a NO-GO
trigger; 1 comune in 7,904 is not that.

**Decision — disclose, do not snap.** The 1 both-nil comune and the 5/2
single-chamber nils are **left unresolved**, surfacing the app's existing
honest not-covered message, rather than being snapped to a nearest collegio.
Rationale, and it is a data-integrity rationale rather than an effort one:
these centroids are outside every collegio polygon **because the shipped
boundaries are simplified at a 1000 m tolerance that drops small islands**,
not because the comune has no collegio. Snapping would present a *computed
guess* about which collegio a real place elects — indistinguishable, in the
UI, from a sourced fact. That is exactly what standing constraint #4 forbids.
Isole Tremiti genuinely belongs to a Camera collegio in the source
(`CU20_COD` is present on its row); the app simply cannot demonstrate that
from the geometry it ships, and says so instead of inventing it.

The **2 Camera mismatches** (0.03 % of hits) are the same phenomenon one step
milder: `Carbonara di Nola` and `Torre de' Roveri` are small border comuni
whose interior point falls on the wrong side of a *simplified* boundary, so
they resolve to a neighbouring collegio rather than the one the source
assigns. Disclosed here as a known, measured inaccuracy of ~2 in 7,900, not
corrected by hand-patching the data (which the generated-artifact rule
forbids and which would hide the underlying simplification effect).
**Condition (c): PASS.**

### (d) No regression of address-level results — CLGeocoder still wins

Enforced structurally, not by convention: `GeocodingService` tries the
injected `AddressResolving` (production: `CLGeocoderResolver`) **first** and
returns immediately on success; the comuni table is consulted only after that
tier returns `nil`. Pinned by
`GeocodingTierTests.testTier1CLGeocoderWinsWhenAvailable`, which supplies a
comuni-table match *and* a CLGeocoder match for the same query and asserts the
CLGeocoder coordinate is the one returned (§7).

The UI's homonym interception (§6) is likewise **exact-comune-name only**, so
it cannot fire for a street address such as "Bolzano, Via del Corso" — that
query goes to CLGeocoder as before. **Condition (d): PASS.**

**GO-COMUNI: GO on all four conditions.**

---

## 3. What the source actually contains (inspected, not assumed)

Per the working methodology, the raw layer was inspected before any pipeline
code was written against it.

| Measured fact | Value |
|---|---|
| Features in `UT_Collegi2020` | 8,213 |
| Distinct comuni (`PRO_COM`) | **7,904** |
| Distinct comune names (`DEN_COM`) | 7,898 |
| Comuni split across >1 row | 6 (Roma ×155, Milano ×88, Napoli ×30, Palermo ×25, Genova ×9, Torino ×8) |
| Distinct `(name, province)` pairs | **7,904 — i.e. unique** |
| Comuni with empty name or province | 0 |

Two findings materially shaped the design:

**Homonyms are real and must be disambiguated by province.** Six comune names
each occur in two different provinces:

```
'Calliano'     -> [(5014, 'Asti'),    (22035, 'Trento')]
'Castro'       -> [(16065, 'Bergamo'), (75096, 'Lecce')]
'Livo'         -> [(13130, 'Como'),    (22106, 'Trento')]
'Peglio'       -> [(13178, 'Como'),    (41041, 'Pesaro e Urbino')]
'Samone'       -> [(1235, 'Torino'),   (22165, 'Trento')]
'San Teodoro'  -> [(83090, 'Messina'), (90092, 'Sassari')]
```

`(name, province)` being unique across all 7,904 comuni is what makes the
compact `{name, province, lat, lon}` schema sufficient and lets `Comune.id`
be `"name|province"`.

**The source carries Italian-only comune names — a deviation from the phase
file's wording, documented rather than papered over.** The phase file
specifies "bilingual names match either side of the `/`". Measured against the
actual layer:

```
names containing '/': 0
Bolzano-province comuni: 116 — 'Bolzano', 'Bressanone', 'Brunico', 'Chiusa', …
names w/ chars beyond the Italian basic set: 5
    'Châtillon', 'Hône', 'Rhêmes-Notre-Dame', 'Rhêmes-Saint-Georges', 'Jovençan'
```

**Zero `DEN_COM` values contain a slash**; South Tyrolean comuni appear under
their Italian names only (`Bolzano`, not `Bolzano/Bozen`). The bilingual `/`
form exists in this package on *collegio* and *circoscrizione* names
(`Valle d'aosta/Vallée d'Aoste`), not on comune names.

Manufacturing the German/Ladin exonyms to satisfy the spec's literal wording
would be fabricating geographic data the source does not contain — standing
constraint #4. **Resolution:** the slash-splitting logic is implemented on the
**query** side, so a user typing `"Bolzano/Bozen"` resolves via its Italian
side, while a German-only query (`"Bozen"`) honestly returns no match. Both
behaviours are pinned by tests (`testBilingualQueryResolvesViaItalianSide`,
`testGermanOnlyExonymDoesNotResolve`).

---

## 4. Centroid method — two measured decisions

The phase file allows centroids "computed via ogr from ISTAT geometry, or
taken from an ISTAT-published coordinate table — whichever the actual product
provides". The product provides **geometry**, so centroids are computed. Two
sub-decisions were each settled by measurement, not preference.

**Decision 1 — `PointOnSurface`, not the mathematical centroid.** A centroid
can fall outside its own polygon (concave comuni, island municipalities). On
the chosen parts this happens for **89 of 7,904** comuni, each of which would
have become a spurious nil. `PointOnSurface` returns a representative point
guaranteed to lie inside the geometry.

**Decision 2 — the comune's largest polygon *part*, not the union of parts.**
The first implementation took an interior point of the whole-comune union.
The full-table dry run exposed a concrete failure:

```
Roma  -> Camera: None   (source CU20 codes: 120101,120102,…,120107)
```

**Rome resolved to no Camera collegio at all.** Rome is split across seven
Camera collegi; an interior point of its *union* landed in a sliver gap
between two independently-simplified collegi polygons. Since Roma is one of
the app's five sample-city chips, shipping that would have been a visible
regression against the very fallback this phase replaces.

Switching to the largest single part fixed it and improved every measure:

| Measure | union-of-parts | **largest part (shipped)** |
|---|---|---|
| Camera resolved | 7,898 (99.92 %) | **7,899 (99.94 %)** |
| Senato resolved | 7,901 (99.96 %) | **7,902 (99.97 %)** |
| Both-chambers nil | 2 (Isole Tremiti, Ponza) | **1 (Isole Tremiti)** |
| Camera accuracy vs `CU20_COD` | 99.97 % | **99.97 %** |
| Roma / Milano / Napoli / Palermo / Genova / Torino | Roma **nil** | **all 6 resolve** |

The residual honest limitation: for a comune split across several collegi
(which by definition has no single "correct" one), the point lands in the
collegio containing its **largest territorial part**. Stated in the importer
docstring, in `docs/DATA_SOURCES.md`, and in the integration test's own
comment — an inherent property of representing a multi-collegio comune by one
coordinate, not an error.

Both the probe and `tools/import_comuni.py` implement the identical method,
and the probe's candidate output is JSON-content-identical to the shipped
artifact:

```
$ diff <(python3 -c "import json;print(json.load(open('tools/probes/output/comuni_candidate.json')))") \
       <(python3 -c "import json;print(json.load(open('Politici/Data/comuni.json')))") && echo EQUAL
JSON-EQUAL (content identical)
```

---

## 5. Spot verification — the ≥10 pairs, verified *before* the tests hardcoded them

The phase requires "spot verification of ≥10 known comuni against their real
collegi from official sources, quoted in the report **before** the integration
tests hardcode them". Each pair below was produced by resolving the **shipped
`comuni.json` coordinate** against the **shipped collegi polygons** — the
exact runtime path — and every Camera result was independently cross-checked
against that comune's own `CU20_COD` in the ISTAT source (the ground truth
carried on each row), not against whatever the implementation happened to
return.

| Comune | lat, lon | Camera collegio | Camera name | Senato collegio |
|---|---|---|---|---|
| Roma | 41.71987, 12.40261 | `120105` | Lazio 1 - U05 | `S120004` |
| Milano | 45.41020, 9.22496 | `30108` | Lombardia 1 - U08 | `S30003` |
| Napoli | 40.85701, 14.16394 | `150102` | Campania 1 - U02 | `S150004` |
| Torino | 45.11047, 7.71843 | `10102` | Piemonte 1 - U02 | `S10001` |
| Firenze | 43.78082, 11.24465 | `90007` | Toscana - U07 | `S90004` |
| Bologna | 44.48824, 11.35968 | `80006` | Emilia-Romagna - U06 | `S80003` |
| Bari | 41.08672, 16.86863 | `160005` | Puglia - U05 | `S160003` |
| Genova | 44.45587, 8.70297 | `70002` | Liguria - U02 | `S70001` |
| Venezia | 45.40783, 12.31314 | `50101` | Veneto 1 - U01 | `S50001` |
| Aosta | 45.74995, 7.30600 | `20001` | Valle d'aosta/Vallée d'Aoste - U01 | `S20001` |
| Trento | 46.06482, 11.10819 | `40001` | Trentino-Alto Adige/Südtirol - U01 | `S40001` |
| Cagliari | 39.21992, 9.09387 | `200001` | Sardegna - U01 | `S200001` |
| Bolzano | 46.48752, 11.34264 | `40003` | Trentino-Alto Adige/Südtirol - U03 | `S40004` |
| Perugia | 43.13840, 12.43409 | `100002` | Umbria - U02 | `S100001` |

**14 pairs, ≥ 10 as required**, each resolving in **both** chambers. Five of
them (Roma, Milano, Napoli, Torino, Genova) are split comuni, so their result
is the largest-part collegio per §4 — noted in the test file itself so a
future reader is not misled into treating it as *the* collegio of the whole
comune. A 15th verified pair (Reggio di Calabria → `180005` / `S180002`) was
measured and is recorded here but not carried into the test.

---

## 6. What shipped

### Data + pipeline

| File | Change |
|---|---|
| `Politici/Data/comuni.json` | **new** generated artifact — 7,904 comuni, 581,849 B |
| `tools/import_comuni.py` | **new** — the importer (`make comuni`) |
| `tools/probes/probe_comuni_centroids.py` | **new** — committed GO-COMUNI probe |
| `Makefile` | `comuni` target added, and inserted into offline `all` |
| `tools/validate_data.py` | `validate_comuni()` + gate constants, wired into `main()` |
| `tools/make_manifest.py` | `istat-comuni-centroidi` source entry |
| `Politici/Data/sources.json` | regenerated — one new entry (§8) |

### App

| File | Change |
|---|---|
| `Politici/Models/Comune.swift` | **new** — `Comune` + `ComuniFile`; `id` = `"name\|province"` |
| `Politici/Services/ComuneService.swift` | **new** — `ComuneLookup` protocol + eager-loading service |
| `Politici/Utilities/NameFolding.swift` | **new** — the shared accent/case fold, reused by both lookups |
| `Politici/Services/GeocodingService.swift` | three-tier resolution + `AddressResolving` seam |
| `Politici/Services/ServiceContainer.swift` | `comuneService` injected |
| `Politici/Views/AddressSearchView.swift` | homonym disambiguation UI + copy refresh |

**The tier order** (`GeocodingService.geocode(address:)`):

1. **`CLGeocoder`** via `AddressResolving` — address-level; wins whenever
   available, so nothing regresses (gate condition (d)).
2. **The bundled comuni table** — exact comune-name match, fully offline.
3. **The five-city table — retained**, not removed. The phase file allowed
   removing it "unless the phase documents removing it"; it is kept because it
   is the only tier doing *substring* matching, so `"Roma Termini"` still
   resolves when tiers 1–2 both miss. Its five coordinates are curated points,
   deliberately independent of the comuni table.

**Homonym handling** is split between service and UI, as the phase specifies
("the lookup returns candidates; the UI disambiguates"):
`ComuneService.comuni(matching:)` returns **every** candidate, sorted
deterministically; `AddressSearchView` intercepts a >1-candidate result
*before* geocoding and renders a chooser — "Più comuni con questo nome /
Scegli la provincia:" — listing `Nome (Provincia)`. All copy is Italian
(constraint #2).

Lookup is **exact folded-name equality, not substring**: with 7,904 names a
substring rule would make `"Roma"` also match `"Romano di Lombardia"`. Pinned
by `testExactMatchIsWholeNameNotSubstring`.

### Data-visibility staleness (baseline rule 9 — declared scope)

- **`README.md` — updated.** The feature bullet claiming "an offline
  five-city fallback table" was made accurate (three tiers, 7,904 comuni,
  homonym disambiguation); the pipeline section gained `make comuni` and
  `comuni.json` as a generated artifact; the "Open (V4 candidates)" entry
  "Offline geocoding beyond the five-city fallback" is struck through and
  marked done.
- **`docs/DATA_SOURCES.md` — updated** (§8).
- **`AddressSearchView` copy — updated.** Two strings had been written for a
  five-city world: the chip header `"Città campione disponibili"` → `"Comuni
  di esempio"`, and the not-found message `"Indirizzo non coperto dal
  prototipo. Prova con una città campione come Roma, Milano o Torino."` →
  `"Nessun collegio elettorale trovato per questa posizione. Prova con il
  nome di un comune (es. Roma, Milano, Torino)."` — the old text told the user
  the prototype covers five cities, which is now false. The chips' *
  accessibility identifiers* were left unchanged, so
  `SmokeFlowUITests` (which asserts `addressSearch.city.Roma` exists) is
  unaffected.
- **`HomeView` "Come funziona l'elezione" — deliberately not touched.** It
  explains the electoral system (uninominale / plurinominale / Estero), not
  address resolution or geocoding coverage; nothing in it became inaccurate.
  Recorded per rule 9's "a *decision not to touch* one of them … is worth a
  line in the report."

---

## 7. Test specifications, one by one

**Spec 1 — manifest + provenance complete; licence verbatim; approval quoted.**
Met. `sources.json` carries `istat-comuni-centroidi` (CC BY 4.0,
`retrievedAt` 2026-07-18); `docs/DATA_SOURCES.md` gained a full section and
its cross-check trailer; `tools/SOURCES.md` and the gitignored
`tools/raw/SOURCES.txt` both updated in this commit; licence quoted verbatim
in §2(a); approval quoted verbatim in §1.

**Spec 2 — `comuni.json` within its documented measured gate; validator green.**
Met. Measured **581,849 B = 568.2 KiB**; gate
`MAX_COMUNI_FILE_BYTES = 768 * 1024` (**74.0 % of gate**, ~35 % headroom),
enforced in *both* `import_comuni.py` (fails loudly, writes nothing) and
`validate_data.py`. Validator exits 0:

```
OK: 7904 comuni in Politici/Data/comuni.json (568.2 KiB) — 6 nomi omonimi disambiguati per provincia
…
EXIT: 0
```

**Bundle-size gate re-measured against current reality**, as the Phase 29
handoff requires — not against this spec file's pre-Phase-25/27/28 estimate:

| | Bytes | MiB | % of 10 MiB soft ceiling |
|---|---:|---:|---:|
| Real `Data/` before Phase 30 | 5,768,651 | 5.50 | 55.0 % |
| **After** (`+581,849` comuni, `+826` sources) | **6,351,326** | **6.06** | **60.6 %** |

Comfortably inside the ceiling, with 3.94 MiB of headroom remaining. The
phase file's ~400–600 KB estimate was accurate (568.2 KiB) but was treated as
an estimate, not a limit, per its own instruction.

**Spec 3 — lookup unit tests.** Met — `PoliticiTests/ComuneLookupTests.swift`,
9 tests against the **real bundled table**: exact match; exact-not-substring;
accent/case-insensitive (`Châtillon` / `chatillon` / `CHATILLON`); bilingual
`"Bolzano/Bozen"`; German-only `"Bozen"` honestly empty; homonym `Castro` →
`[Bergamo, Lecce]` and `Livo` → `[Como, Trento]`; homonym candidates have
distinct coordinates; unknown and empty queries → `[]`.

**Spec 4 — integration tests on the probe-verified pairs.** Met —
`PoliticiTests/ComuneGeocodingIntegrationTests.swift`, 2 tests: the 14
verified pairs of §5 resolved end-to-end through `ComuneService` →
`DistrictService` for **both** chambers (with an explicit
`XCTAssertGreaterThanOrEqual(verifiedPairs.count, 10)`), plus the dual-chamber
`districts(containing:)` path the address search actually uses.

**Spec 5 — tier-order test.** Met — `PoliticiTests/GeocodingTierTests.swift`,
4 tests via injected fakes: tier 1 wins when present *even though tier 2 also
matches*; tier 2 used when tier 1 returns nil; **tier 3 five-city fallback
intact** (`"Roma Termini"`); throws only when all three miss. The final tier
was **retained**, so the "or its removal documented and tested" branch does
not apply.

**Spec 6 — suite green vs baseline plus documented additions.** Met.

```
** TEST SUCCEEDED **        (exit code 0)

  totalTestCount: 204
  passedTests: 204
  failedTests: 0
  skippedTests: 0
  result: Passed
```

Arithmetic, re-derived from source with the **occurrence rule** (never
`sort -u`, per `CLAUDE.md`):

| | Phase 29 baseline (at HEAD) | Phase 30 | Δ |
|---|---:|---:|---:|
| `PoliticiTests` `func test…(` | 177 | 192 | +15 |
| `PoliticiTests` `@Test` | 1 | 1 | 0 |
| `PoliticiUITests` `func test…(` | 11 | 11 | 0 |
| **Declared** | **189** | **204** | **+15** |

+15 = 9 (`ComuneLookupTests`) + 4 (`GeocodingTierTests`) + 2
(`ComuneGeocodingIntegrationTests`). **No existing test was modified or
removed** — the three new files are the entire delta, and `git status` shows
no test file as modified.

**Log-vs-`.xcresult` discrepancy, diagnosed not hand-waved.** The log shows
203 `passed` lines against `totalTestCount 204`. This is the documented
xcodebuild truncation, verified in the log body as `CLAUDE.md` requires:

```
915:Test case 'SmokeFlowUITests.testVotazioniListScopeLineTalliesAndSourceLink()' pa2026-07-27 09:05:47.351 xcodebuild[…] [MT] IDELaunchParametersSnapshot: …
```

The line is cut mid-word (`pa`…) by an interleaved xcodebuild diagnostic — the
test passed; only its log line was mangled. Authoritative signals (exit code
0, `failedTests 0`, `result Passed`) all agree. **No UI-test flake occurred
this run**, so no re-run was needed and the flake tally is unchanged.

---

## 8. Generated-data change protocol

Two generated files are touched. Both diffs were inspected in full.

**`Politici/Data/comuni.json` — new file**, 581,849 B, produced solely by
`tools/import_comuni.py`. (The probe's candidate output quoted in §2(c) reads
581,848 B: the importer terminates the file with a newline and the probe does
not — the JSON content is identical, as the `diff` in §4 shows.) Verified
**idempotent**: re-running the importer leaves it byte-identical, and does not
advance the fetch metadata.

```
$ shasum -a 256 Politici/Data/comuni.json     # before re-run
783a22b99c44e9073c2544e501591e1523556256aa842fdee59c1ab1ba580f75
$ python3 tools/import_comuni.py
OK: 7904 comuni … (568.2 KiB) — 6 nomi omonimi disambiguati per provincia
$ shasum -a 256 Politici/Data/comuni.json     # after
783a22b99c44e9073c2544e501591e1523556256aa842fdee59c1ab1ba580f75
$ python3 -c "…['istat']"
{'fetchedAt': '2026-07-18'}
```

**`Politici/Data/sources.json` — exactly two changes, both expected:**

```diff
-  "generatedAt": "2026-07-22",
+  "generatedAt": "2026-07-23",
@@
+    {
+      "id": "istat-comuni-centroidi",
+      "license": "CC BY 4.0",
+      "name": "ISTAT — Comuni (centroidi per la geocodifica offline)",
+      "notes": "Tabella dei 7.904 comuni italiani con un punto interno …",
+      "retrievedAt": "2026-07-18",
+      "url": "https://www.istat.it/notizia/le-basi-geografiche-dei-nuovi-collegi-elettorali-2"
+    },
```

1. `generatedAt` 2026-07-22 → 2026-07-23 — the date `make manifest` actually
   ran. Expected; it is defined as "when this file was last regenerated".
2. The single new source entry, whose `retrievedAt` is **2026-07-18** — read
   from the pre-existing shared `istat` fetch-metadata key, i.e. the real
   historical download date of the package, **not** today's. This is the
   `stamp_fetch_metadata_if_absent` behaviour `import_boundaries.py` already
   relies on, and is why no date silently advanced.

**No other entry changed in any field** — the nine pre-existing sources are
byte-identical, `schemaVersion` stays 2. Nothing unexpected, so nothing to
investigate or restore.

**Re-run rule (bundled data changed after a validating test run).** The only
post-test-run pipeline execution was the idempotency check above, which
produced a **byte-identical** `comuni.json` (same SHA-256) — the tree the
suite validated is the tree being committed, so no re-run is owed. `make
manifest` ran *before* the test run, not after. Additionally, and for the
record, a grep confirms no test depends on the manifest's mutable content —
only `schemaVersion == 2` and successful load:

```
PoliticiTests/SchemaV2Tests.swift:464:        XCTAssertEqual(manifest.schemaVersion, 2)
PoliticiTests/SchemaV2Tests.swift:471:        XCTAssertEqual(service.manifest?.schemaVersion, 2)
```

**`make manifest` fresh-checkout caveat.** `tools/raw/.fetch_metadata.json`
was confirmed present and holding the real committed fetch dates *before*
running `make manifest`, so the `date.today()` fallback that would rewrite
every `retrievedAt` was never reachable. Confirmed by the diff above: all
nine existing `retrievedAt` values unchanged.

---

## 9. Acceptance criteria

| # | Criterion | Outcome |
|---|---|---|
| 1 | Manifest + provenance entries complete; licence verbatim; acquisition approval quoted | **Met** — §1 (approval verbatim), §2(a) (licence verbatim), §8; `sources.json` + `DATA_SOURCES.md` + `tools/SOURCES.md` + `tools/raw/SOURCES.txt` all synced in this commit |
| 2 | `comuni.json` within its documented measured gate; validator green | **Met** — 581,849 B vs a 768 KiB gate (74.0 %), enforced at import *and* in the validator; `make validate` exits 0; bundle re-measured 5.50 → 6.06 MiB (60.6 % of ceiling) |
| 3 | Lookup unit tests: exact, accent-insensitive, bilingual, homonym, unknown | **Met** — 9 tests, §7 |
| 4 | Integration tests: the ≥10 probe-verified comune → collegio pairs | **Met** — 14 pairs, verified in §5 before being hardcoded, both chambers |
| 5 | Tier-order test: CLGeocoder preferred; comuni table on failure; final fallback intact | **Met** — 4 tests; final tier **retained** (documented, §6) |
| 6 | Suite green vs baseline plus documented additions | **Met** — 189 → **204**, 0 failures, `** TEST SUCCEEDED **` |
| — | GO-COMUNI gate (a)–(d) | **GO** — §2, each condition on quoted evidence |

### Deviations, stated honestly

1. **"Bilingual names match either side of the `/`" could not be implemented
   as literally written** — the ISTAT source carries **zero** comune names
   containing a slash (§3). Implemented on the query side instead (a `"X/Y"`
   query matches via either side); a German-only exonym honestly returns no
   match rather than being fabricated. Constraint #4 governs; the phase file's
   assumption about the data was wrong and reality wins (plan-wide rule 7).
2. **The acquisition was user-gated but resolved to "no acquisition"** — the
   phase anticipated a manual download; the product was already local inside
   an already-attributed package. The gate was still run, presented, and
   approved verbatim (§1) rather than skipped as a formality.
3. **The centroid method changed mid-phase** (union → largest part) after the
   dry run showed Roma resolving to nil. Both the superseded and the shipped
   measurements are published (§4) rather than only the final ones — including
   the fact that the figures quoted in the user's approval text were the
   earlier pass.
4. **2 comuni resolve to a neighbouring collegio** and **1 comune (Isole
   Tremiti) resolves to none**, both consequences of the 1000 m boundary
   simplification. Disclosed, not snapped or hand-patched (§2(c)).

No other deviation. Nothing under `docs/v2/`, `docs/v3/`, or `docs/history/`
was edited.

---

## 10. Post-Phase-30 bundle figure (for Phases 32A/32B)

Recorded as a standalone, current figure so later phases quote a measured
number rather than one from a spec predating Phases 25/27/28/30. Real
(non-`*.sample.*`) `Politici/Data/` **immediately after Phase 30**:

| File | Bytes |
|---|---:|
| `votes.json` | 1,767,926 |
| `districts.geojson` | 1,158,457 |
| `districts_senato.geojson` | 867,362 |
| `districts_plurinominali_camera.geojson` | 766,581 |
| `districts_plurinominali_senato.geojson` | 608,842 |
| **`comuni.json`** | **581,849** |
| `representatives.json` | 482,770 |
| `memberships_camera.json` | 108,917 |
| `sources.json` | 7,002 |
| `parties.json` | 1,620 |
| **TOTAL real** | **6,351,326 B = 6.06 MiB = 60.6 % of the ~10 MiB soft ceiling** |

The three `*.sample.*` test fixtures add a further 13,179 B on disk and in the
bundle (Phase 23 §7 item 1 — deliberately retained). Headroom remaining
against the soft ceiling: **3.94 MiB**.

---

## 11. Open decision (raised by review) — source assignment vs geometric resolution

> **Status: awaiting the user's decision. Nothing was changed for this.** The
> analysis below is read-only measurement against the committed tree; no data,
> pipeline or app behaviour was modified.

### 11.1 Does the source carry its own comune → collegio assignment? **Yes.**

The review asked whether §2(c)'s phrasing — "99.97 % of hits match the
collegio the source itself assigns" — implies `UT_Collegi2020` carries an
authoritative assignment. **It does, and the phrasing was literally accurate.**
The fields:

| Field | Meaning |
|---|---|
| `CU20_COD` / `CU20_DEN` / `CU20_C1` | **Camera uninominale** collegio: code, name, sub-code |
| `SU20_COD` / `SU20_DEN` / `SU20_C1` | **Senato uninominale** collegio |
| `CP20_COD` / `CP20_DEN` / `CP20_C1` | Camera plurinominale collegio |
| `SP20_COD` / `SP20_DEN` / `SP20_C1` | Senato plurinominale collegio |
| `CIRC_COD` / `CIRC_DEN` | Camera circoscrizione |

Sample row (Firenze, `PRO_COM = 48017`):

```
$ ogrinfo -ro -al -geom=NO … -where "PRO_COM = 48017"
  DEN_P_CM (String) = Firenze
  PRO_COM (Integer64) = 48017
  DEN_COM (String) = Firenze
  CU20_COD (Integer64) = 90007          CU20_DEN (String) = Toscana - U07
  SU20_COD (Integer64) = 90004          SU20_DEN (String) = Toscana - U04
  CP20_COD (Integer64) = 90003          CP20_DEN (String) = Toscana - P03
  SP20_COD (Integer64) = 90001          SP20_DEN (String) = Toscana - P01
```

**The 99.97 % figure was comparing the geometric result against exactly this
field** (`CU20_COD`) — i.e. Phase 30 already held the publisher's own answer
and used it only to *grade* the geometry, never to *be* the answer.

Coverage and integrity, measured across all 7,904 comuni:

```
with >=1 CU20_COD: 7904        with NO CU20_COD: 0
with >=1 SU20_COD: 7904        with NO SU20_COD: 0
distinct source CU codes: 147; shipped Camera ids: 147; source codes NOT shipped: []
distinct source SU codes:  74; shipped Senato ids:  74; source codes NOT shipped: []
```

**100 % populated, and referentially exact** — every source code is already a
shipped district id, requiring no translation.

### 11.2 Why does the lookup resolve geometrically? Partly specified, partly artefact

Honestly, both — and only the first was recorded:

- **Specified.** `docs/plan/phase-30.md` defines the deliverable as "a bundled
  table of all Italian comuni (~7,900) **with centroid coordinates**, so any
  comune name resolves offline to a coordinate **→ collegio via the existing
  point-in-polygon path**". The centroid→PIP design is the phase's own wording,
  and the implementation followed it.
- **Artefact.** No design note anywhere — not in the report, the importer, or
  the service — records the alternative ("read `CU20_COD` directly") being
  considered and rejected. It was not weighed. I used the field as a
  verification oracle without asking whether it should be the primary answer.
  **There is no deliberate, recorded decision to prefer geometry**; there is a
  spec that said "geometry" and an implementation that complied.

### 11.3 What would change

Measured by resolving every shipped `comuni.json` centroid against the shipped
polygons and comparing to that comune's source assignment:

| | Camera | Senato |
|---|---:|---:|
| Geometry agrees with source | 7,897 (99.911 %) | 7,900 (99.949 %) |
| Geometry **differs** | **2** | **2** |
| Geometry returns **nil**, source has an answer | **5** | **2** |
| **Comuni whose answer would change** | **7 (0.089 %)** | **4 (0.051 %)** |

**Both named mismatches become correct** — by construction, since they would
read their own source row:

```
Carbonara di Nola (Napoli): geometry=150204  source=150106
Torre de' Roveri (Bergamo): geometry=30302   source=30301
```

**`Isole Tremiti` gains an answer** rather than staying a gap: the source
assigns it Camera `160002` and Senato `S160001`, both real shipped ids. So do
four further Camera gaps this report had only counted, never named:

```
Correzzana (Monza e della Brianza) -> 30102
Pognana Lario (Como)               -> 30203
Porto Recanati (Macerata)          -> 110002
Ronzone (Trento)                   -> 40001
Tropea (Vibo Valentia)             -> S180002   (Senato)
```

**The reviewer's framing is correct on the key point:** this is *citing the
publisher*, not snapping. Snapping invents a nearest-neighbour answer the
source never stated; reading `CU20_COD` reproduces what ISTAT actually
published for that comune. The "disclose over snap" reasoning in §2(c) was
sound **for the choice it was actually facing** (geometry-nil → invent a
neighbour), but it never considered the third option of not needing geometry
at all for name lookups.

### 11.4 The finding the review did not anticipate — and it is larger

The 7 changed Camera comuni total **20,375 residents (0.034 % of Italy)**. But
the same silent-confidence critique applies far more widely, to a case Phase 30
shipped without flagging as a *correctness* issue:

```
population in the 6 multi-collegio comuni: 6,937,409 (11.67% of Italy)
   Roma     pop=2,617,175  spans 7 Camera collegi
   Milano   pop=1,242,123  spans 3
   Napoli   pop=  962,003  spans 2
   Torino   pop=  872,367  spans 2
   Palermo  pop=  657,561  spans 2
   Genova   pop=  586,180  spans 2
```

For these six the source assignment is **legitimately multi-valued** — Roma
genuinely spans seven Camera collegi — so "the source's answer" is a *set*, not
a value. Today a user typing "Roma" is shown **one** collegio (`120105`, Lazio
1 - U05, the largest-part result) with exactly the same confidence as a user
typing "Firenze", for whom the answer is genuinely unique. That is the same
silent-failure shape as `Carbonara di Nola`, but affecting **340× more people**
(6.94 M vs 20 k) — and unlike the two mismatches it is not a simplification
artefact that better geometry would fix; it is intrinsic to answering a
whole-comune question with a single collegio.

This *strengthens* the case for change while reframing it: the main prize is
not fixing 2 wrong answers, it is being able to say "Roma spans 7 collegi —
which part?" using the same disambiguation UI Phase 30 already built for
homonyms.

### 11.5 Cost

Carrying the assignment enlarges `comuni.json`. Both variants measured:

| Schema | Bytes | KiB | vs current 768 KiB gate | `Data/` total |
|---|---:|---:|---:|---:|
| Current (v1, coordinates only) | 581,849 | 568.2 | 74.0 % | 6.06 MiB |
| **A** — always-array `camera`/`senato` | 896,739 | 875.7 | **114.0 %** | 6.36 MiB |
| **B** — scalar when single-valued, array only for the 6/3 multi, short keys | 786,101 | 767.7 | **100.0 %** | 6.25 MiB |

Either variant **requires raising `MAX_COMUNI_FILE_BYTES`** (B clears the
current gate by ~300 bytes, which is not headroom — it defeats the point of a
drift backstop). ~1 MiB would be the honest new gate. Both stay far inside the
~10 MiB soft ceiling.

**Coordinates must stay regardless.** `lat`/`lon` are not replaceable by the
assignment: `CLGeocoder` returns a *coordinate* for street addresses, map taps
produce coordinates, and arbitrary-point → collegio still needs
point-in-polygon. The assignment would serve the **comune-name lookup path
only**.

### 11.6 Recommendation

**Adopt the source assignment as the primary answer for comune-name lookups,
with geometry retained for every coordinate-based path — but as its own scoped
change, not a patch to this commit.** Reasoning:

1. It replaces a derived value with a published one, for 100 % of comuni, with
   zero referential slack (147/147, 74/74).
2. It removes boundary-simplification artefacts from the name path entirely —
   the 2 mismatches and all 7 gaps, not case-by-case.
3. It makes the 6 multi-collegio comuni answerable **honestly**, reusing the
   existing homonym chooser — the largest single integrity gain, by population.
4. It is consistent with how this project already treats sourced-vs-derived
   values everywhere else (`CLAUDE.md` #4).

Against, stated fairly: it is a behaviour change for every comune query, it
grows shipped data ~35 % (variant B) and needs the byte gate raised, it
requires a `schemaVersion` bump with importer/validator/model/service/test
changes, and the 14 hardcoded integration pairs in §5 would need re-derivation
for the split comuni (whose single expected id stops being the right
assertion). None of that is an argument against correctness; it is an argument
for doing it deliberately in its own phase with its own test pass.

**Concretely:** a lettered sub-phase (**30B**) is the established shape for a
user-gated insert of exactly this size (precedents: 13B, 15b). It should also
settle the multi-collegio UI question explicitly rather than inheriting the
largest-part default. **Recommended, not decided — this is the user's call.**

The measurement script used here was run read-only from the session scratchpad
and is deliberately **not** committed: adding a probe for a decision not yet
taken would presume the outcome. If the decision is to proceed, 30B commits it
under `tools/probes/` per the probes convention; if not, the numbers above are
the durable record.

---

## 12. Flow-7 / `CLGeocoder` question (open since Phase 24) — answered

[`docs/v4/24-ui-tests.md`](24-ui-tests.md) §6.3 and §9 recorded UI flow 7's
**300 s wait ceiling** as latent debt: `GeocodingService` attempts `CLGeocoder`
before its offline table, and that attempt was measured once at ~1 s and once
at **>120 s**. Phase 24's stated blocker:

> "making the fallback deterministic would require a second app seam, which
> the phase does not permit… If a later phase adds a geocoding seam, this
> ceiling should come back down."

**Phase 30 added exactly that seam.** `AddressResolving` (§6) factors the
`CLGeocoder` tier behind a protocol with `CLGeocoderResolver` as the production
implementation, injectable via `GeocodingService(primary:comuni:)`. It is
already exercised by `GeocodingTierTests`' fakes.

**Can the `CLGeocoder` attempt be dropped?** **No — and it must not be.** The
comuni table resolves **comune names only** (7,904 exact names). A street
address (`"Via del Corso 12, Roma"`) has no offline resolution path at all;
`CLGeocoder`/`MKLocalSearch` remains the only way to answer it. Dropping tier 1
would regress address-level search — precisely what GO-COMUNI condition (d)
forbids.

**Can it be bounded? Yes, and Phase 30 is what makes that safe.** Two levers
now exist that did not in Phase 24:

1. **Test-side:** inject a deterministic `AddressResolving` into flow 7,
   removing the network wait from the test entirely and letting the 300 s
   ceiling drop to a normal one. This is the seam Phase 24 asked for, and it
   needs **no production behaviour change at all** — the lowest-risk half.
2. **Production-side:** put a timeout (a few seconds) on the tier-1 attempt.
   This was unattractive before Phase 30 because timing out dropped the user to
   a five-city table; now it drops them to ~7,900 comuni, so a bounded tier 1
   degrades to a genuinely useful answer instead of a near-empty one.

**What is still missing** (so this is not read as fully solved): street-address
resolution has no offline path and never will under local-first — a bounded
tier 1 means a slow network yields a *comune-level* answer where an
*address-level* one was possible. That is a deliberate UX trade needing a
decision, not a pure win, and it is why lever 1 (test-only) and lever 2
(production) should be decided separately.

**Scope recommendation — a later phase, not this follow-up.** This one is
docs-only by the user's framing; both levers change app or test code and
require a suite run plus a re-measured flow-7 duration. **Phase 32A** is the
natural home: it already owns Phase 24's deferred UI/a11y inventory, it already
lists the "comuni disambiguation UI" in its a11y pass, and a 300 s ceiling is a
release-readiness issue. Phase 31 (staleness / live-refresh ADR) is unrelated.
**Recommended, not decided.**

---

## 13. Diff scope for the Phase 30 commit (`0e76a75`)

```
Politici/Data/comuni.json                          (new — generated artifact)
Politici/Data/sources.json                         (regenerated — 1 new entry)
Politici/Models/Comune.swift                       (new)
Politici/Services/ComuneService.swift              (new)
Politici/Utilities/NameFolding.swift               (new)
Politici/Services/GeocodingService.swift           (three-tier resolution)
Politici/Services/ServiceContainer.swift           (comuneService injected)
Politici/Views/AddressSearchView.swift             (homonym UI + copy refresh)
PoliticiTests/ComuneLookupTests.swift              (new — 9)
PoliticiTests/GeocodingTierTests.swift             (new — 4)
PoliticiTests/ComuneGeocodingIntegrationTests.swift(new — 2)
tools/import_comuni.py                             (new)
tools/probes/probe_comuni_centroids.py             (new — committed probe)
tools/validate_data.py                             (validate_comuni)
tools/make_manifest.py                             (new source entry)
tools/SOURCES.md                                   (ISTAT notes)
Makefile                                           (comuni target, into all)
README.md                                          (rule 9 staleness)
docs/DATA_SOURCES.md                               (new section + cross-check)
docs/v4/30-comuni-geocoding.md                     (new — this report)
docs/plan/README.md                                (Phase 30 status: pending -> done)
docs/plan/00-baseline-and-rules.md                 (Q5 marked RESOLVED)
```

`tools/raw/SOURCES.txt` was also updated to match `tools/SOURCES.md`, but is
gitignored (working-cache copy) and so does not appear in the diff.
`tools/probes/output/` is gitignored and is never an import source.

Remote actions are the user's. Not run here:

```
git push origin v4
```

---

## 14. Review follow-up (separate commit, `docs(v4): phase 30 review follow-ups`)

Sections 10–12, the §1 approval-scope note, and the entries listed below were
added by a scoped review follow-up after `0e76a75`. It is a **separate commit,
deliberately not an amend** — Phase 30 may already have been pushed, matching
the `17cc2a7` precedent for Phase 29's follow-ups.

| File | Change |
|---|---|
| `docs/v4/30-comuni-geocoding.md` | §1 approval-scope line; §10 bundle figure; §11 open decision; §12 flow-7 answer; this section |
| `docs/plan/00-baseline-and-rules.md` | new plan-wide **rule 10** (approval scope); two deferred-list entries (bilingual comune names; the open decision) |
| `CLAUDE.md` | log-truncation tally — fourth sighting recorded, with the v4 variant's distinguishing detail |

**No suite re-run was performed, and none is owed.** `CLAUDE.md`'s re-run rule
is scoped to *"changes to a bundled data file (anything under
`Politici/Data/`)"* made after a validating run. This follow-up touches **only
Markdown** — no file under `Politici/`, no file under `tools/`, no generated
artifact, no test source. The Phase 30 run therefore still certifies the tree:
**`totalTestCount 204`, `passedTests 204`, `failedTests 0`**, and the declared
count is unchanged at **204** (stated for reference, deliberately not
re-derived from source, since nothing here can change it).

Working tree was clean before and after; nothing was pushed or tagged.
