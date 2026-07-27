# V4 Phase 30B — Comuni Resolve via the Published Collegio Assignment

Phase 30 answered a comune-name query **geometrically** — interior point →
point-in-polygon against the shipped, 1000 m-simplified collegi — and used
ISTAT's own `CU20_COD`/`SU20_COD` only to *grade* that answer. This phase
inverts it: for a **name** query the app now cites what the publisher
actually published, and geometry is retained for the **coordinate** path
alone. Doing so makes a second, larger thing expressible — that **Roma spans
seven Camera collegi** and cannot honestly be answered with one.

**GO-ASSIGN: GO** on all five conditions, on the evidence in §2. Every number
below was measured in-session on **2026-07-27** against the actual repository
state.

**Network acts: none. New downloads: none. No fetch metadata advanced.** The
assignment fields were already local, inside the ISTAT collegi package this
project has downloaded, documented and attributed since v2 — Phase 30's
headline finding. `tools/raw/.fetch_metadata.json`'s `istat` key still reads
its real historical value:

```
$ python3 -c "import json;print(json.load(open('tools/raw/.fetch_metadata.json'))['istat'])"
{'fetchedAt': '2026-07-18'}
```

---

## 1. What this phase decides, and on whose authority

[`docs/v4/30-comuni-geocoding.md`](30-comuni-geocoding.md) §11 raised this as
an **open user decision** and explicitly did not take it ("Recommended, not
decided — this is the user's call"), and
[`docs/plan/00-baseline-and-rules.md`](../plan/00-baseline-and-rules.md)'s
deferred list recorded it as "**Not deferred by choice; awaiting the user's
decision**". The user's decision is the existence of
[`docs/plan/phase-30b.md`](../plan/phase-30b.md) itself — a commissioned,
lettered sub-phase whose objectives are exactly the recommendation. This
report acts on that, and the deferred-list entry is marked RESOLVED in the
same commit.

**No user gate was reached in this phase.** There is no network act, no
acquisition, no licence question and no new source: the same
`UT_Collegi2020` layer, the same D.Lgs. 177/2020 release, the same CC BY 4.0
already verified and recorded in `tools/SOURCES.md` and `docs/DATA_SOURCES.md`.
Nothing needed approval, so nothing was asked and nothing is quoted here —
recorded explicitly so a reader does not look for a missing approval block.

---

## 2. The GO-ASSIGN gate, condition by condition

Committed probe:
[`tools/probes/probe_comuni_assignment.py`](../../tools/probes/probe_comuni_assignment.py),
run **before** any importer change (validation strategy). It reads the raw
`UT_Collegi2020` attributes for the "after" and the **shipped**
`Politici/Data/comuni.json` coordinates resolved against the **shipped**
collegi polygons for the "before" — i.e. literally what the app answered on
2026-07-26. Offline; `tools/probes/output/` is gitignored and is never an
import source.

### (a) Field coverage — re-measured, not inherited

```
--- (a) field coverage ---
rows in layer               : 8213
rows with NO CU20_COD       : 0
rows with NO SU20_COD       : 0
comuni with NO Camera code  : 0  []
comuni with NO Senato code  : 0  []
(a) VERDICT                 : PASS
```

Measured on **rows** as well as comuni, because the condition names an
unpopulated *row* as NO-GO and a comune can carry up to 155 of them. Zero on
both counts. **Condition (a): PASS.**

### (b) Referential integrity — exact, both chambers

```
--- (b) referential integrity (published code -> shipped district id) ---
distinct published Camera codes : 147   shipped Camera ids: 147
  published codes NOT shipped   : []
  shipped ids never published   : []
distinct published Senato codes : 74   shipped Senato ids: 74
  published codes NOT shipped   : []
  shipped ids never published   : []
(b) VERDICT                     : PASS
```

Both directions are checked, not just the one the condition asks for: no
published code is unresolvable **and** no shipped collegio is unassigned. No
alias was added, and none was needed — after the project's unconditional
`"S"` prefix for Senato ids (a v3 convention, applied at import), the
publisher's codes *are* the shipped ids. **Condition (b): PASS.**

### (c) The multi-collegio set — enumerated, with the population field's vintage stated

```
--- (c) multi-collegio comuni (POP_2011 = ISTAT CENSUS-2011 field, NOT current) ---
national POP_2011 total (sum over all rows) : 59433744
comuni spanning >1 Camera uninominale       : 6
comuni spanning >1 Senato uninominale       : 3
comuni multi in EITHER chamber              : 6
population in those comuni                  : 6937409  (11.67% of national POP_2011)
    Roma       (Roma                  ) pop=  2617175  rows= 155  Camera x7 ['120101', '120102', '120103', '120104', '120105', '120106', '120107']  Senato x3 ['S120002', 'S120003', 'S120004']
    Milano     (Milano                ) pop=  1242123  rows=  88  Camera x3 ['30107', '30108', '30109']  Senato x2 ['S30003', 'S30004']
    Napoli     (Napoli                ) pop=   962003  rows=  30  Camera x2 ['150102', '150103']  Senato x1 ['S150004']
    Torino     (Torino                ) pop=   872367  rows=   8  Camera x2 ['10101', '10102']  Senato x1 ['S10001']
    Palermo    (Palermo               ) pop=   657561  rows=  25  Camera x2 ['190101', '190102']  Senato x1 ['S190001']
    Genova     (Genova                ) pop=   586180  rows=   9  Camera x2 ['70002', '70003']  Senato x2 ['S70001', 'S70002']
```

**The set and the arithmetic reconfirm Phase 30 §11.4 exactly**: the same six
comuni, the same 6,937,409 residents, the same 11.67 %.

**Vintage, stated as the condition requires:** `POP_2011` is ISTAT's
**census-2011** population field carried on this layer — the same field
Phase 25 used for placeholder detection. It is **not** a current figure. Its
national sum, 59,433,744, is the 2011 census total, which is a useful
independent check that the per-row sums are being read correctly. The
percentage is therefore "11.67 % of Italy *as of the 2011 census*", and is
used here only to size the problem, never displayed in the app.

**Every multiplicity is expressible**, so the condition's "stop and document"
branch does not apply: the largest is Roma's 7 Camera collegi, and the UI
renders an arbitrary-length list (§4). Senato multiplicity is a subset — 3
comuni, max 3 collegi.

### (d) Byte maxima — measured before committing to ship

Measured on the pre-change tree (schemaVersion 1 shipped, 581,849 B):

```
--- (d) candidate-schema byte measurements ---
current shipped comuni.json (schemaVersion 1) : 581849 B = 568.2 KiB
  variant A:    896739 B =   875.7 KiB  (+ 54.1% vs current)  — always-array camera/senato codes, explicit keys
  variant B:    707061 B =   690.5 KiB  (+ 21.5% vs current)  — scalar-when-single, short keys (report §11.5 variant B)
  variant C:   2186765 B =  2135.5 KiB  (+275.8% vs current)  — A + _DEN names + plurinominale + circoscrizione
  variant D:    817699 B =   798.5 KiB  (+ 40.5% vs current)  — always-array codes, short keys c/s
```

**Shipped: variant A**, and the reasoning is the condition's own fallback
clause rather than preference.

* The phase file's deliverable wording is `CU20_COD`/`SU20_COD` "**with
  `_DEN`, plurinominale and circoscrizione fields**" — that is **variant C**,
  measured at **+275.8 %**, four times the ~35 % the condition projected.
  That is "materially worse than projected", so the condition's documented
  fallback — "a leaner schema (codes without redundant `_DEN` strings)" —
  applies. **Variant A is precisely that fallback**: the same assignment,
  without the `_DEN` strings, which are pure redundancy (the app already
  resolves an id to a `District` carrying its own name, and a second copy
  could only ever disagree with the first) and without the plurinominale and
  circoscrizione fields, which nothing in this phase's deliverables or test
  specs consumes. This is the documented trim the condition asks for, not a
  silent one.
* Variants B and D buy 190 KB / 79 KB with, respectively, a scalar-or-array
  union type the Swift decoder would have to branch on (a new quiet-failure
  surface in the one phase whose stated primary risk is "a version mismatch
  that degrades quietly") and single-letter keys in a human-readable
  generated artifact. Both were measured, and both are recorded here so the
  trade is visible rather than assumed away.
* **A discrepancy worth stating:** Phase 30 §11.5 quoted variant B at
  **786,101 B**; the variant B reconstructed here from that description
  measures **707,061 B**. The two cannot be reconciled — §11.5's measuring
  script was deliberately not committed ("adding a probe for a decision not
  yet taken would presume the outcome"), so the exact schema behind its
  figure is unrecoverable. §11.5's **variant A figure of 896,739 B, however,
  reproduces to the byte**, and is also byte-for-byte what the importer
  actually wrote (§7), so the number the decision rests on is confirmed from
  two independent directions.

**The new gate: `MAX_COMUNI_FILE_BYTES = 1280 * 1024` (1.25 MiB).**

| | Bytes | KiB | % of gate |
|---|---:|---:|---:|
| Shipped `comuni.json` (schemaVersion 2) | **896,739** | **875.7** | **68.4 %** |
| Gate | 1,310,720 | 1,280.0 | — |
| Headroom | 413,981 | 404.3 | 31.6 % |

Enforced in **both** `import_comuni.py` (fails loudly, writes nothing) and
`validate_data.py`. 1.25 MiB rather than the ~1 MiB the phase file projected:
at the measured size a 1 MiB gate would sit at 85.5 %, out of family with the
project's other coarse drift backstops (`comuni` v1 at 74.0 %, memberships at
41.6 %). The gate exists to catch a schema/regeneration accident, and 31.6 %
headroom keeps it doing that job at the same coarseness as its siblings.

**`Data/` total, re-measured (not projected):**

| | Bytes | MiB | % of 10 MiB soft ceiling |
|---|---:|---:|---:|
| Real `Data/` after Phase 30 | 6,351,326 | 6.06 | 60.6 % |
| **After Phase 30B** (`+314,890` comuni, `+335` sources) | **6,666,551** | **6.36** | **63.6 %** |

Headroom remaining: **3.64 MiB**. §8 carries the per-file table for 32A/32B.
**Condition (d): PASS.**

### (e) The resolution diff — enumerated comune by comune

```
--- (e) resolution diff, comune by comune ---

  CAMERA: unchanged 7891/7904   changed 13
    Carbonara di Nola      (Napoli                ) before=150204    after=['150106']   [CORRECTED]
    Correzzana             (Monza e della Brianza ) before=None      after=['30102']   [GAP-FILLED]
    Genova                 (Genova                ) before=70002     after=['70002', '70003']   [MULTI (single answer -> set)]
    Isole Tremiti          (Foggia                ) before=None      after=['160002']   [GAP-FILLED]
    Milano                 (Milano                ) before=30108     after=['30107', '30108', '30109']   [MULTI (single answer -> set)]
    Napoli                 (Napoli                ) before=150102    after=['150102', '150103']   [MULTI (single answer -> set)]
    Palermo                (Palermo               ) before=190101    after=['190101', '190102']   [MULTI (single answer -> set)]
    Pognana Lario          (Como                  ) before=None      after=['30203']   [GAP-FILLED]
    Porto Recanati         (Macerata              ) before=None      after=['110002']   [GAP-FILLED]
    Roma                   (Roma                  ) before=120105    after=['120101', '120102', '120103', '120104', '120105', '120106', '120107']   [MULTI (single answer -> set)]
    Ronzone                (Trento                ) before=None      after=['40001']   [GAP-FILLED]
    Torino                 (Torino                ) before=10102     after=['10101', '10102']   [MULTI (single answer -> set)]
    Torre de' Roveri       (Bergamo               ) before=30302     after=['30301']   [CORRECTED]

  SENATO: unchanged 7897/7904   changed 7
    Carbonara di Nola      (Napoli                ) before=S150002   after=['S150007']   [CORRECTED]
    Genova                 (Genova                ) before=S70001    after=['S70001', 'S70002']   [MULTI (single answer -> set)]
    Isole Tremiti          (Foggia                ) before=None      after=['S160001']   [GAP-FILLED]
    Milano                 (Milano                ) before=S30003    after=['S30003', 'S30004']   [MULTI (single answer -> set)]
    Pieve di Cento         (Bologna               ) before=S80004    after=['S80003']   [CORRECTED]
    Roma                   (Roma                  ) before=S120004   after=['S120002', 'S120003', 'S120004']   [MULTI (single answer -> set)]
    Tropea                 (Vibo Valentia         ) before=None      after=['S180002']   [GAP-FILLED]
```

**13 Camera and 7 Senato changes, against the phase file's "7 on the Camera
side and 4 on the Senato side". The difference is fully explained, and it is
a counting definition, not a surprise:**

| | Camera | Senato |
|---|---:|---:|
| `CORRECTED` — geometry answered a **neighbouring** collegio | 2 | 2 |
| `GAP-FILLED` — geometry answered **nothing**, the source has an answer | 5 | 2 |
| **Sub-total — the phase file's expected figure** | **7** | **4** |
| `MULTI` — a **single** answer becomes the published **set** | 6 | 3 |
| **Total changed** | **13** | **7** |

Phase 30 §11.3, the source of the "7 / 4" figures, counted a comune as
*agreeing* whenever the geometric answer was a **member of** the published
set — so all six multi-collegio comuni were on the "agrees" side there.
This probe counts them as changed because the **answer the user is shown**
changes from one collegio to all of them, which is this phase's headline
deliverable, not an unexplained divergence. `MULTI` is exactly the (c) set:
6 Camera, 3 Senato, same comuni, same order of magnitude. **There is no
change outside those four categories, and no comune changed that neither
§11.3 nor (c) predicted. Condition (e): PASS.**

Two details the earlier report had left unnamed, now on record: the **Senato**
side's two corrections are `Carbonara di Nola` (S150002 → S150007) and
**`Pieve di Cento`** (S80004 → S80003) — §11.3 counted two Senato mismatches
but named neither. And `Torre de' Roveri`'s wrong geometric answer, `30302`,
is *Castro (Bergamo)*'s own collegio — a neat illustration that these are
displacements across a simplified border, not random.

**GO-ASSIGN: GO on all five conditions.**

---

## 3. What ships in `comuni.json` (schemaVersion 2)

```json
{"name":"Roma","province":"Roma","lat":41.71987,"lon":12.40261,
 "camera":["120101","120102","120103","120104","120105","120106","120107"],
 "senato":["S120002","S120003","S120004"]}
```

* `camera` / `senato` — **always arrays**, including for the 7,898
  single-collegio comuni, so the app never decodes a scalar-or-array union.
  Sorted; Senato codes `"S"`-prefixed to match the shipped district ids.
  Never empty: the importer refuses to write a comune without a published
  assignment rather than emitting an empty array the UI would render as
  "not covered" — a wrong answer wearing an honest one's clothes.
* `lat` / `lon` — **unchanged, byte for byte**, from Phase 30 (§7). They are
  not replaceable by the assignment: `CLGeocoder` returns a *coordinate* for
  a street address, map taps produce coordinates, and arbitrary-point →
  collegio still needs point-in-polygon.

---

## 4. The two paths, and the multi-collegio decision

`AddressSearchView.search()` now routes a submission down one of two paths:

| Query | Path | Answer |
|---|---|---|
| an exact comune name (`"Roma"`, `"Bolzano/Bozen"`) | **published assignment** | every collegio ISTAT assigns that comune, per chamber |
| a homonym name (`"Castro"`) | chooser first, then the above | the chosen province's comune |
| anything else (`"Via del Corso 12, Roma"`, `"Roma Termini"`) | **coordinate** — unchanged | at most one collegio per chamber, by point-in-polygon |

**The multi-collegio UI: the "honest all-of-these label", not the chooser.**
The phase file allows either ("route through the homonym chooser … *or*
render with an honest all-of-these label"). The chooser was rejected on a
substantive ground, not an effort one: a homonym chooser asks a question the
user can answer — *which* `Castro` did you mean, Bergamo's or Lecce's? — while
a Roma chooser would ask which of `Lazio 1 - U01 … U07` they live in, which
is precisely what they came to find out. Presenting seven equivalent options
as a choice would push the app's uncertainty onto the user dressed as their
decision. So all seven are listed under copy that says the comune is divided
between them, with the one thing that *can* narrow it offered explicitly:
search a full address.

`ChamberResultGroup` renders **one, many, or none** per chamber. Pinned UI
strings, all Italian (constraint #2):

| Surface | String |
|---|---|
| Section title (any chamber multi-valued) | `"Collegi trovati"` — otherwise the existing `"Collegio trovato"` |
| Provenance caption, name path | `"Assegnazione del comune ai collegi pubblicata da ISTAT (basi geografiche dei collegi 2020)."` |
| Provenance caption, coordinate path | `"Collegio determinato dalla posizione geografica trovata."` |
| Multi-collegio group header | `"Collegi Camera: 7"` / `"Collegi Senato: 3"` |
| Multi-collegio explanation | `"Questo comune è diviso tra 7 collegi uninominali della Camera: sono elencati tutti. Cerca un indirizzo completo per sapere quale ti riguarda."` |
| No collegio for this chamber | `"Collegio Camera: non coperto dal prototipo per questa camera."` |
| Comune with no resolvable collegio | `"Nessun collegio elettorale trovato per questo comune."` |

The empty-chamber string dropped the word `indirizzo` (was `"Collegio Camera:
indirizzo non coperto dal prototipo per questa camera."`): the same component
now also serves a comune-name query, where "indirizzo" would be wrong.

**Accessibility identifiers.** `addressSearch.result.camera` /
`.senato` are unchanged and still present in all three branches (on the row,
the empty-state text, or the group header). The multi branch adds one
identifier per collegio, `addressSearch.result.camera.<collegioId>`.

---

## 5. Data-visibility staleness (baseline rule 9 — declared scope)

* **`README.md` — updated.** The feature bullet described a single
  three-tier geometric resolution, which is now false for comune names; it
  is rewritten as the two paths above, naming the six multi-collegio comuni
  behaviour explicitly. The `make comuni` comment in the pipeline section was
  updated (the artifact is no longer "7,904 comune centroids").
* **`docs/DATA_SOURCES.md` — updated.** Section retitled; the transformation
  summary now describes both what the record carries and the coverage of each
  path separately (the name path is complete by construction; the coordinate
  path keeps Phase 30's 99.94 %/99.97 % figures, which describe *it*); the
  6-comuni/11.67 % fact and the `POP_2011` census-2011 vintage are stated;
  the cross-check trailer gained a 2026-07-27 entry.
* **`tools/make_manifest.py` → `Politici/Data/sources.json` — updated.** The
  `istat-comuni-centroidi` entry's `name` and `notes` described a
  centroid-only table. Rewritten (Italian, in-app copy) to say the published
  assignment answers name queries and that six comuni are shown with all
  their collegi. No new entry, no `retrievedAt` moved.
* **`HomeView` "Come funziona l'elezione" — deliberately not touched.** It
  explains the electoral system (uninominale / plurinominale / Estero), not
  address resolution; nothing in it became inaccurate. Same decision Phase 30
  recorded, re-checked rather than inherited.
* **`HomeView`'s search field copy — deliberately not touched.** `"Inserisci
  un indirizzo o una città"` and its hint `"Cerca il collegio elettorale per
  indirizzo o città"` remain accurate: both are still what the field accepts.

---

## 6. Test specifications, one by one

**Spec 1 — probe output quoted, (a)–(e) individually evidenced, GO/NO-GO
stated.** Met — §2, five conditions each with its own quoted block and
verdict; **GO-ASSIGN: GO**. The probe is committed under `tools/probes/` and
was run before the importer changed.

**Spec 2 — validator green; counts from gate evidence; new byte gate with
measured headroom; all other generated files byte-identical.** Met.

```
OK: 7904 comuni in Politici/Data/comuni.json (875.7 KiB) — 6 nomi omonimi disambiguati per provincia, 6 su più collegi uninominali
OK: assegnazione comune → collegio referenzialmente esatta — Camera 147/147 collegi, Senato 74/74 collegi coperti
…
EXIT: 0
```

New checks, with their expected counts taken from §2's probe output and
attributed to it in the source comments — never from the plan file:
`camera`/`senato` are non-empty, sorted, duplicate-free string arrays with the
`"S"` prefix enforced on the Senato side; exactly
`EXPECTED_COMUNI_MULTI_COLLEGIO = 6` comuni are multi-valued (a drift
detector — the names are printed on failure); and a new cross-file
`validate_comuni_reference_districts()` proving **both** directions of
condition (b) against the shipped boundary files. Byte gate: §2(d).
`git status` shows exactly two files changed under `Politici/Data/` —
`comuni.json` and `sources.json`; `representatives.json`, `votes.json`,
`memberships_camera.json` and all four boundary files are **byte-identical**.

**Spec 3 — named resolution regressions, expected ids verified by standalone
script before hardcoding.** Met — `PoliticiTests/ComuneAssignmentTests.swift`.
The probe's own `test-expectation re-derivation` section prints each expected
id **straight from `UT_Collegi2020`'s `CU20_COD`/`SU20_COD`**, never read back
off the implementation (Phase 25 precedent); it is quoted in §9 and is what
the test file hardcodes. Covered: the 4 corrections
(`Carbonara di Nola` ×2 chambers, `Torre de' Roveri`, `Pieve di Cento`), all
7 gap-fills (`Isole Tremiti` ×2, `Correzzana`, `Pognana Lario`,
`Porto Recanati`, `Ronzone`, `Tropea`), and the 14 unchanged Phase 30 comuni
re-derived as **sets** — which is the concrete reason they needed
re-derivation: five of them are split comuni whose single expected id stopped
being the right assertion.

**Spec 4 — multi-collegio returns all, never one; chooser tested; unknown
still nil.** Met — `ComuneAssignmentTests`:
`testMultiCollegioComuniAreExactlyTheSixMeasured` pins the set;
`testMultiCollegioComuneReturnsEveryCollegioNeverOne` asserts Roma resolves to
all 7 Camera / 3 Senato districts **and** explicitly that the result is *not*
`["120105"]` (the Phase 30 largest-part answer is a member of the set, not the
set); `testNoMultiCollegioComuneEverResolvesToASingleAnswer` sweeps all six;
`testHomonymNameIsAmbiguousAndEachCandidateHasItsOwnAssignment` drives the
chooser path and shows the two `Castro` candidates carry **different**
assignments, so the province choice is a real one;
`testUnknownComuneIsNoneNeverAFallback` covers unknown, empty and the
German-only exonym. The UI half is asserted end-to-end in flow 7 (spec 7).

**Spec 5 — coordinate/address path unchanged, with a test pinning that the
two paths are deliberately distinct.** Met —
`ComuneGeocodingIntegrationTests` keeps Phase 30's two tests **unmodified**
(same 14 coordinate → collegio pairs, same dual-chamber assertion) and gains
`testCoordinatePathAndPublishedAssignmentAreDeliberatelyDistinct`, which pins
both sides of the divergence on the two worked examples: `Carbonara di Nola`
resolves to `150204` **by coordinate** (Phase 30's disclosed artefact,
deliberately still there) and to `150106` **by name**; `Isole Tremiti`
resolves to `nil` by coordinate — the nil is *not* patched — and to `160002`
by name. `GeocodingService`'s tier order is untouched and its four tests still
pass.

**Spec 6 — unexpected `schemaVersion` fails loudly; no silent degradation.**
Met — `PoliticiTests/ComuniSchemaVersionTests.swift`, 5 tests.
`ComuniFile.init(from:)` throws `ComuniFileError.unsupportedSchemaVersion` on
**any** version other than 2 — the check is equality, not a floor, so a v1
file (tested) and a hypothetical v3 file (tested) are both refused. The
assignment fields are **non-optional**, so a correctly-versioned file that
lost them fails to decode too (tested) instead of yielding comuni with an
empty assignment. `ComuneService` surfaces the error as `loadError`, logs it,
and answers `.none` to everything (tested) — a total, loud absence rather than
a partial table.

**Spec 7 — flow 7's wait bounded through the test seam; no production timeout
introduced.** Met. The 300 s ceiling is gone; the assertion now uses the
suite's ordinary `Self.timeout` (30 s) and the test ran in **21.7 s** in the
certifying run (17.0 s in an isolated one). Two independent things bound it:
"Roma" is now answered offline from the published assignment without geocoding
at all, and every UI test launches with `-stubAddressResolver 1`, which swaps
the `CLGeocoder` tier for one that resolves nothing instantly. **No production
timeout was added** — `CLGeocoderResolver` is untouched and the production
tier-1 timeout stays with Phase 32A, as the phase file requires.

**Spec 8 — UI strings pinned, all Italian; rule 9 sweep recorded including
deliberate non-changes.** Met — §4 (strings table) and §5 (sweep, including
the two deliberate non-changes).

**Spec 9 — suite green; additions counted against the Phase 30 baseline of
204.** Met.

```
** TEST SUCCEEDED **        (exit code 0)

  totalTestCount: 219
  passedTests: 219
  failedTests: 0
  skippedTests: 0
  expectedFailures: 0
  result: Passed
```

Declared count re-derived from source with the **occurrence rule** (never
`sort -u`, per `CLAUDE.md`):

| | Phase 30 | Phase 30B | Δ |
|---|---:|---:|---:|
| `PoliticiTests` `func test…(` | 192 | 207 | +15 |
| `PoliticiTests` `@Test` | 1 | 1 | 0 |
| `PoliticiUITests` `func test…(` | 11 | 11 | 0 |
| **Declared** | **204** | **219** | **+15** |

+15 = 9 (`ComuneAssignmentTests`, new) + 5 (`ComuniSchemaVersionTests`, new)
+ 1 (`ComuneGeocodingIntegrationTests`, 2 → 3). Declared **219** equals the
`.xcresult`'s `totalTestCount` **219**, and the log carried **219** `passed`
lines — **no truncation occurred this run**, so the `CLAUDE.md` quirk's tally
stays at four sightings. **No UI-test flake occurred either**, so that tally
is also unchanged.

**Deliberate test-expectation changes, listed per plan-wide rule 5:**

| Test | Change | Why |
|---|---|---|
| `ComuneGeocodingIntegrationTests` (file) | header rewritten; both existing tests' **assertions unchanged** | the file now pins the *coordinate* path specifically; the name path moved to `ComuneAssignmentTests` |
| `GeocodingTierTests` ×2 | the two `Comune(...)` fixtures gained `camera:`/`senato:` | the model's new non-optional fields. Values are the **real** published assignments for `Castro (Bergamo)` and `Predoi (Bolzano)`, read from the source, not invented placeholders |
| `SmokeFlowUITests` flow 7 | `timeout: 300` → `Self.timeout`; one new assertion | spec 7 (the seam now bounds it) and spec 4's UI half |
| `PoliticiUITestCase` | `launchArguments` now includes `-stubAddressResolver 1` | the seam, applied suite-wide |

No other existing test was modified or removed.

**One failure occurred during development and was a real defect in this
phase's own change, not a flake** — recorded because diagnosing it changed the
implementation. The first full run failed flow 7's new assertion with
`("0") is not greater than ("1")`: the per-collegio identifiers were absent.
Root cause was not the test — an `accessibilityIdentifier` applied to the
enclosing `VStack` propagates down and **overrides** the identifiers set on
its children, erasing exactly the per-row addressability the branch exists
for. Fixed by moving the group identifier onto the group's header `Text`
(commented in place so it is not "simplified" back later). The assertion was
not loosened.

---

## 7. Generated-data change protocol

Two generated files changed. Both diffs were inspected in full; nothing else
under `Politici/Data/` moved.

**`Politici/Data/comuni.json`** — one line (the file is single-line compact
JSON), so the diff was inspected structurally rather than textually:

```
keys identical: True                 # the same 7,904 (name, province) pairs
coordinates changed: 0 []            # every lat/lon byte-identical to Phase 30
order identical: True                # same sort, same positions
new keys per record: ['camera', 'lat', 'lon', 'name', 'province', 'senato']
```

Every change is the two added keys and the `schemaVersion` bump. **Expected,
explained, committed.**

Verified **idempotent** — run twice, byte-identical, and again after the
validating test run:

```
$ shasum -a 256 Politici/Data/comuni.json
45ece6284dc0ae8fa8eb3a3f75b40a5bcff79bf0b413e03ff108432d03e54152
$ python3 tools/import_comuni.py
OK: 7904 comuni in Politici/Data/comuni.json (875.7 KiB) — 6 nomi omonimi disambiguati per provincia, 6 comuni su più collegi uninominali
$ shasum -a 256 Politici/Data/comuni.json
45ece6284dc0ae8fa8eb3a3f75b40a5bcff79bf0b413e03ff108432d03e54152
```

The 896,739 B written is **byte-identical to the probe's variant-A
measurement**, an independent confirmation that the gate decision and the
artifact are the same object.

**`Politici/Data/sources.json` — exactly three changed lines, all expected:**

```diff
-  "generatedAt": "2026-07-23",
+  "generatedAt": "2026-07-27",
@@
-      "name": "ISTAT — Comuni (centroidi per la geocodifica offline)",
-      "notes": "Tabella dei 7.904 comuni italiani con un punto interno (centroide) …",
+      "name": "ISTAT — Comuni (assegnazione ai collegi e centroidi)",
+      "notes": "Tabella dei 7.904 comuni italiani. Per ciascuno riporta l'assegnazione ai collegi uninominali pubblicata dalla fonte …",
       "retrievedAt": "2026-07-18",
```

1. `generatedAt` — the date `make manifest` actually ran. Expected.
2. The one entry's `name`/`notes`, rewritten for rule 9 (§5).

**No `retrievedAt` moved, no entry added or removed, `schemaVersion` stays 2,
the other nine entries are byte-identical.** The fresh-checkout caveat does not
apply: `tools/raw/.fetch_metadata.json` was confirmed present with its real
committed dates *before* running `make manifest`, and the diff above proves
the `date.today()` fallback was never reached.

**Re-run rule (bundled data changed after a validating run).** The only
post-test-run pipeline execution was the idempotency check above, which
produced a **byte-identical** `comuni.json` (same SHA-256). `make manifest`
ran *before* the certifying test run. The tree the suite validated is the tree
being committed, so no re-run is owed.

---

## 8. Reconciliation with Phase 30 — superseded, not wrong

Phase 30's report and spec are the historical record and were **not edited**
(baseline rule on completed phases). What changed status:

| Phase 30 statement | Status after 30B |
|---|---|
| "99.94 % resolve to a Camera collegio … 99.97 % to a Senato one" | **Still true, now scoped**: those describe the *coordinate* path, which is unchanged. The *name* path has no nil rate — every comune has a published assignment |
| "2 comuni resolve to a neighbouring collegio … disclosed, not corrected" | **Still true of the coordinate path** (pinned by a test). The name path no longer inherits it |
| "1 comune (Isole Tremiti) resolves to none" | Same: coordinate path nil (pinned), name path answers `160002` / `S160001` |
| "for a split comune the point lands in the largest territorial part" | Same for the coordinate path; the name path returns the whole set |
| `comuni.json` 581,849 B against a 768 KiB gate | Superseded: 896,739 B against a 1.25 MiB gate |
| §10's `Data/` total 6,351,326 B (60.6 %) | Superseded by §9's 6,666,551 B (63.6 %) |
| §11's "awaiting the user's decision" | Resolved by this phase; the deferred-list entry is updated in this commit |
| §12's flow-7 lever 1 (test-side) "Recommended, not decided" | **Done here** (spec 7). Lever 2 (a production `CLGeocoder` timeout) remains untouched and stays with 32A |

One small correction of a **measurement**, not a claim: Phase 30 §10 states
the three `*.sample.*` fixtures "add a further 13,179 B". Measured today they
total **14,765 B** (3,773 + 6,423 + 4,569), and all three are byte-identical
to their content at Phase 30's commit `0e76a75` — so the 13,179 figure was a
mis-sum carried forward, not a file that changed. Noted here rather than
edited there.

---

## 9. Post-Phase-30B bundle figure (for Phases 32A/32B)

Real (non-`*.sample.*`) `Politici/Data/` immediately after Phase 30B:

| File | Bytes |
|---|---:|
| `votes.json` | 1,767,926 |
| `districts.geojson` | 1,158,457 |
| **`comuni.json`** | **896,739** |
| `districts_senato.geojson` | 867,362 |
| `districts_plurinominali_camera.geojson` | 766,581 |
| `districts_plurinominali_senato.geojson` | 608,842 |
| `representatives.json` | 482,770 |
| `memberships_camera.json` | 108,917 |
| `sources.json` | 7,337 |
| `parties.json` | 1,620 |
| **TOTAL real** | **6,666,551 B = 6.36 MiB = 63.6 % of the ~10 MiB soft ceiling** |

The three `*.sample.*` test fixtures add a further **14,765 B** (measured;
see §8). Headroom against the soft ceiling: **3.64 MiB**.

### The re-derived test expectations (quoted before the tests hardcoded them)

Printed by the committed probe straight from `UT_Collegi2020`:

```
--- test-expectation re-derivation (published assignment, from source) ---
    Roma                   (Roma                  ) camera=['120101', '120102', '120103', '120104', '120105', '120106', '120107']  senato=['S120002', 'S120003', 'S120004']
    Milano                 (Milano                ) camera=['30107', '30108', '30109']  senato=['S30003', 'S30004']
    Napoli                 (Napoli                ) camera=['150102', '150103']  senato=['S150004']
    Torino                 (Torino                ) camera=['10101', '10102']  senato=['S10001']
    Firenze                (Firenze               ) camera=['90007']  senato=['S90004']
    Bologna                (Bologna               ) camera=['80006']  senato=['S80003']
    Bari                   (Bari                  ) camera=['160005']  senato=['S160003']
    Genova                 (Genova                ) camera=['70002', '70003']  senato=['S70001', 'S70002']
    Venezia                (Venezia               ) camera=['50101']  senato=['S50001']
    Aosta                  (Aosta                 ) camera=['20001']  senato=['S20001']
    Trento                 (Trento                ) camera=['40001']  senato=['S40001']
    Cagliari               (Cagliari              ) camera=['200001']  senato=['S200001']
    Bolzano                (Bolzano               ) camera=['40003']  senato=['S40004']
    Perugia                (Perugia               ) camera=['100002']  senato=['S100001']
    Calliano               (Asti                  ) camera=['10204']  senato=['S10004']
    Calliano               (Trento                ) camera=['40002']  senato=['S40002']
    Castro                 (Bergamo               ) camera=['30302']  senato=['S30007']
    Castro                 (Lecce                 ) camera=['160010']  senato=['S160005']
    Livo                   (Como                  ) camera=['30204']  senato=['S30002']
    Livo                   (Trento                ) camera=['40001']  senato=['S40001']
    Peglio                 (Como                  ) camera=['30204']  senato=['S30002']
    Peglio                 (Pesaro e Urbino       ) camera=['110004']  senato=['S110002']
    Samone                 (Torino                ) camera=['10104']  senato=['S10003']
    Samone                 (Trento                ) camera=['40002']  senato=['S40003']
    San Teodoro            (Messina               ) camera=['190205']  senato=['S190006']
    San Teodoro            (Sassari               ) camera=['200004']  senato=['S200002']
    Carbonara di Nola      (Napoli                ) camera=['150106']  senato=['S150007']
    Correzzana             (Monza e della Brianza ) camera=['30102']  senato=['S30006']
    Isole Tremiti          (Foggia                ) camera=['160002']  senato=['S160001']
    Palermo                (Palermo               ) camera=['190101', '190102']  senato=['S190001']
    Pieve di Cento         (Bologna               ) camera=['80007']  senato=['S80003']
    Pognana Lario          (Como                  ) camera=['30203']  senato=['S30002']
    Porto Recanati         (Macerata              ) camera=['110002']  senato=['S110001']
    Ronzone                (Trento                ) camera=['40001']  senato=['S40001']
    Torre de' Roveri       (Bergamo               ) camera=['30301']  senato=['S30009']
    Tropea                 (Vibo Valentia         ) camera=['180004']  senato=['S180002']
```

---

## 10. Acceptance criteria

| # | Criterion | Outcome |
|---|---|---|
| 1 | Probe output quoted; (a)–(e) individually evidenced; GO/NO-GO stated | **Met** — §2, **GO** on all five |
| 2 | Validator green; counts from gate evidence; new byte gate with headroom; other generated files byte-identical | **Met** — §6 spec 2, §2(d), §7 |
| 3 | Named resolution regressions; expected ids verified by standalone script first | **Met** — §6 spec 3, §9 |
| 4 | Multi-collegio returns all, never one; chooser tested; unknown still nil | **Met** — §6 spec 4 |
| 5 | Coordinate path unchanged; a test pins the two paths as distinct | **Met** — §6 spec 5 |
| 6 | Unexpected `schemaVersion` fails loudly; no silent degradation | **Met** — §6 spec 6 |
| 7 | Flow 7 bounded through the test seam; no production timeout | **Met** — §6 spec 7; 300 s → 30 s, ran in 21.7 s |
| 8 | UI strings pinned, all Italian; rule 9 sweep recorded incl. non-changes | **Met** — §4, §5 |
| 9 | Suite green; additions counted against the 204 baseline | **Met** — 204 → **219**, 0 failures |

### Deviations, stated honestly

1. **The schema does not carry `_DEN`, plurinominale or circoscrizione
   fields**, which the phase file's deliverable sentence names. Measured at
   **+275.8 %** (variant C), against the phase file's own ~35 % projection —
   which triggers its documented fallback clause, "a leaner schema (codes
   without redundant `_DEN` strings)". Shipped variant A is exactly that
   fallback. Recorded as the documented trim the clause requires, not taken
   silently (§2(d)). Nothing in this phase's deliverables or test specs
   consumes the omitted fields; if a later phase needs the plurinominale
   assignment it is a small additive change with its own measurement.
2. **The byte gate is 1.25 MiB, not the ~1 MiB the phase file projected.**
   At the measured 896,739 B a 1 MiB gate would sit at 85.5 %, out of family
   with the project's other coarse drift backstops. Stated with measured
   headroom (§2(d)) rather than adjusted quietly.
3. **The (e) diff is 13/7 changes, not the 7/4 the phase file expected.** Not
   an unexplained additional change: the extra 6/3 are exactly the (c)
   multi-collegio set, which Phase 30 §11.3's counting rule classified as
   "agrees" because geometry returned a *member* of the published set. Full
   reconciliation table in §2(e).
4. **The flow-7 seam touches production source, not "the UI test target
   only"** as the phase file words it. A UI test drives a separate process
   and cannot inject a Swift object into it; the only mechanism is a launch
   argument the app reads. Implemented exactly like the Phase 24 favorites
   seam it mirrors: `#if DEBUG`, compiled out of release builds entirely,
   inert unless the argument is passed. **No production behaviour changed**
   and no timeout was introduced, which is what the requirement is actually
   protecting.
5. **The multi-collegio UI took the "honest all-of-these label" branch rather
   than the chooser** — both are permitted by the phase file; the reasoning
   for preferring one is in §4 rather than left implicit.

No other deviation. Nothing under `docs/v2/`, `docs/v3/`, `docs/history/`, or
`docs/v4/30-comuni-geocoding.md` was edited.

---

## 11. Diff scope for this commit

```
Politici/Data/comuni.json                          (regenerated — schemaVersion 2)
Politici/Data/sources.json                         (regenerated — 1 entry's name/notes)
Politici/Models/Comune.swift                       (camera/senato + loud schemaVersion)
Politici/Services/ComuneService.swift              (ComuneNameMatch: one/many/none)
Politici/Services/DistrictService.swift            (districts(assignedTo:))
Politici/Services/GeocodingService.swift           (DEBUG UI-test resolver seam + .live)
Politici/Services/ServiceContainer.swift           (geocodingService: .live)
Politici/Views/AddressSearchView.swift             (two paths + ChamberResultGroup)
PoliticiTests/ComuneAssignmentTests.swift          (new — 9)
PoliticiTests/ComuniSchemaVersionTests.swift       (new — 5)
PoliticiTests/ComuneGeocodingIntegrationTests.swift(coordinate-path scope, +1)
PoliticiTests/GeocodingTierTests.swift             (fixtures gained the assignment)
PoliticiUITests/PoliticiUITestCase.swift           (-stubAddressResolver launch arg)
PoliticiUITests/SmokeFlowUITests.swift             (flow 7: 300 s -> 30 s, +assertion)
tools/import_comuni.py                             (schemaVersion 2 + new byte gate)
tools/validate_data.py                             (comuni v2 + cross-file check)
tools/make_manifest.py                             (comuni source name/notes)
tools/probes/probe_comuni_assignment.py            (new — committed GO-ASSIGN probe)
README.md                                          (rule 9 staleness)
docs/DATA_SOURCES.md                               (rule 9 staleness + cross-check)
docs/v4/30b-comuni-assignment.md                   (new — this report)
docs/plan/phase-30b.md                             (the commissioned phase file)
docs/plan/README.md                                (Phase 30B row: pending -> done)
docs/plan/00-baseline-and-rules.md                 (open decision marked RESOLVED)
```

`tools/probes/output/` is gitignored and is never an import source.

Remote actions are the user's. Not run here:

```
git push origin v4
```
