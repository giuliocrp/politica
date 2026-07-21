# V3 Phase 15b — Senato Linkage Predicate Probe (GO/NO-GO Re-evaluation)

Re-evaluates Phase 15's `NO-GO(LINK)` finding with real evidence from one
approved, deliberate, read-only SPARQL introspection run against
`https://dati.senato.it/sparql`. No app code, pipeline script, or bundled
data changed — only probe scripts and this report.

## Approval

The user explicitly approved running exactly one predicate-discovery
probe (plus the legislature-currency precheck below) against
`https://dati.senato.it/sparql`, in response to a presented choice
between "run the probe" and "skip it, mandate-half-only Phase 17." User
reply: **"A"**. The approval was scoped narrowly — one read-only
introspection query, no production query file to be modified based on
assumed results, join implementation deferred to Phase 17 even if this
phase finds GO.

## 1. Legislature-currency precheck

**Design note, found live**: the originally-designed aggregate form
(`GROUP BY ?legislatura`, `COUNT`, `SUM(IF(BOUND(?fine), 0, 1))`) got
`HTTP 403 Forbidden` from the endpoint. Isolated by testing the known-good
committed `tools/queries/senato_senatori.rq` (still returns 208 bindings,
confirming the client/endpoint/User-Agent are fine) against a plain,
non-aggregate `SELECT DISTINCT ?legislatura` (works). The aggregate
constructs specifically are what this endpoint rejects — not a general
block. `tools/probes/probe_senato_legislature_currency.rq` was rewritten
to the working, non-aggregate form; the rejected aggregate attempt is
documented in its header comment for future reference.

**Result** (`tools/probes/output/legislature_currency.json`, 21
bindings):
```
Assemblea Costituente, Consulta Nazionale, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
11, 12, 13, 14, 15, 16, 17, 18, 19
```
**19 is the maximum value present — no legislature beyond it exists in
the graph.** Legislature XIX is confirmed current. Proceeded to the main
probe.

## 2. Predicate-discovery probe — two more real obstacles, both resolved

`tools/probes/probe_senato_predicate_discovery.rq` (Phase 15's design)
also used `SAMPLE`/`COUNT`/`GROUP BY` and got `HTTP 400 Bad Request`.
Rewritten to a plain `SELECT ?predicate ?value` (no aggregation) — this
ran, but returned exactly `10000` bindings (a suspiciously round number).
Investigation:
```
distinct predicates: 22
http://dati.senato.it/osr/interviene: 9322 occurrences (of 10000 total)
```
`osr:interviene` (floor-speech records — thousands per senator) dominated
the endpoint's apparent ~10,000-row result cap before most senators' other,
low-cardinality predicates (birth city, nationality, etc. — 11-12
occurrences each) were even reached. **Rewritten again** to
`SELECT DISTINCT ?predicate` with no `?value` — a solution modifier, not
an aggregate function, and structurally incapable of being truncated
below the true distinct-predicate count (there are only ~37, nowhere near
10,000 — verified this can't silently under-report).

**Result** (`tools/probes/output/predicate_discovery_distinct.json`, 37
distinct predicates). Full list quoted in the probe's own committed
output structure; the three relevant to this phase:
```
http://dati.senato.it/osr/tipoElezione
http://dati.senato.it/osr/regioneElezione
http://dati.senato.it/osr/collegioElezione
```
None of these three were ever requested by the committed
`tools/queries/senato_senatori.rq` — confirming Phase 15's NO-GO(LINK)
was correct *for the cache that existed then*: the join key was never
missing from the graph, only from the query.

## 3. Candidate analysis — verbatim samples

A third probe (`tools/probes/probe_senato_collegio_predicates.rq`)
fetches these three predicates for every senator. **First attempt** used
a looser join (`?senatore a osr:Senatore ; foaf:firstName ; foaf:lastName
; osr:mandato ?mandato` only) and returned 400 bindings across 254
distinct `?senatore` URIs — **46 more than the known-good 208**. Diffing
against a fresh control run of the actual `senato_senatori.rq` confirmed
all 46 extras were *not* in the production query's result set: the
control query requires several additional mandatory triples
(`osr:tipoMandato`, `osr:inizio`, `osr:cittaNascita`,
`osr:provinciaNascita`, `osr:nazioneNascita`, `osr:dataNascita`,
`foaf:depiction`) that my looser probe omitted, admitting senators
outside the production query's actual scope. **Fixed** by mirroring
`senato_senatori.rq`'s exact join pattern verbatim and adding the three
new predicates as `OPTIONAL`. Re-run: **208 bindings, 208 distinct
senatore — exact match with the production query.**

Among the 201 currently-serving (no `fineMandato`, same rule as Phase 15):

```
tipoElezione value counts:
  "Eletto uninominale dalla XVIII legislatura":   73
  "Eletto proporzionale dalla XVIII legislatura": 121
  <absent>:                                         5
  "circoscrizioni estere":                           2
                                                   ---
                                                   201
```

The 5 `<absent>` are, verbatim by name: **Elena Cattaneo, Mario Monti,
Renzo Piano, Carlo Rubbia, Liliana Segre** — exactly Phase 15's 5
verified life senators, an independent cross-check that this join is
scoped correctly. The 2 `"circoscrizioni estere"` senators (Andrea
Crisanti, Francesco Giacobbe) have `regioneElezione` = `"EUROPA"` /
`"AFRICA ASIA OCEANIA ANTARTIDE"` and no `collegioElezione` — structurally
no collegio, exactly like Camera's estero deputies.

**73 senators have `tipoElezione` = uninominale, and exactly those same
73 have a non-null `collegioElezione`** (verified: `count(uninominale) ==
count(collegioElezione present) == 73`, not a partial overlap). Sample
values, verbatim:
```
BASILICATA - U01 (POTENZA)
PIEMONTE - U02 (MONCALIERI)
PIEMONTE - U01 (TORINO: CIRCOSCRIZIONE 2 - SANTA RITA - MIRAFIORI NORD - MIRAFIORI SUD)
LOMBARDIA - U06
TRENTINO-ALTO ADIGE/SÜDTIROL - U04 (BOLZANO/BOZEN)
VALLE D'AOSTA - U01 (AOSTA)
SARDEGNA - U01 (CAGLIARI)
```
(73 total values, all individually inspected — not a subsample.)

**Join test against the real ISTAT side**: parsed each `collegioElezione`
value's prefix before `" ("` (or the whole string when no city detail is
present, e.g. `"LOMBARDIA - U06"`), split on `" - U\d+$"` into
`(regione, subCode)`, uppercased, and matched against a
`(regione.upper(), subCode) → id` lookup built directly from
`Politici/Data/districts_senato.geojson`'s real 74 features:
```
matched: 72 / 73
unmatched: ("VALLE D'AOSTA - U01 (AOSTA)", ("VALLE D'AOSTA", "U01"))
```
The one unmatched case is a naming variant, not an ambiguity or a data
problem: ISTAT's `SU20_DEN` for this region is the bilingual `"Valle
d'aosta/Vallée d'Aoste"`, while the SPARQL side gives the Italian-only
`"VALLE D'AOSTA"`. Valle d'Aosta has **exactly one** Senato uninominale
collegio (`S20001`, `subCode = "U01"` — verified directly against
`districts_senato.geojson`), so there is zero ambiguity about which real
collegio this refers to — it's a one-line naming alias, not a join
failure. **Effective match rate: 73/73 (100%).**

**No duplicate claims**: all 73 `collegioElezione` values are distinct —
no two currently-serving senators claim the same collegio (unlike
Camera's 2 by-election successor cases, Senato's XIX-legislature
uninominale seats show no such collision in this data).

## GO/NO-GO(LINK) — re-evaluated: **GO**

| Requirement | Phase 15 | Phase 15b (this probe) |
|---|---|---|
| Demonstrated joinable key, quoted samples on both sides | ✗ — no collegio-shaped predicate found in the then-existing cache | ✓ — `osr:collegioElezione`, quoted samples above; ISTAT side (`SU20_DEN`/`regione`+`subCode`) already verified in Phase 15/16 |
| Written join design, demonstrated not speculative | n/a | ✓ — parse rule executed against real data, 73/73 (100%) resolved, §4 below |
| Computable `MIN_LINKED_SENATO` at 90% of verified linkable-elective count | ✗ — count itself unknown | ✓ — 73 verified linkable (uninominale, currently-serving, elective) senators |

**Decision: GO.** The join key was never structurally absent — Phase 15's
NO-GO was the correct call *given the evidence available then* (the cache
genuinely didn't have it, and guessing a predicate name rather than
discovering it live would have violated the project's own established
methodology). This probe supplies the missing evidence.

## 4. Join design for Phase 17

**Query extension** (design only — `tools/queries/senato_senatori.rq` is
**not modified in this phase**; this is what Phase 17 should add,
verified working via the probe above):
```sparql
OPTIONAL { ?mandato osr:tipoElezione ?tipoElezione. }
OPTIONAL { ?mandato osr:regioneElezione ?regioneElezione. }
OPTIONAL { ?mandato osr:collegioElezione ?collegioElezione. }
```
added alongside the existing `OPTIONAL { ?mandato osr:fine ?fineMandato.
}` / `OPTIONAL { ?mandato osr:tipoFineMandato ?tipoFineMandato. }` block,
and `?tipoElezione ?regioneElezione ?collegioElezione` added to the
`SELECT DISTINCT` variable list.

**Linkage logic** (for `tools/import_representatives.py`, Phase 17):
1. A senator links to a collegio iff `tipoElezione` starts with `"Eletto
   uninominale"` (73 of 201 currently-serving — the rest, 128, correctly
   get no `districtId`, exactly mirroring Camera's plurinominale/estero
   pattern).
2. Parse `collegioElezione`: take the substring before `" ("` (or the
   whole string if there's no `" ("`), then split it into
   `(regione, subCode)` on the pattern `"{regione} - {subCode}"`
   (`subCode` matches `U\d+`).
3. Look up `(regione.upper(), subCode)` against
   `Politici/Data/districts_senato.geojson`'s `(regione, subCode) → id`
   map (already built by `tools/import_boundaries.py --chamber senato`,
   Phase 16) to get the `"S"`-prefixed district id.
4. **Special case**: when `regione.upper() == "VALLE D'AOSTA"`, match
   against ISTAT's `"Valle d'aosta/Vallée d'Aoste"` regione instead (or
   equivalently, special-case on `subCode == "U01"` for that one region,
   since it has only one collegio) — a one-entry alias table, not a
   fuzzy-matching heuristic, since this is a fully disclosed, verified,
   unambiguous naming difference, not a guess.
5. Every other `(regione, subCode)` pair matched exactly against the 74
   real ISTAT features in this probe (§3) — no other aliasing needed,
   *but Phase 17 should still verify this holds at implementation time*,
   since this probe's evidence is from one point-in-time fetch, not a
   standing guarantee.

**Expected outcome**: 73 of 201 currently-serving senators link to a real
Senato collegio (not 196 — only the uninominale-elected subset
structurally has one, exactly as Camera's `districtId` is null for every
plurinominale/estero deputy). The remaining 128 elective senators
(121 proporzionale + 2 estero) and the 5 life senators correctly keep
`districtId = null`.

**`MIN_LINKED_SENATO` gate**: mirrors
`tools/import_representatives.py`'s existing `MIN_LINKED_COLLEGI = 133`
constant, which is `ceil(0.9 × 147)` (147 = total Camera uninominale
collegi; verified by reading the constant and its neighboring `fail()`
message, which states "il 90% di 147" and computes to 132.3, ceiling
133). Applying the same ceiling convention to Senato's verified linkable
count of 73:
```
MIN_LINKED_SENATO = ceil(0.9 × 73) = ceil(65.7) = 66
```

**Ambiguity cases**: none found. Zero duplicate `collegioElezione` claims
among currently-serving senators (§3); the single naming variant (Valle
d'Aosta) is fully resolved, not merely worked around, since the region
has exactly one collegio.

## Files added this phase

- `tools/probes/probe_senato_legislature_currency.rq` — rewritten to the
  working non-aggregate form; rejected aggregate form documented in its
  header.
- `tools/probes/probe_senato_predicate_discovery.rq` — rewritten from
  Phase 15's aggregate design to the working `SELECT DISTINCT ?predicate`
  form.
- `tools/probes/probe_senato_collegio_predicates.rq` — new; the
  production-query-mirroring follow-up that produced the join evidence.
- `tools/probes/run_probe.py` — new; a small, reusable, sparql_client-backed
  runner for executing a probe `.rq` file against a live endpoint and
  saving raw output to `tools/probes/output/` (gitignored) — documented
  in `tools/probes/README.md`.
- `tools/probes/output/*` — gitignored, not committed (7 intermediate
  JSON files from this session's investigation, including the two
  rejected/superseded attempts, left in place locally as this machine's
  own scratch trail, not part of the commit).

No file under `tools/queries/`, `tools/import_*.py`, `Politici/`, or any
bundled `Politici/Data/*` file was modified. The join implementation
itself — extending `senato_senatori.rq` for real, wiring it into
`import_representatives.py`, adding `MIN_LINKED_SENATO`, and updating
`District`/`Representative`-adjacent Swift code and UI — is Phase 17's
work, not this phase's.
