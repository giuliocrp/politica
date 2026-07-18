# v2 Phase 8 — Collegio Metadata Fix + Current-Deputy Linkage

Two things in one phase, because the second depends on the first: (A) the
`districts.geojson` boundary metadata is corrected to carry a truthful
`circoscrizione` instead of the misleading `region: "U01"` shipped in the
boundaries phase (`docs/v2/03-boundaries-audit.md`), and (B) each *current*
Camera deputy elected in a collegio uninominale is linked to their
`CU20_COD` id via `Data/representatives.json`'s `districtId`.

## Part A — Full shapefile schema, and where `circoscrizione` actually lives

`ogrinfo -so` on `CAMERA_CollegiUNINOMINALI_2020.shp` (full field list, not
just the three fields the boundaries phase used):

```
OBJECTID:   Integer64 (10.0)
CU20_COD:   Integer64 (10.0)
CU20_DEN:   String (150.0)
CU20_C1:    String (254.0)
Shape_Leng: Real (19.11)
Shape_Area: Real (19.11)
POP_2011:   Real (19.11)
```

**There is no dedicated circoscrizione field.** `OBJECTID` is just the row
index; `Shape_Leng`/`Shape_Area`/`POP_2011` are geometry/population
measures, not identifiers. So matching-ladder rung (1) from the task brief
("a dedicated attribute field") does not apply — confirmed, not assumed.

### Rung (2): parsing CU20_DEN

Every one of the 147 `CU20_DEN` values (e.g. `"Piemonte 1 - U01"`) splits
cleanly into `"{circoscrizione} - {CU20_C1}"` with **zero exceptions**
(verified programmatically across all 147 rows — the tail after `" - "`
matches `CU20_C1` exactly in every case). Taking the prefix yields exactly
**28 distinct values**:

```
Abruzzo, Basilicata, Calabria, Campania 1, Campania 2, Emilia-Romagna,
Friuli-Venezia Giulia, Lazio 1, Lazio 2, Liguria, Lombardia 1, Lombardia 2,
Lombardia 3, Lombardia 4, Marche, Molise, Piemonte 1, Piemonte 2, Puglia,
Sardegna, Sicilia 1, Sicilia 2, Toscana, Trentino-Alto Adige/Südtirol,
Umbria, Valle d'aosta/Vallée d'Aoste, Veneto 1, Veneto 2
```

This is **exactly** the official list of 28 Camera electoral circoscrizioni
established by D.Lgs. 177/2020 (Piemonte split into 2, Lombardia into 4,
Veneto/Lazio/Campania/Sicilia into 2 each, every other region a single
circoscrizione) — cross-checked against the Camera dei Deputati's own
published dossier on the decree. So this isn't a guess dressed up as a
parse rule: the prefix *is* the circoscrizione, by construction of the
source denominazione string, and independently corroborated by the
constitutional structure it's supposed to represent.

**Adopted rule**: `circoscrizione = CU20_DEN.rsplit(" - ", 1)[0]`,
`subCode = CU20_C1` (== the tail). Implemented in
`tools/import_boundaries.py`, with a hard failure if any future source
update ever produces a `CU20_DEN` that doesn't end in `" - {CU20_C1}"`.

### What changed in `Data/districts.geojson`

- `region` (previously = `CU20_C1`, misleadingly named — see
  `03-boundaries-audit.md`) → **removed**.
- `subCode` (= `CU20_C1`, e.g. `"U01"`) → **added**.
- `circoscrizione` (= the true circoscrizione, e.g. `"Piemonte 1"`) →
  **added**.
- `id`/`name`/`chamber`/`collegioType`/`provenance`/`sourceName` unchanged.
  Geometry/simplification tolerance unchanged (still 1000m; output still
  1131 KB, under the 3MB budget).
- `Politici/Models/District.swift`, `GeoJSONLoader.swift`,
  `tools/validate_data.py`'s `REQUIRED_DISTRICT_PROPERTY_KEYS` updated to
  match. No property named `region` containing `"U01"`-style values remains
  anywhere in the shipping data or the Swift model.
- `region` was never rendered in the app's UI (confirmed via `grep` across
  `Politici/Views/` before and after this phase), so there was no
  user-facing copy to correct.

## Part B — Linking current uninominale deputies

### Step 4: exploring the raw `?collegio` field first (before writing any matching code)

The existing `tools/queries/camera_deputati.rq` already had a `?collegio`
variable, bound via `?el dc:coverage ?collegio` where `?el` is the
mandate's election resource. Inspecting the **cached** raw response
(`tools/raw/camera_deputati_sparql.json`, no network) first:

- 55 distinct `?collegio` literals across all 1173 bindings, e.g.
  `"SICILIA 1 - P01"`, `"CAMPANIA 2 - P02"`, plus 4 Estero macro-area names
  (`"EUROPA"`, `"AMERICA MERIDIONALE"`, `"AMERICA SETTENTRIONALE E
  CENTRALE"`, `"AFRICA ASIA OCEANIA ANTARTIDE"`) and one bare
  `"VALLE D'AOSTA"`.
- **Critical finding**: every one of those 55 values uses a `P0N` suffix
  (or no suffix), never `U0N`. This `?collegio` field is the
  **plurinominale** collegio (the proportional-list grouping a deputy's
  list ran in) — the *same* granularity for both majoritarian and
  proportional winners. A plurinominale collegio contains anywhere from 1
  to 11 uninominale collegi (see the per-circoscrizione counts below), so
  this field **cannot by itself identify which specific uninominale
  collegio** a majoritarian winner represents. Rung (a) "code join" and the
  naive form of rung (b) both fail against this field alone — reported
  here rather than forced.

Live introspection against `https://dati.camera.it/sparql` (read-only
`SELECT DISTINCT ?p WHERE { ... }` queries enumerating predicates —
developer-tool network use only, per CLAUDE.md; the app itself makes no
such calls) turned up the fields actually needed:

- `?el ocd:tipoElezione ?tipo` — literal values `"maggioritario"`,
  `"maggioritario suppletiva"` (by-election replacement), or
  `"proporzionale"`. Exactly the distinction between a uninominale seat and
  a plurinominale/estero seat.
- `?el dcterms:spatial ?collegioUninominale` — **present only for
  maggioritario(-suppletiva) mandates**, giving the *exact* uninominale
  collegio as `"{CIRCOSCRIZIONE} - U0N"` (e.g. `"SICILIA 1 - U01"`) — the
  same granularity as `districts.geojson`'s `circoscrizione` + `subCode`.
  Confirmed absent for every proporzionale mandate sampled (0 of 15 tested
  had a bound `dcterms:spatial`).

Sample complete bindings (one per `tipoElezione` category, committed here
before any matching code was written):

```json
// maggioritario (uninominale winner)
{"cognome": "AIELLO", "nome": "DAVIDE", "collegio": "SICILIA 1 - P01",
 "tipoElezione": "maggioritario", "collegioUninominale": "SICILIA 1 - U01",
 "sigla": "M5S"}

// proporzionale (plurinominale list winner) — no collegioUninominale
{"cognome": "ALBANO", "nome": "LUCIA", "collegio": "MARCHE - P01",
 "tipoElezione": "proporzionale", "sigla": "FDI"}

// proporzionale, Estero coverage — no collegioUninominale
{"cognome": "BILLI", "nome": "SIMONE", "collegio": "EUROPA",
 "tipoElezione": "proporzionale", "sigla": "LEGA"}

// maggioritario suppletiva (by-election replacement)
{"cognome": "CENTENARO", "nome": "GIULIO", "collegio": "VENETO 2",
 "tipoElezione": "maggioritario suppletiva",
 "collegioUninominale": "VENETO 2 - U02", "sigla": "LEGA"}
```

Note the last example's `collegio` (dc:coverage) is bare `"VENETO 2"`, not
`"VENETO 2 - P0N"` — by-election coverage literals drop the plurinominale
suffix. A disclosed source-data quirk; irrelevant to linkage since
`collegioUninominale`/`dcterms:spatial`, not `collegio`, is the join key.

`tools/queries/camera_deputati.rq` was extended to select `?tipoElezione`
and `?collegioUninominale`, and to add `MINUS { ?mandato ocd:endDate
?fineMandato }` — restricting to the mandate currently held by each person
(excludes a since-replaced predecessor's row for a by-election collegio).
Verified this doesn't change the Camera total: 414 legislature-XIX mandati
exist, 14 have an `ocd:endDate` (ended), leaving exactly 400 — unchanged
from the previous phase's count.

### Step 5: current-mandate filtering results

After re-fetching with the updated query (`make fetch` step —
`tools/fetch_camera.py`, network, cache-only artifact): 400 distinct
`persona` bindings, `tipoElezione` breaks down as:

| tipoElezione | count |
|---|---|
| `maggioritario` | 145 |
| `maggioritario suppletiva` | 2 |
| `proporzionale` | 253 (245 plurinominale + 8 estero) |

145 + 2 = **147** — every one of the 147 uninominale collegi has exactly
one current holder, **0 currently vacant**.

**By-election (suppletiva) current holders** (2):
- Giulio Centenaro → collegio `50202` (Veneto 2 - U02)
- Alberto Di Rubba → collegio `50201` (Veneto 2 - U01)

Both are disclosed here per the task's explicit request, not silently
folded into the "ordinary maggioritario" bucket.

### Step 6: matching ladder — which rung succeeded

- **Rung (a) code join**: not applicable. Neither `?collegio` nor
  `?collegioUninominale` carries `CU20_COD` or any equivalent numeric code
  — both are human-readable denominazione text.
- **Rung (b) structural join — used, 147/147 (100%)**: parse
  `(circoscrizione, subCode)` from both `collegioUninominale`
  (`"SICILIA 1 - U01"` → `("SICILIA 1", "U01")`) and
  `districts.geojson`'s `circoscrizione`/`subCode` properties, normalize
  (uppercase, strip accents/punctuation, and — for the one bilingual
  circoscrizione name — take the Italian-only segment before `"/"`), and
  join on the pair. Verified as a **complete, exact bijection** across all
  147 shapefile collegi before writing it into `import_representatives.py`:
  147 shapefile keys, 147 SPARQL keys, 147 matched, 0 unmatched either
  direction.
- **Rung (c) normalized-denomination fallback**: implemented as a
  documented no-op — not reached, because rung (b) resolved all 147 with
  zero ambiguity. No non-exact/ambiguous case exists to list.

**The one normalization wrinkle**, caught and verified rather than
assumed: `districts.geojson`'s circoscrizione for Valle d'Aosta is
`"Valle d'aosta/Vallée d'Aoste"` (ISTAT's bilingual official name), while
SPARQL's `collegioUninominale` for the same collegio is the Italian-only
`"VALLE D'AOSTA - U01"`. The normalization function splits on `"/"` and
keeps the first segment before comparing — verified this doesn't cause any
false collision across the other 27 circoscrizioni (none of which contain a
`/`), and Valle d'Aosta has exactly one uninominale collegio on both sides,
so there was no ambiguity to begin with even before normalization.

### Step 7 — `Data/representatives.json` classification rule

- `tipoElezione` ∈ {`maggioritario`, `maggioritario suppletiva`} →
  `electionType: "uninominale"`, `districtId` = the matched `CU20_COD`.
- `tipoElezione` = `proporzionale` and `collegio` (dc:coverage) is one of
  the 4 Estero macro-areas → `electionType: "estero"`, `districtId: null`.
- `tipoElezione` = `proporzionale` otherwise → `electionType:
  "plurinominale"`, `districtId: null`.
- Senato: **untouched** — no Senato boundaries exist in this app
  (out of scope, see `03-boundaries-audit.md`), so every Senato record
  keeps `districtId: null` / `electionType: null` exactly as before.

Resulting Camera breakdown (400 total, unchanged from the previous phase):
**147 uninominale, 245 plurinominale, 8 estero**.

### Step 8 — linkage summary / quality gate

| | |
|---|---|
| Uninominale collegi with a current deputy linked | **147 / 147 (100%)** |
| Colleges with exactly one deputy | 147 (all of them) |
| Colleges with zero current deputies (vacant) | **0** |
| Ambiguous matches (non-exact, listed not auto-resolved) | **0** |
| `electionType == "uninominale"` count vs. expected ~147 | 147 — exact match, no deviation to explain |
| Quality gate (`≥ 133/147`, 90%) | **PASSED** (147 ≥ 133) — data committed |

`make import`'s own run (`tools/import_representatives.py`) printed the
same figures at generation time:

```
Collegamento collegio uninominale -> deputato: 147/147
  deputati subentrati per elezione suppletiva: 2
    - Giulio Centenaro (collegio 50202)
    - Alberto Di Rubba (collegio 50201)
OK: 601 rappresentanti scritti in Politici/Data/representatives.json (400 Camera, 201 Senato)
```

The gate (`MIN_LINKED_COLLEGI = 133` in `import_representatives.py`) is
enforced in code: if the linked count ever drops below 133 on a future
re-fetch, the script fails loudly and writes nothing to
`Data/representatives.json`, rather than committing a partially-linked
file silently.

## Adapted plan

No deviation from the task brief was needed: rung (b) of the matching
ladder resolved all 147 collegi cleanly, so rung (c)'s
normalized-denomination fallback and the spatial-join-against-ISTAT-regioni
escape hatch were never invoked. The one genuine surprise was that the
*existing* `?collegio` SPARQL variable (already wired into
`camera_deputati.rq` and named suggestively) turned out to be the wrong
granularity entirely (plurinominale, not uninominale) — this was caught by
exploring the cached raw data *before* writing any matching code, exactly
as the task required, rather than discovered after building against it.
