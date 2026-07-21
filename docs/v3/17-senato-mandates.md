# V3 Phase 17 — Senator Mandates (MandateType) + Senato Collegio Linkage (GO-LINK)

Implements both halves of Phase 17 per the re-baseline r2: the fully
offline senator-mandate import from the existing cache, and — under the
GO(LINK) established by `docs/v3/15b-senato-link-probe.md` and an explicit
in-session user approval — the Senato-only refetch and collegio linkage
for the 73 uninominale-elected serving senators.

## Approval (quoted verbatim)

The network act (extending `tools/queries/senato_senatori.rq` with the
three probe-verified predicates and running `tools/fetch_senato.py`) was
presented as an explicit in-session choice between **"Approve refetch
(Recommended)"** and **"Withhold — mandate-only"**. The user selected:

> **"Approve refetch (Recommended)"**

The offline mandate half had already been implemented, built, and tested
green (117/117 runtime cases) *before* the question was asked, so the
withhold path would have shipped as-is with a documented linkage deferral.

## 1. Mandate half (offline, from the existing cache)

**Cache verification before implementing** (per the audit-first
methodology): the pre-existing `tools/raw/senato_senatori_sparql.json`
reproduced Phase 15's numbers exactly — 208 bindings, 201 serving (no
`fineMandato`), `tipoMandato` = 196 `"elettivo"` + 5 `"a vita, di nomina
del Presidente della Repubblica"` among serving, plus exactly one
non-serving `"di diritto e a vita, Presidente emerito della Repubblica"`
binding (Giorgio Napolitano, excluded by the fineMandato rule).

**What shipped:**

- `MandateType` tolerant enum (`Politici/Models/Representative.swift`),
  with the **three verbatim source raws** as raw values — `elettivo`,
  `nominaAVita = "a vita, di nomina del Presidente della Repubblica"`,
  `diDirittoEAVita = "di diritto e a vita, Presidente emerito della
  Repubblica"` — plus `.sconosciuto` as decode-time fallback only, never
  written by the pipeline.
- `Representative.mandate: MandateType?` — `decodeIfPresent`, so an absent
  key decodes to `nil` (not `.sconosciuto`). **Decision recorded: Camera
  records omit the key entirely** rather than carrying `null` — the Camera
  source has no equivalent concept, and this follows the
  chamber-conditional-key convention Phase 16 established for districts'
  `circoscrizione`/`regione`.
- `tools/import_representatives.py`: every senator record now carries
  `"mandate"` = the verbatim `tipoMandato` literal. A missing or
  out-of-vocabulary value **fails the import loudly**
  (`KNOWN_TIPO_MANDATO`) — no best-guess, no `"sconosciuto"` ever written.
- `tools/validate_data.py`: per-record checks (mandate required verbatim
  vocabulary on senators, forbidden on Camera records) plus the two
  phase-specified invariants: `count(elettivo) + count(nominaAVita) +
  count(diDirittoEAVita) == 201` (the robust three-term form) **and** the
  separate `serving diDirittoEAVita == 0` drift detector.
- Profile badge (`RepresentativeProfileView`) shown iff
  `mandate == .nominaAVita`.

**Badge wording decision (Open Q6, resolved in-phase):** the badge label
is **"A vita, di nomina del Presidente della Repubblica"** — the source's
own category phrasing verbatim (initial capital aside), exposed via
`MandateType.profileBadgeLabel` (non-nil only for `.nominaAVita`, unit
tested). Rationale: the Senato source provides **no gender field**
(`head.vars` audited in Phase 15 §6), gender inference from names is
forbidden, and "Senatore/Senatrice a vita" would require exactly that
inference — while the source's own category wording is gender-neutral by
construction and adds the appointment context ("di nomina del Presidente
della Repubblica") that a bare "a vita" would drop. Icon
`star.circle.fill`, purple capsule, same visual family as the existing
provenance badge. The badge appears on exactly the 5 life-senator profiles
(Cattaneo, Monti, Piano, Rubbia, Segre — verified by name against the
regenerated data) and no others, guaranteed jointly by the data (exactly 5
`nominaAVita` records) and the tested badge predicate.

**Data diff (generated-data protocol):** exactly 201 added `"mandate"`
lines in `Politici/Data/representatives.json`, zero other changes; every
other generated artifact byte-identical at this stage.

## 2. Refetch protocol execution (linkage half)

Checklist, in order, all executed on 2026-07-21:

1. **Legislature XIX re-verified at fetch time** — reused
   `tools/probes/probe_senato_legislature_currency.rq` via
   `tools/probes/run_probe.py` (aggregate-free form; output
   `legislature_currency_phase17.json`, gitignored). Result: 21 distinct
   values, **max integer legislature = 19**. XIX confirmed current;
   15b's 2026-07-20 check was treated as evidence, not a substitute.
2. **Query extension** — `senato_senatori.rq` gained exactly the 15b §4
   design: three `OPTIONAL` triples (`osr:tipoElezione`,
   `osr:regioneElezione`, `osr:collegioElezione`) and the three matching
   SELECT variables. Plain OPTIONALs only — no aggregates (endpoint
   rejects them, 15b §1–2).
3. **Minimal-scope fetch** — `python3 tools/fetch_senato.py` alone (not
   `make refresh`); the Camera and votes caches are untouched, keeping the
   `representatives.json` diff attributable to senator fields only.
4. **Before/after diff** — binding counts identical pre/post fetch
   (senatori 208, gruppi 206, commissioni 689). Post-fetch cache:
   208 bindings / 208 distinct senators / 201 serving; `tipoMandato`
   196 + 5 (serving); `tipoElezione` **73** `"Eletto uninominale dalla
   XVIII legislatura"` + 121 `"Eletto proporzionale dalla XVIII
   legislatura"` + 2 `"circoscrizioni estere"` + 5 absent (exactly the
   five life senators, by name); **73 collegio-bearing = the same 73
   uninominale senators, all 73 values distinct**. Every 15b number
   reproduced exactly — zero drift; the constants 73 and
   `MIN_LINKED_SENATO = 66` were therefore kept without modification.
5. **Manifest + provenance re-sync** — `sources.json`'s
   `senato-della-repubblica-xix-legislatura` `retrievedAt` moved to
   **2026-07-21** (the fetch ran just after local midnight — the approval
   conversation began 2026-07-20); `docs/DATA_SOURCES.md`, the
   working-cache `tools/raw/SOURCES.txt`, and its committed mirror
   `tools/SOURCES.md` all updated to match in this same commit. The other
   five source entries are unchanged.
6. **Boundary byte-identity** — `districts.geojson` and
   `districts_senato.geojson` show zero diff after the full
   `make all` re-run.

## 3. Linkage implementation

Exactly the 15b §4 design, in `tools/import_representatives.py`:

- **Eligibility**: `tipoElezione` starts with `"Eletto uninominale"`.
- **Parse rule**: substring before `" ("` (the parenthetical city detail
  can itself contain `" - "`), then `^(?P<regione>.+) - (?P<sub>U\d+)$`.
- **Match**: `(regione.upper(), subCode)` against the index built from
  `districts_senato.geojson`'s real `(regione, subCode) → id` pairs
  (`load_senato_uninominale_index`). **Deliberately strict**: plain
  `.upper()` equality, *not* Camera's accent-stripping
  `normalize_circoscrizione` — the looser normalization would silently
  absorb future naming drift; the strict form surfaces it as a loud
  failure. (The Camera normalizer would incidentally also have resolved
  Valle d'Aosta; strictness + one disclosed alias was chosen on purpose.)
- **Alias table**: exactly one entry, `"VALLE D'AOSTA"` → uppercased
  `"Valle d'aosta/Vallée d'Aoste"` (ISTAT's bilingual `SU20_DEN`; that
  region has exactly one Senato collegio, `S20001`, so zero ambiguity).
  Any *other* parse or match failure calls `fail()` — new variants must be
  verified and documented, never added ad hoc.
- **Duplicate-claim guard**: a second serving senator claiming an
  already-linked collegio fails the import (mirrors Camera's guard).
- **Gate**: `MIN_LINKED_SENATO = 66` (= ceil(0.9 × 73), same convention as
  `MIN_LINKED_COLLEGI = 133`), enforced before any file is written.
- The join logic was **dry-run as a standalone script against the fresh
  cache before being wired in** (per the verify-before-hardcoding
  methodology): 73/73 resolved, zero problems, no alias needed beyond
  Valle d'Aosta.

`tools/validate_data.py`'s `validate_linkage()` is now **per-chamber**: a
deputy's `districtId` must resolve to a Camera uninominale collegio and a
senator's to a Senato one (a cross-chamber assignment would be a real
defect even though the S-prefix makes id collisions impossible), with the
same one-representative-per-collegio check on each side. Output:
`147/147 Camera` and `73/74 Senato`.

**Result**: 73 of 201 serving senators carry an `S`-prefixed `districtId`;
128 (121 proporzionale + 2 estero + 5 a-vita) stay `null`, mirroring
Camera's plurinominale/estero pattern.

## 4. The uncovered collegio — identified by computation

`74 − 73 = 1`: **`S120002` — "Lazio - U02"**, computed at import time as
the single Senato uninominale collegio with no linked serving senator.

Additional finding (from inspecting the fresh cache, not assumed): **no
binding in the entire XIX-legislature result set — serving or former —
claims `LAZIO - U02` at all.** Lazio's serving uninominale senators claim
U01, U03, U04, U05, U06. So this is not a resignation/death gap in our
serving filter: the collegio is structurally unrepresented in the source
data itself, and the app's existing honest empty state ("Nessun
rappresentante collegato in questa versione del prototipo.") is exactly
right for it. No explanation for *why* the source has no claimant is
asserted here — that would be speculation; the computed fact is what the
data supports. For contrast, the Senato's one by-election case *is*
visible and coherent in this data: Silvio Berlusconi (deceased 2023-06-12,
`fineMandato` bound) formerly held `LOMBARDIA - U06 (MONZA)`, and serving
senator Adriano Galliani (mandate start 2023-10-30) now claims
`LOMBARDIA - U06` → linked to `S30006`.

## 5. App-side changes

- Linked senators surface through the **existing**
  `DistrictDetailView` → `representatives(for: districtId)` path — no new
  view code was needed for the district page itself (as Phase 16
  anticipated).
- Home "Come funziona l'elezione" explainer: the NO-GO-era bullet ("nessun
  senatore è ancora collegato…") replaced with the linked reality: 73 of
  74 collegi show their directly-elected senator, one collegio is
  currently without a serving senator in the official data, and
  proporzionale/estero/life senators are list-only. All strings Italian.
- README: the "Senato collegi are not rendered at all" limitation
  rewritten (now: 128 of 201 senators unmapped, with the 73-linked /
  one-empty-collegio reality); the v3-roadmap "Senato collegio boundaries"
  bullet marked **shipped in v3 (Phases 16–17)**; the explainer feature
  bullet's "(plurinominale/estero/Senato)" parenthetical corrected.
- `electionType` is untouched (grep-verified: the enum still has exactly
  its four v2 cases) and **no senator record carries a non-null
  `electionType`** (verified 0 in the shipped data).

**Open Q5 flagged to the user (default applied: keep null).**
`osr:tipoElezione` now exists in the cache for 196 senators, so senators'
`electionType` *could* be populated in a future phase — but mapping
`"Eletto proporzionale dalla XVIII legislatura"` onto Camera's
`plurinominale` case would be a new cross-chamber semantic best-fit
needing its own decision. Phase 17 consumes `tipoElezione` at import time
for linkage eligibility only; a V4 candidate otherwise.

## 6. Tests

Deliberate additions (+6 declared vs the post-16 baseline):

| Test | What it pins |
|---|---|
| `MandateTypeTests.testVerbatimMandateRawValuesDecode` | all three verbatim raws decode to the right cases |
| `MandateTypeTests.testUnknownMandateDecodesAsSconosciuto` | tolerant fallback |
| `MandateTypeTests.testAbsentMandateDecodesAsNil` | absence ≠ `.sconosciuto` (the Camera-record shape) |
| `MandateTypeTests.testProfileBadgeLabelIsOnlyForNominaAVita` | badge predicate + exact pinned Italian label |
| `SchemaV2Tests.testShippingSenatorsCarryVerbatimMandates` | shipping snapshot: 196/5/0, zero `.sconosciuto`, deputies all nil |
| `ServiceLookupTests.testRepresentativesForSenatoDistrictInSampleFixtureIsNonEmpty` | Senato district-detail linkage via the hand-known sample fixture |

Deliberate updates to existing tests (expectation changes driven by the
data change, each documented in its comment):

- `SchemaV2Tests.testSenatoRepresentativesAreUntouchedByLinkage` →
  **rewritten** as `testSenatoLinkageMatchesPhase17Import` (73 linked,
  all S-prefixed, ⊂ real Senato ids, exactly 1 uncovered collegio,
  electionType still `.sconosciuto` for all, life senators never linked).
- `SchemaV2Tests.testEveryNonNilShippingRepresentativeDistrictIsKnown`
  and `DecodingTests.testEveryNonNilRepresentativeDistrictReferencesAKnownDistrict`
  → the known-id set now unions both chambers' boundary files (they
  checked Camera-only and would otherwise have failed on the 73 S-ids);
  the latter's v2-era stale comment ("districtId is nil for every real
  representative") corrected, as was the same stale claim in
  `ServiceLookupTests`.

**Suite result: 118 runtime cases passed, 0 failures** — declared 115
(109 baseline + 6), runtime 118 (112 baseline + 6), the ×4
`testLaunch` gap cause unchanged. One passing case's log line was mangled
by parallel-test output interleaving in one run (`testPointClearlyInsideSquareIsContained`
— verified present-and-passed in the log body); an earlier run also hit a
one-off simulator-clone infrastructure failure (`PoliticiTests.xctest`
bundle failed to load on a cloned device; passed unchanged on re-run) —
neither is a code regression, both disclosed here rather than smoothed
over.

Verification trio: `build` **BUILD SUCCEEDED**; `simctl list` (iPhone 17
Pro used); `test` exit 0.

## 7. Acceptance criteria walk

1. ✅ 201/201 mandates, three verbatim raws, zero `.sconosciuto` written,
   deputies key-absent; data diff = exactly 201 `mandate` lines + 73
   `districtId` null→S-id lines, nothing else.
2. ✅ Validator three-term arithmetic + serving-emerito zero-assert, both
   computed (no vacancy constant asserted anywhere).
3. ✅ Refetch ran: 73 S-prefixed links, VdA-only alias, 66-gate passed,
   per-chamber validation green with Camera 147/147 unchanged; uncovered
   collegio `S120002` computed and named (§4).
4. ✅ Protocol checklist quoted (§2): XIX at fetch time, before/after
   diffs, manifest + `docs/DATA_SOURCES.md` + `tools/SOURCES.md` re-synced,
   boundary files byte-identical.
5. ✅ Badge on exactly the 5 life-senator profiles (data + tested
   predicate); linked Senato district pages show their senator through the
   existing path (fixture-tested); `S120002` keeps the honest empty state;
   explainer/README updated; all in-app strings Italian. Visual
   spot-checking in a live simulator was **not** performed in this
   headless session — the UI claims rest on the tested predicates plus the
   pre-existing, Phase 16-verified view paths (same disclosure class as
   `docs/v3/13-baseline-audit.md` §9; the 22A a11y pass lists the human
   checks).
6. ✅ Tests per §6, zero regressions beyond the documented deliberate
   updates.
7. ✅ `ElectionType` grep clean; 0 senators with non-null `electionType`.
8. n/a — approval was granted.
9. ✅ This report, committed in the phase commit.

## 8. Notes for later phases

- **`origin/v3` exists now** — the branch is tracking `origin/v3` and was
  up to date at phase start, contradicting the re-baseline §1 note (based
  on 13 §1) that it was never pushed. 22B's printed push commands should
  use plain `git push origin v3` (the `-u` first-push form is already
  satisfied) — verify at 22B time.
- README still carries pre-16-era staleness *outside* this phase's
  "no-senator-linked" line class (e.g. "tap either stat card ('Collegi
  campione' …)", the 147-only map/list feature bullets) — left for 22A's
  full refresh by scope discipline, listed here so it isn't lost.
- The importer's Senato linkage report prints vacant collegi on every run
  (`collegi Senato senza senatore corrente: 1: ['S120002']`) — future
  refetches will surface any change in the uncovered set automatically.
- New a11y surfaces for the 22A checklist: the a-vita profile badge
  (Label with full Italian text, part of the header's combined
  accessibility element) and linked-senator rows on Senato district pages
  (existing `RepresentativeRow`, already labeled).
