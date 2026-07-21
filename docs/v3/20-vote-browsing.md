# V3 Phase 20 — Vote Browsing (Source-Backed Event Identity) + Methodology Gate [GO-EVENT-ID: **GO**]

Fully offline phase (the votes cache was untouched by Phase 17's
Senato-only refetch). Companion document: `docs/v3/votes-methodology.md` —
the standing gate that defers every vote-derived metric to V4 at the
earliest. **No metric ships in this phase**; grep-verified: the pinned
metric label appears only in documentation, nowhere in app code.

## Open questions resolved first (plan §1 Q3/Q4)

**Q3 — votes.json internal shape (pre-phase):** a **flat position list** —
4,788 records, each duplicating its event's `title`/`date`/`result`/
`sourceUrl`/`provenance` per position; keys uniform; 12 distinct
(date, title) tuples and 12 distinct sourceUrls. Not previously normalized
in any way.

**Q4 — every extant votes byte gate:** exactly **two**, both 2 MiB
(2,097,152 B): `tools/import_votes.py::MAX_OUTPUT_BYTES` (pre-write, on
the serialized output, nothing written on breach) and
`tools/validate_data.py::MAX_VOTES_FILE_BYTES` (post, on the file). Both
were honored by every measurement below; no other size constraint exists
in the pipeline.

## The GO-EVENT-ID gate — evidence

**Candidate identifier:** the `ocd:votazione` URI's trailing segment, e.g.
`vs19_690_076` from
`http://dati.camera.it/ocd/votazione.rdf/vs19_690_076` — the source's own
id taken verbatim with the same `id_segment` convention as every other id
in the pipeline (nothing minted). It was already `import_votes.py`'s
internal grouping key; it had simply never been carried into the output.

Verified by the committed offline probe
`tools/probes/probe_votes_event_identity.py` (output gitignored), on
**both** sides:

- **Present for every event**: all 9,975 raw bindings carry `?v`; every
  slug parses as `vs{leg}_{seduta}_{numero}`; 25 distinct votazioni in the
  cache's fetch scope.
- **Constant across all positions of an event**: every per-position
  `ocd:voto` slug (`vd{leg}_{seduta}_{numero}_{deputato}`, e.g.
  `vd19_690_022_306139`) embeds exactly its votazione's
  `(leg, seduta, numero)` triple — checked for all 9,975 bindings; and on
  the shipped side, each position id's embedded triple maps to exactly one
  `(date, title, result, sourceUrl)` tuple.
- **Distinct across events**: 12 distinct slugs ↔ 12 distinct event tuples
  in `votes.json` (a bijection, no slug shared by two tuples and no tuple
  by two slugs), all 12 present in the raw cache.

Sample quoted pair: shipped position `vd19_690_076_50204` ↔ event
`vs19_690_076` ↔ sourceUrl `...RifVotazione=690_76...` (the official
scheda link's own reference corroborates the same sitting/number pair).

**Decision: GO.**

## Flat vs normalized — decided by measurement

All three serializations measured with the pipeline's actual
`json.dumps(..., ensure_ascii=False, indent=2, sort_keys=True)` settings,
against the 2 MiB (2,097,152 B) gates:

| Shape | Bytes | % of gate | Headroom |
|---|---|---|---|
| Pre-phase flat (no identifier) | 1,878,366 | 89.6% | 10.4% |
| (A) flat + `voteEventId` per position | 2,045,946 | 97.6% | **2.4%** |
| (B) normalized `{"events":[...],"positions":[...]}` | **711,439** | **33.9%** | 66.1% |

(A) lands inside the plan's "< ~5% headroom" trigger → **normalized
schema adopted**: events carry `{id, title, date, result, sourceUrl,
provenance}` once; positions carry only `{id, voteEventId,
representativeId, vote}`. The file *shrank* 62%, freeing ~1.33 MiB under
the unchanged 2 MiB policy — deliberately left as Phase 21 material; the
included scope (12 events / 4,788 positions) was **not** expanded here.

**Content equivalence verified** (generated-data protocol): rejoining the
normalized file's positions to their events reproduces exactly the old
flat file's 4,788 `(id, representativeId, title, date, vote, result,
sourceUrl, provenance)` tuples — a pure shape change, zero value drift.

## What shipped

*tools:* `probe_votes_event_identity.py` (committed);
`import_votes.py` emits the normalized shape with the slug as event id
(importer-side invariants: unique event ids, unique position ids,
positions' distinct `voteEventId` set == event-id set, referential
integrity, both byte gates); `validate_data.py::validate_votes()`
rewritten for the schema (per-event and per-position structural checks
plus the Phase 20 invariants: every position references an existing
event, every event has ≥ 1 position; the id→tuple uniqueness is
structural in this schema since the tuple lives once on the unique-id
event record); `validate_votes_reference_representatives()` reads
positions.

*data:* `votes.json` — the recorded shape change only (695 KB on disk).

*app:*
- `VotesFile`/`VoteEventRecord`/`VotePositionRecord` decode types +
  aggregated `VoteEvent` (Vote.swift); `Vote.dateFormatter` made shared.
- `VoteService`: decodes the normalized schema first, falls back to the
  flat array for the frozen `votes.sample.json` fixture (in flat mode
  `allEvents()` is empty **by design** — no source-backed ids, no
  synthesized events); rebuilds the flat `[Vote]` view by joining
  positions to events, so `votes(for:)` and every existing consumer is
  unchanged; `aggregateEvents` is a static pure function keyed strictly
  on `voteEventId` (grep-verified: the only `sourceUrl`+grouping match in
  app code is the comment forbidding it).
- `VotazioniListView` + `AppRoute.votazioniList` + Home entry button
  (`"Votazioni in Aula (campione)"`): scope line
  `"Campione di {N} votazioni importate — non l'archivio completo"` with
  N from the data (12); per-event row with wrapping title, long date,
  esito line, tally row with the pinned accessibility labels
  (`"Favorevoli: N"` / `"Contrari: N"` / `"Astenuti: N"` /
  `"Assenti: N"`; a `.sconosciuto` tally renders only when nonzero,
  labeled with the existing `"Esito non disponibile"` vocabulary), and
  the source `Link` as its own VoiceOver element (same pattern as
  `VoteRow`); single screen, no detail route.
- `VoteHistoryView`: outcome filter chips (`"Tutte"` + the four real
  choices, `isSelected` trait, ≥44 pt) + `.searchable` over titles,
  composing with AND via the static pure `filtered(_:choice:searchText:)`
  (case/diacritic-insensitive `localizedStandardContains`); honest
  distinct empty state `"Nessuna votazione corrisponde ai filtri
  selezionati."` when filters over-narrow (vs the no-data case).

## Tests

Deliberate additions (+8, `VoteBrowsingTests`): shipping-file invariants
(12 events; non-empty `voteEventId`s; distinct-id set equality), shipping
tally-sums == per-event position counts, aggregation stability under
position order (fixture), aggregation keyed strictly on `voteEventId`
even when two events share title/date/sourceUrl (fixture), flat-fixture
fallback (sample loads, zero events synthesized), shipping join
(positions count == votes count), filter composition, filter
case/blank-tolerance.

Deliberate updates (documented; the old flat-decode load path no longer
exists): `SchemaV2Tests.testShippingDataIdsAreUnique` (+ event-id
uniqueness), `testShippingVotesReferenceKnownRepresentatives`,
`testShippingVotesAreAllOfficialProvenance`,
`testShippingVotesHaveNoUnmappedVoteOrResultVocabulary`, and
`DecodingTests.testShippingVotesAreNonEmptyAndWithinBudget` — all now
decode `VotesFile`. `testVoteServiceSortsRealVotesNewestFirst` needed no
change (the `VoteService` API is preserved). The `votes.sample.json`
fixture and its tests are untouched.

**Suite: 139 runtime cases passed, 0 failures, exit 0** — declared 136
(109 baseline + 27 deliberate across Phases 17–20), runtime 139
(112 + 27), ×4 `testLaunch` cause unchanged. Clean run, no flake.

Verification trio: build **BUILD SUCCEEDED**; iPhone 17 Pro simulator;
test exit 0.

## Acceptance criteria walk

1. ✅ `votes-methodology.md` committed: six-line gate with per-line
   current-sample status (1 of 6 passes — the sample is one sitting, one
   day, zero atti), standing rules, pinned label, explicit V4 deferral.
2. ✅ GO-EVENT-ID evidence above, committed probe.
3. ✅ Every position carries the non-empty source-backed `voteEventId`;
   validator green; greps clean (aggregation on `voteEventId` only; no
   metric string in app code); both gates satisfied with measured
   headroom; flat-vs-normalized decision recorded with all three
   measurements.
4. ✅ Votazioni scope line N=12 from data; tally sums == fixture position
   counts (test-enforced); per-event source links; Home entry present.
5. n/a (GO path taken).
6. ✅ VoteHistory chips + search compose; honest empty-filter copy;
   metric label absent from app code.
7. ✅ Invariant-style tests per above; zero regressions beyond documented
   deliberate updates.
8. ✅ This report, committed in the phase commit. As in Phases 17–19,
   live-simulator visual checks were not performed headless; UI claims
   rest on tested pure functions and established view idioms (22A human
   checks flagged below).

## Notes for later phases

- **Phase 21 inputs**: the normalized schema leaves 66.1% headroom under
  the unchanged 2 MiB per-file policy, and per-event cost is now ~2.5 KB
  (event record) + ~120 B/position — the scope probe's arithmetic should
  start from these real numbers plus the run-time file sizes.
  `tools/config/votes_scope.json` was deliberately not touched.
- The methodology gate table must be re-measured in the same commit as
  any Phase 21 sample change (see the re-evaluation protocol in
  `votes-methodology.md`).
- New a11y surfaces for 22A: Votazioni rows (combined static element +
  separate Fonte link + the four pinned tally labels), the scope-line
  header, the VoteHistory filter chips (`isSelected` trait, 44 pt), the
  search field, and the empty-filter state; plus the Home
  `"Votazioni in Aula (campione)"` entry button.
