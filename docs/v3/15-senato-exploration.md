# V3 Phase 15 — Senato Source Exploration

Read-only exploration of the Senato geographic layer (ISTAT shapefile
cache) and the Senato SPARQL cache, producing two independent gates:
**GO/NO-GO(MAP)** for rendering Senato collegio boundaries, and
**GO/NO-GO(LINK)** for joining a senator to their collegio. No app code
changed, no bundled data changed — every number below is quoted from a
command transcript run in this phase.

Environment: `ogrinfo`/`ogr2ogr` = GDAL 3.13.1 "Iowa City" (`/opt/homebrew/bin/ogr2ogr`).

## Cache presence

`tools/raw/collegi/` exists on this machine (confirmed before any other
step): `ls tools/raw/collegi/` lists `CAMERA_CollegiPLURINOMINALI_2020`,
`CAMERA_CollegiUNINOMINALI_2020`, `Circoscrizioni_Camera`,
`Regioni_Senato`, `SENATO_CollegiPLURINOMINALI_2020`,
`SENATO_CollegiUNINOMINALI_2020`, `UT_Collegi2020`. Not blocked — proceeding.

## 1. Senato uninominale layer — `ogrinfo -so`

```
$ ogrinfo -so tools/raw/collegi/SENATO_CollegiUNINOMINALI_2020/SENATO_CollegiUNINOMINALI_2020.shp SENATO_CollegiUNINOMINALI_2020

Layer name: SENATO_CollegiUNINOMINALI_2020
Metadata:
  DBF_DATE_LAST_UPDATE=2022-07-28
Geometry: Polygon
Feature Count: 74
Extent: (313279.251400, 3933682.932500) - (1312016.150600, 5220292.292200)
Layer SRS WKT:
PROJCRS["WGS 84 / UTM zone 32N", ... ID["EPSG",32632]]
Data axis to CRS axis mapping: 1,2
OBJECTID: Integer64 (10.0)
SU20_COD: Integer64 (10.0)
SU20_DEN: String (150.0)
SU20_C1: String (254.0)
Shape_Leng: Real (19.11)
Shape_Area: Real (19.11)
POP_2011: Real (19.11)
```

(WKT elided above for length — full CRS block matches Camera's
EPSG:32632/WGS 84 UTM zone 32N exactly, same transverse-Mercator
parameters, same reprojection path to EPSG:4326 that
`tools/build_boundaries.sh` already uses for Camera.)

**Verified feature count: 74.** Field schema is the SU20-prefixed mirror
of Camera's CU20 schema (`OBJECTID`, `SU20_COD` Integer64, `SU20_DEN`
String(150), `SU20_C1` String(254), plus the same `Shape_Leng`/`Shape_Area`/`POP_2011`
measures) — same shapefile producer, same 2022-07-28 `DBF_DATE_LAST_UPDATE`
as the Camera layer (confirmed against Camera's own `ogrinfo` output from
Phase 13's C5 investigation).

Sample attribute rows (`ogrinfo -al -geom=NO`, first 10 of 74):

```
SU20_COD=10001  SU20_DEN="Piemonte - U01"                        SU20_C1=U01
SU20_COD=10002  SU20_DEN="Piemonte - U02"                        SU20_C1=U02
SU20_COD=10003  SU20_DEN="Piemonte - U03"                        SU20_C1=U03
SU20_COD=10004  SU20_DEN="Piemonte - U04"                        SU20_C1=U04
SU20_COD=10005  SU20_DEN="Piemonte - U05"                        SU20_C1=U05
SU20_COD=20001  SU20_DEN="Valle d'aosta/Vallée d'Aoste - U01"    SU20_C1=U01
SU20_COD=30001  SU20_DEN="Lombardia - U01"                       SU20_C1=U01
SU20_COD=30002  SU20_DEN="Lombardia - U02"                       SU20_C1=U02
SU20_COD=30003  SU20_DEN="Lombardia - U03"                       SU20_C1=U03
SU20_COD=30004  SU20_DEN="Lombardia - U04"                       SU20_C1=U04
```

## 2. Plurinominale layers (context only, no import planned)

```
$ ogrinfo -so .../CAMERA_CollegiPLURINOMINALI_2020.shp CAMERA_CollegiPLURINOMINALI_2020
Layer name: CAMERA_CollegiPLURINOMINALI_2020
Geometry: Polygon
Feature Count: 50

$ ogrinfo -so .../SENATO_CollegiPLURINOMINALI_2020.shp SENATO_CollegiPLURINOMINALI_2020
Layer name: SENATO_CollegiPLURINOMINALI_2020
Geometry: Polygon
Feature Count: 27
```

Recorded for future reference only — no plurinominale import is planned
by this phase or proposed by this report.

## 3. Denomination rule

`SU20_DEN` follows the same `"{grouping} - U0N"` shape as Camera's
`CU20_DEN`, but **the grouping is a different concept**, verified by
comparing the two layers' unique prefixes:

```
Senato SU20_DEN prefixes (20 distinct, ogrinfo dump, sed-stripped of " - U0N"):
Abruzzo, Basilicata, Calabria, Campania, Emilia-Romagna, Friuli-Venezia Giulia,
Lazio, Liguria, Lombardia, Marche, Molise, Piemonte, Puglia, Sardegna, Sicilia,
Toscana, Trentino-Alto Adige/Südtirol, Umbria, Valle d'aosta/Vallée d'Aoste, Veneto

Camera districts.geojson circoscrizione values (28 distinct, from the
bundled, already-shipped file):
Abruzzo, Basilicata, Calabria, Campania 1, Campania 2, Emilia-Romagna,
Friuli-Venezia Giulia, Lazio 1, Lazio 2, Liguria, Lombardia 1, Lombardia 2,
Lombardia 3, Lombardia 4, Marche, Molise, Piemonte 1, Piemonte 2, Puglia,
Sardegna, Sicilia 1, Sicilia 2, Toscana, Trentino-Alto Adige/Südtirol,
Umbria, Valle d'aosta/Vallée d'Aoste, Veneto 1, Veneto 2
```

Senato's 20 values are exactly Italy's 20 administrative regions,
**unsplit**. Camera's 28 circoscrizioni split the larger regions
(Lombardia → 1–4, Piemonte/Lazio/Sicilia/Veneto/Campania → 1–2) into
multiple electoral groupings. This is a genuine semantic difference, not
a formatting quirk: Camera's `circoscrizione` field name would be
**misleading** if reused verbatim for Senato, since a Senato "grouping"
really is the administrative region 1:1 with no split. **Display-name
derivation rule for a future Senato import**: parse `SU20_DEN` the same
structural way as Camera's `CU20_DEN` (prefix before `" - {subCode}"`,
verified to match `SU20_C1`'s tail in the sample above with no exceptions
found in the 10-row spot check), but name the resulting property
`regione` for Senato districts, not `circoscrizione` — reusing Camera's
field name for a different concept would misrepresent the source
structure, which the standing "never fabricate" constraint requires
avoiding even for a field name choice.

## 4. ID collision check

Extracted all 74 `SU20_COD` values and intersected with the 147 Camera
`id` values already shipped in `Politici/Data/districts.geojson`:

```python
camera_ids = {f['properties']['id'] for f in districts.geojson features}   # 147
senato_ids = {str(su20_cod) for f in Senato uninominale layer features}     # 74
intersection = camera_ids & senato_ids
```

**Result: 32 of 74 Senato ids collide with existing Camera ids** (43% —
not a rare edge case, a routine occurrence, since both codes are
independently assigned low integers per region/circoscrizione):

```
20001, 40001, 40002, 40003, 40004, 60001, 70001, 70002, 80001, 80002,
80003, 80004, 80005, 90001, 90002, 90003, 90004, 100001, 110001, 110002,
130001, 140001, 160001, 160002, 160003, 160004, 160005, 170001, 180001,
180002, 200001, 200002
```

Per the already-decided policy (stated in this phase's brief, applied
here rather than re-litigated): **Senato ids receive a chamber prefix at
import time; Camera ids are never modified** — the existing Camera
linkage (147 `districtId` references in `representatives.json`) depends
on those ids staying exactly as shipped. This collision check confirms
the policy was necessary, not precautionary: a same-day merge without
prefixing would have silently aliased 32 real, distinct Camera and Senato
collegi onto the same id.

## 5. Simplification probe

`tools/probes/probe_senato_simplify.py` (committed) runs `ogr2ogr -t_srs
EPSG:4326 -simplify <tolerance>` at a small sweep and measures byte size +
per-feature vertex maxima, reusing the exact `count_vertices()` logic from
`tools/import_boundaries.py` (Phase 14). Output written to
`tools/probes/output/` (gitignored), not committed.

```
$ python3 tools/probes/probe_senato_simplify.py 500 1000 1500 2000
tolerance_m      bytes       KB  max_vertices   max_id  island_spot_check
        500     576111    562.6          1048   200002  {200001: 'MultiPolygon', 200002: 'MultiPolygon'}
       1000     341578    333.6           800   200002  {200001: 'MultiPolygon', 200002: 'MultiPolygon'}
       1500     263362    257.2           710   200002  {200001: 'MultiPolygon', 200002: 'MultiPolygon'}
       2000     218881    213.8           665   200002  {200001: 'MultiPolygon', 200002: 'MultiPolygon'}
```

Island spot-check target: Sardegna's two Senato uninominale collegi
(`200001`, `200002` — the region is unsplit for Senato, so both together
cover mainland Sardegna plus the La Maddalena archipelago). Verified
`MultiPolygon` at every tested tolerance, including the coarsest (2000 m).

Separately, at the source (no simplification), 34 of the 74 Senato
features are already `MultiPolygon` — verified via a raw `ogr2ogr -f
GeoJSON` conversion (no `-simplify` flag) and counting `geometry.type ==
"MultiPolygon"` in Python: `10001, 30002, 30010, 60001, 70001, 70002,
80001, 80002, 90001, 90002, 100001, 120002, 120004, 120006, 130001,
150003, 150004, 150005, 150006, 160001–160005, 170001, 180001,
190001–190006, 200001, 200002` (34 total).

**Byte-size reality check (schema-v2 transform inflation):** the
`ogr2ogr`-only sizes above are compact JSON; the actual pipeline output
(`import_boundaries.py`, Phase 7/14) writes `json.dumps(..., indent=2)` —
pretty-printed, one coordinate pair per line. Measured against Camera's
own real numbers: intermediate `tools/raw/camera_collegi_uninominali_wgs84.geojson`
= 464,060 bytes; final `Politici/Data/districts.geojson` = 1,158,457
bytes — a **2.496x** inflation ratio, driven by indentation, not by the
schema-v2 property additions (spot-checked the first ~300 bytes of each
file: the intermediate is single-line compact, the final is
one-coordinate-per-line indented). Applying that same, evidence-derived
ratio to Senato's 1000 m intermediate size (341,578 bytes) projects a
**~852,700-byte (~833 KB)** final schema-v2 file — well under the 3 MB
per-file gate whether shipped as its own file or merged into a combined
221-feature (147 + 74) `districts.geojson` (projected combined ≈
1,158,457 + 852,700 ≈ **1.97 MB**, still under 3 MB). Architecture
(merge vs. separate file) is an implementation-phase decision, not made
here — both options fit the existing budget either way.

**Tolerance choice: 1000 m**, matching Camera's existing calibration
(consistency of rendering fidelity between the two chambers), not the
finest tested value — 1000 m already clears both gates with wide margin
(800 vertices vs. the 1500 gate; ~833 KB projected vs. the 3 MB gate) and
preserves every tested island MultiPolygon. Finer tolerances (500 m) were
measured and also pass, but there's no evidence-based reason to diverge
from the value already validated and shipped for Camera.

## 6. Senato SPARQL cache — predicate inventory

`tools/raw/senato_senatori_sparql.json` (774,361→368,089 bytes — see
`ls -la` for the three cache files; sizes match what Phase 13 recorded),
standard SPARQL JSON results shape (`head.vars` / `results.bindings`):

```
head.vars: ['senatore', 'foto', 'nome', 'cognome', 'legislatura',
            'inizioMandato', 'fineMandato', 'tipoMandato',
            'tipoFineMandato', 'dataNascita', 'cittaNascita',
            'provinciaNascita', 'nazioneNascita']
results.bindings: 208 total
```

Cross-checked against `tools/queries/senato_senatori.rq`: the query's own
`SELECT` list matches `head.vars` exactly — **no collegio, circoscrizione,
or spatial predicate is requested or present anywhere in this cache.**
The two sibling queries (`senato_gruppi.rq`, `senato_commissioni.rq`) were
also read in full; neither queries or exposes anything collegio-shaped
either (their vocabulary is `osr:denominazione`/`osr:titolo`/`osr:carica`/`osr:afferisce`/`osr:commissione`
— group/committee membership only).

### 7a. Life-senator marker — found, quoted

`osr:tipoMandato` is directly present and has exactly three distinct raw
values across all 208 bindings:

```python
tipoMandato value counts (all 208 bindings):
  'elettivo':                                              202
  'a vita, di nomina del Presidente della Repubblica':        5
  'di diritto e a vita, Presidente emerito della Repubblica': 1

Among the 201 bindings with no fineMandato bound (= currently serving,
per the existing v2 inclusion rule in docs/v2/02-post-import-audit.md):
  'elettivo':                                             196
  'a vita, di nomina del Presidente della Repubblica':       5
  (the Presidente-emerito record is NOT among the 201 — it has
   fineMandato bound, see below)
```

This exactly reproduces the starting-state's expected 196 elective + 5
life senators — verified from the actual cache, not assumed. The 5 life
senators, named and cross-checked one-for-one against the expected list:

```
Elena Cattaneo  | http://dati.senato.it/senatore/30511 | inizioMandato 2022-10-13
Mario Monti     | http://dati.senato.it/senatore/28543 | inizioMandato 2022-10-13
Renzo Piano     | http://dati.senato.it/senatore/30512 | inizioMandato 2022-10-13
Carlo Rubbia    | http://dati.senato.it/senatore/30510 | inizioMandato 2022-10-13
Liliana Segre   | http://dati.senato.it/senatore/32435 | inizioMandato 2022-10-13
```

Matches Cattaneo/Monti/Piano/Rubbia/Segre exactly. The excluded 208th-vs-201
record (`tipoMandato = "di diritto e a vita, Presidente emerito della
Repubblica"`) is:

```
Giorgio Napolitano | fineMandato: 2023-09-22 | tipoFineMandato: Deceduto
```

— matching `docs/v2/02-post-import-audit.md`'s account of "one former
President (deceased, mandate ended) correctly excluded," now re-verified
directly against the raw cache in this phase rather than cited from the
earlier report.

`representatives.json`'s actual shipped Senato count was independently
re-checked in this phase: `python3 -c "... len([r for r in
json.load(open('Politici/Data/representatives.json')) if r['chamber']=='Senato'])"`
→ **201**, matching the cache's 201 currently-serving count exactly.

### 7b. Collegio join key — NOT found; extension designed, not run

No field in `head.vars`, in either `.rq` query, or in any binding's keys
resembles a collegio/circoscrizione/spatial reference. This is a genuine
absence, not an oversight in this phase's search — the entire predicate
surface actually fetched was enumerated above and is exhaustive for what
this cache contains.

**Per this phase's own scope (read-only, no network), the correct next
step is NOT to guess a predicate name and write it into
`tools/queries/senato_senatori.rq`** — v2's own Phase 8 hit the identical
problem on the Camera side (the obvious `?collegio` variable turned out
to be the wrong granularity) and only found the correct field
(`dcterms:spatial`) via a **live SPARQL predicate-enumeration query**
against the graph, not by guessing from the ontology's naming
conventions (`docs/v2/03-linkage-report.md`; cited as the working
methodology in `CLAUDE.md`). Writing an unverified predicate name into
the pinned production query file would risk exactly the kind of
plausible-sounding-but-unsourced fabrication the standing constraints
forbid.

**Designed instead**: `tools/probes/probe_senato_predicate_discovery.rq`
(committed) — a live-introspection query that enumerates every distinct
predicate actually used on a `?senatore`/`?mandato` resource for
legislature 19, with one sample value and an occurrence count per
predicate. This is the same *kind* of instrument Phase 8 used, adapted to
the `osr:` ontology. **Not run in this phase** — running it means
querying `https://dati.senato.it/sparql` over the network, which this
phase's read-only scope excludes; it is deliberately left for a future,
explicitly-approved refetch-protocol step. Only after that probe's real
output is read can a genuine `senato_senatori.rq` collegio-join extension
be written and proposed.

## GO/NO-GO(MAP): **GO**

| Requirement | Evidence | Met? |
|---|---|---|
| Verified feature count | `ogrinfo -so`: **74** features, `SENATO_CollegiUNINOMINALI_2020` layer | ✓ |
| Confirmed reprojectable CRS | Source EPSG:32632 (WGS 84 / UTM zone 32N), identical to Camera's; `ogr2ogr -t_srs EPSG:4326` completed without error in the simplification probe (§5) | ✓ |
| Tolerance meeting both Phase 14 gates, islands preserved | 1000 m: **800** max vertices (< 1500 gate); ~833 KB projected final size (< 3 MB gate, and < 3 MB even combined with Camera at ~1.97 MB); Sardegna (`200001`/`200002`) verified `MultiPolygon` at every tested tolerance | ✓ |
| Id policy resolved | 32/74 collisions found and quoted (§4); pre-decided prefix-at-import policy directly resolves them without touching any Camera id | ✓ |

All four conditions independently verified in this phase with quoted
numbers. **Rendering Senato collegio boundaries on the map is
geometrically and technically viable** with the same toolchain, same
tolerance, and the existing vertex/byte gates, once a future
implementation phase does the actual import work (schema-v2 transform,
`regione` property per §3, prefixed ids per §4).

## GO/NO-GO(LINK): **NO-GO** (blocked on missing evidence, not a technical dead end)

| Requirement | Evidence | Met? |
|---|---|---|
| Demonstrated joinable key on both sides, quoted samples | ISTAT side has one (`SU20_DEN`/`SU20_C1`, quoted in §3/§1); **Senato SPARQL side has none** — exhaustively enumerated in §6/§7b, zero collegio-shaped predicate in the actual cache or either query file | ✗ |
| Written join design | Only a *contingent* design is possible: if a future live-introspection run (via the committed `probe_senato_predicate_discovery.rq`, §7b) finds a predicate whose value shape matches `"{regione} - U0N"`, the join would mirror Camera's own rung-2 approach (parse `SU20_DEN`'s prefix, match against the discovered predicate's value string) — but this is *speculative*, not demonstrated, and is not asserted as a working design here | n/a — see above |
| `MIN_LINKED_SENATO` gate at 90% of verified linkable-elective count | **Cannot be computed.** The "count of linkable elective senators" is exactly the unknown this gate depends on, and it isn't knowable until a join key is found. No number is fabricated in its place. | ✗ |

**Decision: NO-GO(LINK) at this time.** This is not a finding that Senato
linkage is impossible — Senato does have 196 elective senators and 74
uninominale collegi, so a join plausibly exists in the graph somewhere —
it is a finding that **this phase's evidence does not demonstrate one**,
and per the standing constraint ("if data is missing or ambiguous, stop
and document it"), no join is designed as if verified. **Required next
step, explicitly out of this phase's scope:** run
`tools/probes/probe_senato_predicate_discovery.rq` against
`https://dati.senato.it/sparql` under a deliberate, approved refetch-protocol
step; read its actual output; only then extend
`tools/queries/senato_senatori.rq` for real and redo this evaluation with
real evidence.

## Life-senator import design

Independent of the LINK gate above — the marker predicate (§7a) is fully
verified and needs no further network access to use.

**Marker**: `osr:tipoMandato`, already fetched by the existing
`senato_senatori.rq` (no query change needed for this part). Three raw
values verified present in the cache (§7a): `"elettivo"`, `"a vita, di
nomina del Presidente della Repubblica"`, `"di diritto e a vita,
Presidente emerito della Repubblica"`.

**New tolerant field — `MandateType`** (separate from `ElectionType`,
which stays election-*method*-only and remains `null` for every senator,
per this phase's brief — Senato mandates aren't Camera-style
maggioritario/proporzionale elections, so overloading `ElectionType`
would misrepresent what the field means):

```swift
enum MandateType: String, TolerantStringEnum {
    case elettivo = "elettivo"
    case nominaAVita = "a vita, di nomina del Presidente della Repubblica"
    case diDirittoEAVita = "di diritto e a vita, Presidente emerito della Repubblica"
    case sconosciuto  // tolerant-decode fallback only — never written by the
                       // import script itself; exists solely so an
                       // unanticipated future raw value decodes to an
                       // explicit unknown instead of crashing or silently
                       // guessing (same pattern as VoteChoice/VoteResult).
}
```

All three non-fallback cases are **source-faithful raw strings**, quoted
verbatim from the actual cache (§7a) — not paraphrased or normalized —
matching the project's existing `TolerantStringEnum` convention (e.g.
`docs/v2/04-votes-import.md`'s `VoteChoice`/`VoteResult` precedent, cited
in `CLAUDE.md`'s constraint 4). `districtId` for every senator remains
`null` regardless of `MandateType` (§ GO/NO-GO(LINK) — no join exists
yet); Camera's existing `districtId` semantics are untouched.

**Elective-mandate evidence: direct, not derived.** The cache does **not**
carry a separate election-region/election-date field distinct from
`inizioMandato` (which is the same 2022-10-13 legislature-start date for
both elective and life senators alike — not itself an election signal).
But this doesn't force a derive-by-complement design: `osr:tipoMandato`'s
raw value is **literally the string `"elettivo"`** for 196 of 201
currently-serving bindings — a direct positive marker, quoted in §7a, not
inferred from "not a life senator." **The import will use the direct
`tipoMandato == "elettivo"` value**, not a complement of the life-senator
marker.

**Validator arithmetic** (to add to `tools/validate_data.py` alongside
the existing Camera/Senato/vote checks, when this is actually
implemented):

```
count(MandateType == .elettivo) + count(MandateType == .nominaAVita) == total senators (201)
```

Verified to hold exactly against the current cache: **196 + 5 = 201**.
Caveat, stated precisely rather than glossed over: this two-term equation
holds *specifically because* the third raw category
(`.diDirittoEAVita` — the Presidente-emerito case) has zero currently-serving
occurrences today (its one binding always co-occurs with a bound
`fineMandato` in this cache, so it's excluded by the existing
serving-filter before `MandateType` is even assigned). If a future
Presidente Emerito became an active life senator, the equation would need
a third term (`+ count(.diDirittoEAVita)`); the validator design should
either use `count(.elettivo) + count(.nominaAVita) + count(.diDirittoEAVita) == total`
from the start (robust to that case) or explicitly assert
`count(.diDirittoEAVita among serving) == 0` as its own separate check.
Recorded here as a documented design choice for whoever implements this,
not resolved by this read-only phase.

## Files added this phase

- `tools/probes/probe_senato_simplify.py` — tolerance sweep, reused for §5.
- `tools/probes/probe_senato_predicate_discovery.rq` — designed, not run;
  see §7b.
- `docs/v3/15-senato-exploration.md` — this report.
- `tools/probes/output/` (gitignored, per the Phase 14 convention) held
  the probe's intermediate GeoJSON files during this session; not
  committed.

No file under `Politici/`, `tools/queries/`, `tools/import_*.py`,
`tools/build_boundaries.sh`, `Makefile`, or any bundled `Politici/Data/*`
file was modified.
