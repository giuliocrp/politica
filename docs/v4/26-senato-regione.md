# V4 Phase 26 — Senato Regione Context + Senator `electionType` Decision [GO-REG: **GO**]

The Phase-18 analog for the Senato. Every elective senator gains a `regione`
derived from the source's `osr:regioneElezione`, Senato collegio pages gain a
"Senatori proporzionali della regione {name}" section, senator profiles gain a
"Regione: {name}" line — and the deferred senator-`electionType` decision is
taken here (its owning phase) with explicit user approval.

**Network acts: none.** Everything below was derived from the existing,
committed-as-cache `tools/raw/senato_senatori_sparql.json` (unchanged since
Phase 17's Senato-only refetch), the shipped `districts_senato.geojson`, and
the shipped `representatives.json`. No SPARQL fetch, no download, no user
network gate was needed or invoked. The one user gate this phase carries is the
`electionType`-mapping decision (§3), not a network act.

---

## 1. Preconditions

| Precondition | Verified how | Result |
|---|---|---|
| Phase 23 done (the phase's dependency) | `docs/plan/README.md` row 23 links `../v4/23-baseline-audit.md` | **met** |
| Working tree clean at start | `git status --porcelain` → empty | **met** |
| Branch / tip | `v4`, tip `b6f70b2` (Phase 25a doc-sync commit) | **met** |
| `regioneElezione` present for all 196 elective serving senators | GO-REG probe (a): 196 with, 5 a-vita without | **met** |
| 20 shipped regione values in `districts_senato.geojson` | probe reads them from the file, not a hardcoded list | **met** |
| `.fetch_metadata.json` cache present (so `make manifest` won't churn `retrievedAt`) | `ls tools/raw/.fetch_metadata.json` present; `sources.json` `generatedAt` already `2026-07-22` | **met** |
| GDAL for the byte-identity re-run of boundaries | `ogr2ogr --version` → GDAL 3.13.1 (Phase 25's version) | **met** |

---

## 2. The GO-REG gate — per-condition evidence

A committed, re-runnable offline probe —
`tools/probes/probe_senato_regione.py` (output not applicable; it prints, per
the probes convention it imports the linkage machinery from
`import_representatives.py` rather than re-implementing it) — was written and
run **before** any importer/model/UI change. Verbatim output:

```
========================================================================
Fase 26 — sonda contesto regione Senato (GO-REG)
========================================================================

Valori regione spediti (districts_senato.geojson): 20

--- (a) copertura elettiva regioneElezione ---
  senatori in carica: 201
  mandate elettivo: 196   non-elettivo (a-vita/emerito): 5
  con regioneElezione: 196   senza: 5
  insieme(elettivo) == insieme(con regioneElezione): True
  (a) OK — 196/196 elettivi con regioneElezione, 5 a-vita senza

--- (b) mappatura regioneElezione domestico -> regione spedita ---
  valori domestici mappati per uguaglianza esatta: 18 distinti
  valori domestici mappati via alias bilingue:
    'Trentino-Alto Adige' (6) -> 'Trentino-Alto Adige/Südtirol'
    "Valle D'Aosta" (1) -> "Valle d'aosta/Vallée d'Aoste"
  valori estero (non geografici, gestiti separatamente): ['AFRICA ASIA OCEANIA ANTARTIDE', 'EUROPA']
  (b) OK — 20 regioni domestiche distinte, 0 non mappate

--- (c) coerenza regione derivata vs collegio (73 uninominali) ---
  senatori uninominali: 73
  collegioElezione Trentino in forma bilingue (/SÜDTIROL): 6
  (c) OK — 73/73 regione derivata == regione del collegio

--- contesto decisione electionType ---
   121  'Eletto proporzionale dalla XVIII legislatura'
    73  'Eletto uninominale dalla XVIII legislatura'
     2  'circoscrizioni estere'
     5  None
  mappatura raccomandata -> uninominale 73 / plurinominale 121 / estero 2 / (a-vita null 5)
  coerenza estero: insieme(tipoElezione estere) == insieme(regioneElezione estera): True (2)

========================================================================
GO-REG: condizioni (a)-(c) verificate.
========================================================================
```

Condition by condition:

- **(a) 196/196 elective coverage re-verified at import time — PASS.** All 196
  `mandate == elettivo` serving senators carry `osr:regioneElezione`; the 5
  a-vita don't; and the two sets are **identical** (`insieme(elettivo) ==
  insieme(con regioneElezione): True`) — so "elective" and "has regioneElezione"
  are the same 196 senators, which is what lets the a-vita key-omission rule be
  stated as `regione` present ⇔ `mandate == elettivo`.

- **(b) Every domestic value maps to exactly one of the 20 — PASS.** 18 of the
  20 domestic regioni match by **strict `.upper()` equality**; the other 2 need
  a bilingual alias (the anticipated candidate class):
  - **`"Valle D'Aosta"` → `"Valle d'aosta/Vallée d'Aoste"`** — already in
    Phase 17's `SENATO_REGIONE_ALIASES`.
  - **`"Trentino-Alto Adige"` → `"Trentino-Alto Adige/Südtirol"`** — a **new**
    per-entry-verified alias. It was not needed by Phase 17's linkage because
    `osr:collegioElezione` already carries the bilingual form for Trentino
    (`TRENTINO-ALTO ADIGE/SÜDTIROL - U0N`), whereas `osr:regioneElezione` gives
    the Italian-only `Trentino-Alto Adige`. Each region has exactly the expected
    number of collegi, so both aliases are unambiguous. Any *other* unmapped
    domestic value fails the import loudly.

- **(c) Derived regione == the linked collegio's regione — PASS.** For all
  **73/73** uninominale senators, the regione derived from `regioneElezione`
  equals the collegio's shipped `regione` property (exact string equality on
  canonical values). The probe confirmed Trentino's `collegioElezione` is
  bilingual in all 6 cases, so it resolves through the linkage index without the
  new alias — the alias is load-bearing **only** on the `regioneElezione` side.

**Decision: GO.** All three conditions verified; probe exits 0. (A NO-GO would
have shipped as report + probe only, with no importer change.)

### A defect the probe's own strictness caught — in the probe, not the data

On its first run the probe reported a single (c) mismatch: the Valle d'Aosta
uninominale senator, `collegio=None`. Root cause (diagnosed, not smoothed over):
the probe's (c) collegio lookup had failed to apply the regione alias the way
Phase 17's `link_senato_collegio` does — Valle d'Aosta's `collegioElezione` is
Italian-only (`VALLE D'AOSTA - U01`), so the raw uppercase key missed the
bilingual geojson index entry. The **importer's** real linkage already applies
the alias before the lookup; the fix was to mirror that in the probe (one line),
not to loosen the assertion. Re-run: 73/73 clean, GO. The data was consistent
all along.

---

## 3. Decisions recorded

- **`regione` field policy — the Senato mirror of Camera's `circoscrizione`.**
  Present on a senator **iff** they were elected in a regione (the 196 with
  `regioneElezione`, i.e. `mandate == elettivo`), stored in
  `districts_senato.geojson`'s own canonical casing so the (c) cross-check is
  exact string equality and the profile line display-matches the district
  pages. The 5 a-vita senators and every Camera record **omit the key**
  (absent, not null) — the chamber/field-conditional-key convention.

- **The 2 estero senators → pinned `"Estero"` (present), not key-absent.** Their
  `regioneElezione` values (`EUROPA`, `AFRICA ASIA OCEANIA ANTARTIDE`) are estero
  constituency names, not regioni, so they must never match a geographic regione;
  they are collapsed to `"Estero"` exactly as Camera Phase 18 collapses its
  estero deputies' 4 macro-constituencies to `circoscrizione: "Estero"`. Chosen
  over the also-offered key-absent option because: (i) the objective says "every
  elective senator gains regione" — the 2 estero senators are elective; (ii) it
  keeps cross-chamber parallelism (a Camera estero deputy shows
  "Circoscrizione: Estero", a Senato estero senator "Regione: Estero"); (iii) it
  matches test spec 2's "shipped set (∪ the estero decision's value)" wording.
  `"Estero"` is source-disclosed (the constituency category), not fabricated —
  the same disclosed-collapse class as Camera's. The grouping and pages never
  surface it as a geographic regione (there is no `"Estero"` geojson feature).

- **Two bilingual aliases only, both per-entry verified** (§2b). The alias table
  extends only with the same per-entry evidence the 15b/26 probes produced;
  bilingual names are the sole verified variant class. Any other mismatch fails
  the import loudly.

- **The deferred senator-`electionType` decision — TAKEN, with user approval.**
  This phase owns it. The decision was flagged to the user before any importer
  change, with keep-null offered as the alternative. **User approval, quoted
  verbatim:**

  > **"Approve mapping (Recommended)"**

  (Selected from a two-option choice — "Approve mapping (Recommended)" vs "Keep
  null" — with the preview shown to the user:
  `Eletto uninominale… → .uninominale (73); Eletto proporzionale… →
  .plurinominale (121); circoscrizioni estere → .estero (2); (a-vita, absent) →
  .sconosciuto (5)`.)

  The mapping is a **disclosed cross-chamber best fit** onto the Camera
  `ElectionType` vocabulary — the same precedent class as the votes import's
  `"Non ha votato"` → `.assente` (a documented best fit, not an assertion of
  identity). `"Eletto proporzionale…"` → `.plurinominale` because the Senato's
  proportional route is the cross-chamber analog of the Camera's plurinominale
  list seats. The 5 a-vita senators have no `tipoElezione` at all, so
  `electionType` stays absent → `.sconosciuto` at decode, honestly reflecting
  "not elected".

---

## 4. Pipeline changes

### 4.1 Importer (`import_representatives.py`)

- `SENATO_REGIONE_ALIASES` gained the Trentino-Alto Adige entry (with a comment
  explaining why it's needed only on the regione side, not the linkage side).
- `load_senato_uninominale_index()` now also returns `canonical_regioni`
  (`regione.upper()` → shipped casing) and `regione_of_district` (id → shipped
  regione) — mirroring `load_uninominale_index`'s 4-tuple for Camera.
- New `derive_regione()` (the Senato analog of `derive_circoscrizione`): returns
  the canonical regione, `"Estero"` for the overseas senators, or `None` when
  `regioneElezione` is absent (a-vita); any unmapped domestic value fails loudly.
- New `derive_senato_election_type()`: the approved `osr:tipoElezione` →
  `ElectionType` mapping, with a loud failure on any value outside the three
  known prefixes/literals (so a new vocabulary can't silently miss to `None`).
- `import_senato()` now captures `regioneElezione`, derives `electionType` and
  `regione` per senator, sets `record["electionType"]` (was hardcoded `None`),
  adds the key `regione` only when non-`None`, and **cross-checks (c) at import
  time**: a linked senator's derived regione must equal their collegio's shipped
  regione, else fail. New summary prints for regione coverage and the Senato
  electionType distribution.

### 4.2 Validator (`validate_data.py`)

- Per-record chamber/field-conditional checks: `regione` forbidden on Camera;
  on Senato present ⇔ `mandate == elettivo` (forbidden on a-vita), non-empty
  when present.
- Aggregate drift detectors: exactly **196** senators carry `regione`; the
  approved Senato distribution **73 / 121 / 2** (+ 5 null); and the
  `regione == "Estero"` set == `electionType == "estero"` set (the Senato mirror
  of Camera's estero correspondence).
- New `validate_regione()` (the Senato mirror of `validate_circoscrizione()`):
  every senator's `regione` is `"Estero"` or one of `districts_senato.geojson`'s
  own regione values (reference set read from the real data, not hardcoded), and
  every linked senator's regione equals their collegio's property — condition
  (c) re-enforced at validation time.

### 4.3 Generated-data protocol — every change explained

`make all` (fully offline) is reproducible and green. The complete
`Politici/Data/` diff:

| File | Change | Explanation |
|---|---|---|
| `representatives.json` | **+392, −196** | classified line-by-line: **196 `regione` added** + **196 `electionType` value changes** (null → value). All 196 changed records are senators (0 Camera). Distribution of the electionType changes: 121 plurinominale + 73 uninominale + 2 estero. The 5 a-vita keep `electionType: null` and carry no `regione` (unchanged). The 2 estero senators' `regione` is `"Estero"`. |
| `districts*.geojson` (all four), `votes.json`, `sources.json` | **byte-identical, zero diff** | confirmed by `git diff --stat` (only `representatives.json` listed); `sources.json` `generatedAt` was already `2026-07-22`, and no source was added, so `make manifest` left it and every `retrievedAt` byte-identical |

`make validate` (relevant new lines):

```
  senatori per tipo: uninominale 73  plurinominale 121  estero 2  (a-vita/null 5)
  senatori con regione: 196
OK: regioni senatori coerenti — 21 valori osservati (21 ammessi: 20 da districts_senato.geojson + 'Estero')
```

No attribution change was needed (no new source); `docs/DATA_SOURCES.md`,
`tools/SOURCES.md`, and the manifest are untouched.

---

## 5. App changes (all user-facing strings Italian)

- **`Representative.regione: String?`** — decoded/encoded `IfPresent`,
  absent-tolerant like `mandate`/`circoscrizione`/`collegioPlurinominale`.
- **`RepresentativeService.proporzionaleSenators(inRegione:)`** — a pure static
  grouping (`chamber == .senato && electionType == .plurinominale && regione ==
  name`, name-sorted), the exact mirror of the Camera
  `plurinominaleRepresentatives(inCircoscrizione:)`. Filtering on
  `.plurinominale` keeps the region's uninominale senators out of its
  proporzionale section, and the a-vita (nil regione) and estero (`.estero`,
  `"Estero"` regione) senators off every geographic page.
- **`DistrictDetailView`** — a Senato uninominale collegio page now gets a
  `proporzionaleSenatoriSection` (the mirror of the Camera `plurinominaleSection`),
  listing the regione's proporzionale senators or an honest empty state.
  Uninominale/plurinominale Camera pages and the Senato plurinominale page are
  unchanged.
- **`RepresentativeProfileView`** — a `"Regione: {name}"` line whenever the
  senator carries the field (estero senators honestly show `"Regione: Estero"`),
  placed directly below the Camera-only `"Circoscrizione: {name}"` line inside
  the header's combined accessibility element.

### Pinned Italian strings (new)

| Where | String |
|---|---|
| Senato proporzionale section (header) | "Senatori proporzionali della regione {regione}" |
| …caption | "Eletti con il sistema proporzionale su base regionale: rappresentano l'intera regione, non questo specifico collegio uninominale." |
| …empty state | "Nessun senatore proporzionale in questa regione." |
| Profile line | "Regione: {regione}" |

---

## 6. Tests

Sample fixtures were **not** extended: `representatives.sample.json` is frozen
(the grouping tests build their own JSON fixtures), and it carries no regione
key, decoding to `regione == nil` — consistent with the absent-key convention.

Deliberate additions (**+6** vs the Phase 25 baseline of 158):

| Test | Pins |
|---|---|
| `RegioneTests.testRegioneDecodesWhenPresent` | field decode |
| `RegioneTests.testAbsentRegioneDecodesAsNil` | absence → nil (a-vita / Camera shape) |
| `RegioneTests.testGroupingReturnsOnlyProporzionaleSenatorsOfTheRegione` | pure grouping: same-regione uninominale, other regione, estero, a-vita, and a Camera plurinominale deputy all excluded; name-sorted |
| `RegioneTests.testGroupingForEsteroRegioneNeverReturnsAnyone` | estero excluded by electionType even when queried by "Estero" |
| `RegioneTests.testGroupingForUnknownRegioneIsEmpty` | unknown regione → empty |
| `SchemaV2Tests.testShippingSenatorsCarryCanonicalRegioni` | shipping bundle: 196 carry regione, values ⊆ 20 ∪ {"Estero"}, linked-senator equality (c), estero↔"Estero" (2), a-vita nil, deputies nil, 73/121/2 distribution |

Deliberate updates to existing tests (each documented in its comment, driven by
the approved electionType change — listed per-test per plan rule 5):

- `SchemaV2Tests.testSenatoLinkageMatchesPhase17Import` → the "electionType
  stays `.sconosciuto` for every senator" assertion is **replaced** by the
  approved distribution (73 uninominale / 121 plurinominale / 2 estero / 5
  `.sconosciuto`) plus the uninominale⇔linked equivalence. This is the exact
  test the phase file named as becoming a deliberate documented update if the
  mapping shipped.
- `SchemaV2Tests.testUninominaleElectionTypeCountMatchesLinkedDistrictCount` →
  **scoped to Camera** (`chamber == .camera && electionType == .uninominale`).
  Senators now also carry `.uninominale` (73), so the previously-unscoped filter
  would count 147 + 73 instead of 147.

Both grouping functions that pre-date this phase stay chamber-scoped
(`chamber == .camera`), so senators newly carrying `.plurinominale`/`.uninominale`
cannot leak into a Camera page — verified green (see below).

### Suite result

Run on `iPhone 17 Pro` (result bundle authoritative):

```
$ xcrun xcresulttool get test-results summary --path p26final.xcresult
  "failedTests" : 0,
  "passedTests" : 164,
  "result" : "Passed",
  "skippedTests" : 0,
  "totalTestCount" : 164
```

Exit code 0; `** TEST SUCCEEDED **`. `totalTestCount` **164** = the Phase 25
baseline **158** + the **6** deliberate additions above. Declared == runtime,
as since Phase 24: re-derived from source with the Phase 23/24 rule, **164**
(152 `func test` + 1 `@Test` + 11 UITests). The two Phase 24 UI smoke flows that
open the Lazio Senato collegio page and drive the `ChamberPicker`
(`testSenatoCollegioDetailAndLifeSenatorMandateBadge` and the plurinominale
flow) passed unchanged — the new `district.section.proporzionaleSenato` section
uses a distinct identifier from the Camera `district.section.plurinominale`, so
the Senato flow's `assertFalse(plurinominale.exists)` still holds.

(An earlier full run against source that predated the HomeView-explainer edit
and a cosmetic test-method rename was also green — 164/164 — the numbers are
identical because neither change alters any test's logic or the runtime count.)

---

## 7. Acceptance criteria walk

1. **Probe evidence per gate condition, both outcomes supported** — §2, GO
   (NO-GO would have been report + probe only). (a)/(b)/(c) each evidenced with
   quoted values; the probe supports NO-GO via a non-zero exit.
2. **Shipping tests**: all elective senators carry a non-nil canonical regione
   within 20 ∪ {"Estero"}; a-vita nil; all deputies nil; linked-senator equality
   per (c) — §6 (`testShippingSenatorsCarryCanonicalRegioni`).
3. **Pure grouping tests on hand-built fixtures**: proporzionale-only; excludes
   uninominale of the same regione, a-vita, estero; name-sorted; unknown regione
   → empty — §6 (`RegioneTests`).
4. **Mapping shipped**: the 73/121/2 distribution test ships
   (`testShippingSenatorsCarryCanonicalRegioni` + the updated
   `testSenatoLinkageMatchesPhase17Import`); the user approval is quoted verbatim
   in §3.
5. **UI strings pinned, Italian; suite green against the current baseline** —
   §5, §6.

### Deviations, stated plainly

1. **A second bilingual alias was needed (Trentino-Alto Adige), not just Valle
   d'Aosta.** The phase file's gate wording named "the Valle d'Aosta-alias
   rule"; the probe found a second bilingual variant on the `regioneElezione`
   side. This is exactly the anticipated failure mode — the gate text says
   "bilingual names are the likely candidates" and "the alias table extends
   only with per-entry verified evidence" — so it was added with that evidence
   (§2b), not treated as a NO-GO. Documented as a `SENATO_REGIONE_ALIASES` entry
   with its own comment.
2. **The HomeView "Come funziona" Senato explainer was updated** beyond the
   phase file's explicit deliverable list (district section + profile line),
   because this phase changes *where* proporzionale senators are visible: the
   old bullet said they were "consultabili nell'elenco dei rappresentanti"
   (implying list-only), which this phase makes stale. The Phase-18 analog
   updated the same explainer for the Camera side, so the Senato side was
   brought into parallel rather than left mildly inaccurate. No test pins that
   copy (grep-verified).
3. **The probe's own (c) check had a one-line bug** (missing alias application
   in the collegio lookup) that its strictness surfaced on first run; fixed to
   mirror the importer's linkage, not by loosening the assertion (§2). The data
   was consistent throughout.
