# V3 Phase 18 — Plurinominale / Estero Representation Context [GO-CIRC: **GO**]

Fully offline phase: everything below was derived from the cached
`tools/raw/camera_deputati_sparql.json` (untouched by Phase 17's
Senato-only refetch), the shipped `districts.geojson`, and the shipped
`representatives.json`. The gate was evaluated by a committed, re-runnable
probe (`tools/probes/probe_camera_coverage.py`, output gitignored per the
probes convention) **before** any importer/model/UI change was written.

## The GO-CIRC gate — per-condition evidence

**Parse rule under test** (explicit, source-backed): a deputy's
`dc:coverage` literal is (1) one of the 4 estero macro-constituency names
(the v2-verified `ESTERO_COVERAGE_VALUES`) → `"Estero"`; else (2)
`"{CIRCOSCRIZIONE} - P\d+"` → the prefix; else (3) a bare circoscrizione
name. Domestic names resolve to the canonical shipped value via
`normalize_circoscrizione` — the same Phase 8 normalization the
uninominale linkage has used since v2, imported by the probe from
`import_representatives.py`, not reimplemented.

**(a) Every literal parses, zero unexplained failures — PASS.** 400/400
deputies carry exactly one coverage literal; 55 distinct values: 49
suffixed (`" - P0N"`), 4 estero, 2 bare. The 3 bare *instances* (2 values)
are each structurally explained, verbatim:

```
"VALLE D'AOSTA" -> p308760 (MANES, maggioritario, "VALLE D'AOSTA - U01")
'VENETO 2'      -> p309321 (CENTENARO, maggioritario suppletiva, 'VENETO 2 - U02')
'VENETO 2'      -> p309320 (DI RUBBA,  maggioritario suppletiva, 'VENETO 2 - U01')
```

Valle d'Aosta is the one circoscrizione with **no plurinominale collegio
at all** (its single seat is uninominale), so the source has no `" - P0N"`
to attach; the two bare `VENETO 2` records are **exactly the two
"maggioritario suppletiva" deputies** — by-election mandates carry the
bare circoscrizione. This confirms the v2 narrative (55 values, P0N
suffixes, suppletiva bare) which the plan had explicitly demoted to
hypothesis until enumerated.

**(b) Parsed set lands exactly within the 28 shipped values ∪ {"Estero"}
— PASS.** Derived domestic circoscrizioni: **28/28** present in
`districts.geojson` (not merely a subset — every shipped circoscrizione is
also observed), plus `"Estero"`; 29 observed values total, 29 admitted.

**(c) Uninominale cross-check — PASS.** For all **147/147** linked
uninominale deputies, the coverage-derived circoscrizione equals their
linked collegio's shipped `circoscrizione` property exactly (the probe
compares canonical string to canonical string; the importer now re-checks
this on every run and fails loudly on mismatch).

**(d) Unambiguous mapping — PASS.** Zero deputies carry more than one
distinct coverage value across their bindings, and the 28 shipped
circoscrizione values normalize to 28 distinct keys (no normalization
collision — reconfirming the Phase 8 finding).

**(e) Estero explicitly identifiable — PASS.** Exactly **8** deputies
carry one of the 4 estero constituency names (`EUROPA`, `AMERICA
MERIDIONALE`, `AMERICA SETTENTRIONALE E CENTRALE`, `AFRICA ASIA OCEANIA
ANTARTIDE`) as their own coverage value — identified by that value, not by
parse-failure elimination — and all 8 are `tipoElezione` "proporzionale".

**Decision: GO.** All five conditions verified; probe exits 0.

## Decisions recorded

- **`collegioPlurinominale` second field: not added.** The P0N code is
  cleanly derivable for 397 of 400 deputies but structurally absent for
  the 3 bare-coverage records (Valle d'Aosta + the 2 suppletiva), no UI
  consumer exists for it, and a field that's null for exactly the
  hard-to-explain records adds schema weight without value. Deferred until
  something actually needs it.
- **Canonical casing storage.** The derived value is stored in
  `districts.geojson`'s own casing (e.g. `"Valle d'aosta/Vallée
  d'Aoste"`, `"Piemonte 1"`), not the SPARQL uppercase form — this makes
  the (c) cross-check exact string equality and the profile line
  display-identical to the district pages.
- **Chamber-conditional key.** `circoscrizione` is required on every
  Camera record and absent (not null) on every Senato record — the exact
  mirror of Phase 17's `mandate` convention, enforced by the validator in
  both directions. It is never `regione`, which remains Senato's distinct
  concept.
- **Importer bare-value policy encodes the explanation, not the
  snapshot**: bare coverage is accepted iff the value is Valle d'Aosta
  (structural) or the mandate is "maggioritario suppletiva" (structural) —
  a future by-election elsewhere won't crash the pipeline, but any *other*
  new bare pattern fails loudly for review.

## What shipped

*tools:* `probe_camera_coverage.py` (the gate, committed);
`import_representatives.py` (`derive_circoscrizione` with loud-fail
branches, the import-time (c) cross-check, `load_uninominale_index`
extended to return the canonical map + per-district circoscrizione,
summary print); `validate_data.py` (chamber-conditional key checks; the
measured 147/245/8 electionType distribution as expected constants;
estero↔"Estero" set-equality check; new cross-file
`validate_circoscrizione()` — value set checked against districts.geojson
itself, not a hardcoded list, plus per-linked-deputy equality).

*data:* `representatives.json` only — the diff is exactly **400 added
`"circoscrizione"` lines**, zero other changes (verified by diff-line
classification); senators carry no key (verified 0).

*app:* `Representative.circoscrizione: String?`;
`RepresentativeService.plurinominaleRepresentatives(inCircoscrizione:)`
with the grouping logic as a **static pure function** (filters
`chamber == .camera && electionType == .plurinominale && circoscrizione
== name`, sorted by name — the electionType filter keeps estero deputies
off every geographic page even hypothetically, and uninominale deputies
out of their own circoscrizione's plurinominale list);
`DistrictDetailView`: Camera pages' elected-representative header is now
the pinned `"Eletto nel collegio uninominale"` (Senato pages keep
`"Rappresentanti eletti"` — Phase 18 is Camera-only by scope), plus the
new section `"Rappresentanti plurinominali della circoscrizione {name}"`
with explanatory caption (`"Eletti con il sistema proporzionale nei
collegi plurinominali della circoscrizione: rappresentano l'intera
circoscrizione, non questo specifico collegio uninominale."`) and an
honest empty state (`"Nessun deputato plurinominale in questa
circoscrizione."` — currently reachable only on the Valle d'Aosta page,
whose circoscrizione structurally has no plurinominale deputies);
`RepresentativeProfileView`: `"Circoscrizione: {name}"` line whenever the
field is present (estero deputies honestly show `"Circoscrizione:
Estero"`); `HomeView` explainer bullet extended to state that Camera
district pages now show their circoscrizione's plurinominale deputies and
that estero deputies remain list-only. All strings Italian.

## Tests

Deliberate additions (+6 declared vs the post-17 baseline):

| Test | What it pins |
|---|---|
| `CircoscrizioneTests.testCircoscrizioneDecodesWhenPresent` | field decode |
| `CircoscrizioneTests.testAbsentCircoscrizioneDecodesAsNil` | absence → nil (the Senato-record shape) |
| `CircoscrizioneTests.testGroupingReturnsOnlyPlurinominaleDeputiesOfTheCircoscrizione` | pure grouping on hand-built fixtures: same-circoscrizione uninominale, other-circoscrizione, estero, and Senato records all excluded; name-sorted |
| `CircoscrizioneTests.testGroupingForEsteroNeverReturnsAnyone` | estero excluded by type even when queried by "Estero" |
| `CircoscrizioneTests.testGroupingForUnknownCircoscrizioneIsEmpty` | unknown value → empty |
| `SchemaV2Tests.testShippingDeputiesCarryCanonicalCircoscrizioni` | shipping bundle: complete coverage, value set ⊆ 28 ∪ {"Estero"}, linked-deputy equality, 147/245/8, estero set-equality, senators key-free |

No existing test needed its expectation changed (unlike Phase 17 — this
field is purely additive).

**Suite: 124 runtime cases passed, 0 failures** — declared 121 (109
baseline + 6 Phase 17 + 6 here), runtime 124 (112 + 12), ×4 `testLaunch`
cause unchanged. Two disclosed anomalies, both investigated rather than
waved off: (1) one run failed only `PoliticiUITests.testExample()` (the
template boilerplate) while all five other app launches in the same run
passed and the log showed the environment's recurring
`xcrun … simctl not found` diagnostics error — reproduced clean on
re-run, same simulator-clone infrastructure flake class as Phase 17's;
(2) in the green run, `testAccessibilityLabelsMatchTheSpecifiedItalianCopy`'s
log line was truncated mid-name by an interleaved xcodebuild message
(`testAcce2026-07-21 09:06:03…`) — the suite completed, exit code 0, zero
failure lines, so it verifiably passed; the truncation is a logging
artifact also seen in Phase 17.

Verification trio: build **BUILD SUCCEEDED**; iPhone 17 Pro simulator;
test exit 0.

## Acceptance criteria walk

1. ✅ Gate committed with per-condition verbatim evidence (above), GO path.
2. n/a (NO-GO path not taken).
3. ✅ Coverage measured complete (400/400, validator-enforced per record);
   import-time (c) cross-check fails loudly; estero → `"Estero"` (8);
   senators key-free (0); validator green with 147/245/8 measured.
4. ✅ Pinned strings ship; a Camera district page lists its
   circoscrizione's plurinominale deputies; estero deputies appear on no
   geographic page (excluded by electionType *and* by value); profile
   line present. As in Phase 17, visual spot-checking in a live simulator
   was not performed in this headless session — the UI claims rest on the
   tested pure function and the existing view paths; 22A's a11y pass
   lists the human checks (new surfaces flagged below).
5. ✅ Pure grouping function + invariants on fixtures; suite green, zero
   regressions, +6 deliberate.
6. ✅ This report, committed in the phase commit.

## Notes for later phases

- New a11y surfaces for 22A: the plurinominale section (header +
  explanatory caption + `RepresentativeRow` list, and its empty state on
  the Valle d'Aosta page) and the profile `"Circoscrizione:"` line inside
  the header's combined accessibility element.
- The two UI-test-infrastructure flakes (Phases 17–18) are now a pattern
  worth a line in 22A's report: the template `PoliticiUITests` target's
  value is marginal and its flakiness is environmental, not code-driven.
- `validate_circoscrizione()` reads the reference set from
  `districts.geojson` at validation time — if a future ISTAT re-import
  ever renamed a circoscrizione, both the importer cross-check and the
  validator would surface the mismatch loudly rather than letting the two
  files drift apart silently.
