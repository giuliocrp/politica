# v2 Phase 9 — Curated Official Camera Votes with Per-Deputy Positions

Replaces `Data/votes.json`'s empty schema-v2 placeholder (shipped since the
representative-import phase — see `docs/v2/01-real-data-import.md`) with a
bounded, curated subset of real Camera dei Deputati roll-call votes and
every current deputy's recorded position on each. Senato is explicitly out
of scope for this phase.

## Step 1 — exploring the votazioni schema before writing any code

Live introspection against `https://dati.camera.it/sparql` (developer-tool
network use only, per CLAUDE.md — the app itself makes no such calls),
starting from `SELECT DISTINCT ?p WHERE { ?v a ocd:votazione ; ?p ?o }`,
then dumping every triple of one real XIX-legislature votazione
(`votazione.rdf/vs19_047_005`) and one of its per-deputy `voto` records.

### The vote-level entity (`ocd:votazione`)

| predicate | example | notes |
|---|---|---|
| `rdfs:label` / `dc:title` | `"Votazione Articolo 1 PDL n. 0080"` | **Always a generic procedural template** — confirmed across every sample checked, including "final" votes (`"Votazione finale "`). Never the actual bill/motion text. |
| `dc:date` | `"20230201"` | `yyyyMMdd`, no separators. |
| `ocd:approvato` | `1` / `0` | Integer flag: did the vote pass. |
| `dc:relation` | `"http://documenti.camera.it/apps/votazioni/votazionitutte/schedavotazione.asp?Legislatura=XIX&RifVotazione=47_5&tipo=dettaglio"` | A real, directly-published deep link to the official vote detail page — used verbatim as `sourceUrl`. |
| `ocd:votazioneSegreta` | `1` / `0` | Secret-ballot flag — see the scope-control finding below. |
| `ocd:votazioneFinale` | `1` / `0` | Final vs. intermediate (e.g. article-by-article) vote. |
| `ocd:richiestaFiducia` | `1` / `0` | Confidence-vote flag. Not carried into the app's schema (no field for it). |
| `ocd:rif_assemblea`, `ocd:rif_leg`, `ocd:rif_seduta`, `ocd:rif_attoCamera` | URIs | Scoping/linking references. |
| `ocd:astenuti`/`ocd:contrari`/`ocd:favorevoli`/`ocd:presenti`/`ocd:votanti` | integers | Aggregate counts — not per-deputy, just used during exploration to sanity-check volumes. |

**Finding: the real subject of a vote lives on the associated `atto`, not
on the votazione itself.** `?v ocd:rif_attoCamera ?atto` and `?atto
rdfs:label ?attoLabel` gave, for the PDL-80 example:

```
" BRAGA ed altri: \"Istituzione di una Commissione parlamentare di inchiesta
sulle attivit&agrave; illecite connesse al ciclo dei rifiuti e su illeciti
ambientali ad esse correlati\" (80) ^^http://www.w3.org/2001/XMLSchema#string"
```

Two disclosed, purely-mechanical source-data artifacts here, both cleaned
deterministically in `tools/import_votes.py`'s `clean_atto_label()` — not
invented content, just undoing a known encoding glitch:
- An HTML entity (`&agrave;` for "à") left unescaped — fixed with `html.unescape`.
- A literal `^^http://www.w3.org/2001/XMLSchema#string` suffix that leaked
  into the label *string value itself* (this is not proper RDF datatype
  metadata — it's literally part of the text) — stripped with a regex.

Not every votazione has an associated atto (organizational votes, procedural
motions, etc.) — `attoLabel` is `OPTIONAL`; `title` falls back to the
trimmed `dc:title` alone in that case (see the "what we actually imported"
section below — the 12 votes that made the final cut happen to be exactly
this fallback case).

### The per-deputy position entity (`ocd:voto`)

A separate entity per `(votazione, deputato)` pair, found via `?x
ocd:rif_votazione <votazione-uri>` (273–399 such entities per votazione,
one per current-at-the-time deputy):

```json
{
  "rdfs:label": "L'ABBATE PATTY (M5S) ha votato favorevole",
  "ocd:rif_deputato": "http://dati.camera.it/ocd/deputato.rdf/d307822_19",
  "ocd:rif_votazione": "http://dati.camera.it/ocd/votazione.rdf/vs19_047_005",
  "ocd:rif_gruppoParlamentare": "http://dati.camera.it/ocd/gruppoParlamentare.rdf/gr4131",
  "dc:type": "Favorevole",
  "dc:identifier": "047005_307822"
}
```

`dc:type` is the raw position vocabulary. `ocd:rif_deputato`'s URI ends in
`d{numericId}_19` — **`{numericId}` is exactly the same source identifier
already used as `Representative.stableSourceId`** (see
`tools/import_representatives.py`), giving a direct, zero-ambiguity join
key with no separate lookup needed.

### Observed raw `dc:type` vocabulary (per-deputy position) → app enum

Checked via `GROUP BY dc:type` over multiple real votazioni (one unanimous,
one with real dissent):

| raw `dc:type` observed | count (sample votazione) | mapped `VoteChoice` | note |
|---|---|---|---|
| `"Favorevole"` | 53–273 | `Favorevole` | exact match |
| `"Contrario"` | 0–187 | `Contrario` | exact match |
| `"Astensione"` | 0–66 | `Astenuto` | **noun→adjective mismatch** — the app's `VoteChoice` enum requires an exact raw-value match (`Self(rawValue:)` is not fuzzy — see `TolerantDecoding.swift`), and its case is `Astenuto`, not `Astensione`. Translated explicitly in `tools/import_votes.py`, not passed through. |
| `"Non ha votato"` | 93–126 | `Assente` | The graph doesn't distinguish "genuinely absent" from "present but didn't press a button" at this predicate — mapped to the closest existing `VoteChoice` case as a disclosed best fit, not a guess about *why*. |
| `"Ha votato"` | (secret-ballot votes only) | *(excluded — see scope control)* | Only ever seen on `ocd:votazioneSegreta 1` votes — confirms secrecy is enforced at the data level, not just a UI convention. |

No raw value outside this table was observed in the 12 votes actually
imported (see `unknown_vote_choice`/`unknown_vote_result` logging in
`tools/import_votes.py` — empty on every run so far). Any future new value
maps to `Sconosciuto` with a printed warning, never a crash or a guess —
enforced by `testShippingVotesHaveNoUnmappedVoteOrResultVocabulary`.

`ocd:approvato` → `VoteResult`: `"1"` → `Approvato`, `"0"` → `Respinto`,
anything else → `Sconosciuto` with a warning (not observed in practice —
this predicate is documented as always a bound integer).

### Finding: secret-ballot votes exist but are genuinely unattributable

`ocd:votazioneSegreta 1` votes (98 of 37,959 XIX-legislature votazioni)
*do* have per-deputy `ocd:voto` records — but every one of them carries the
generic `dc:type "Ha votato"` ("voted"), never a disclosed position.
Verified directly: `GROUP BY dc:type` on a real secret-ballot vote gave
`{"Ha votato": 286, "Astensione": 5, "Non ha votato": 108}` — no
`Favorevole`/`Contrario` at all. This is ballot secrecy enforced at the
data-publication level, not a gap in the query. **"Electronic" votes in
this phase's scope means `ocd:votazioneSegreta 0`** — excluding secret
ballots isn't an arbitrary cut, it's the only choice that doesn't
misrepresent "we don't know" (an unmapped-vocabulary `Sconosciuto`) as if
it were the same thing as "this is inherently unknowable by design."

## Step 2 — scope control

`tools/config/votes_scope.json`:

```json
{
  "mode": "recent",
  "n": 25,
  "voteUris": [],
  "maxVotes": 25,
  "maxPositionRecords": 5000
}
```

`mode: "recent"` — the N most recent Camera Assemblea, non-secret,
XIX-legislature votazioni, ordered by `dc:date` descending
(`tools/queries/camera_votazioni_scope.rq`). `mode: "explicit"` (an
alternative not used this run) would take a hand-curated `voteUris` list
instead, skipping the scope query entirely — supported in both
`tools/fetch_camera_votes.py` and validated the same way (checked to be
well-formed `dati.camera.it` votazione URIs before ever being
string-interpolated into a SPARQL `VALUES` clause).

**Two hard caps, enforced in code, independent of the config's nominal
`n`:**
- `maxVotes` (25): never include more than this many votazioni.
- `maxPositionRecords` (5000): never write more than this many position
  records total. This is the one that actually binds in practice — with
  ~399 positions per votazione (one row per then-serving deputy, present or
  not) and a 25-vote nominal scope, the naive "25 most recent" set would
  produce ~9,975 records / ~4.6 MB, comfortably over the "~2 MB" budget.
  `tools/import_votes.py` processes candidates newest-first and **stops at
  the first vote that would push the cumulative count over
  `maxPositionRecords`** — never a bin-packed selection that skips ahead to
  a smaller/older vote to fit more in, which would make the "most recent"
  claim misleading. `MAX_OUTPUT_BYTES` (2 MB, hard-coded) is a second,
  independent safety check computed on the actual serialized bytes *before*
  writing — caught and correctly refused a write on the first run
  (`maxPositionRecords` was initially 6000, producing a 2.20 MB file; tuned
  down to 5000 after measuring real output, landing at 1.79 MB).

**What this run actually produced**: 12 of the 25 candidate votazioni fit
(4,788 position records, 1834 KB) before the 13th would have exceeded the
5000-record budget. `tools/import_votes.py`'s own output, verbatim:

```
OK: 4788 posizioni (12 votazioni) scritte in Politici/Data/votes.json (1834 KB)
  votazioni incluse: 12/25 candidate (maxVotes=25, maxPositionRecords=5000)
  votazioni escluse per budget posizioni: 13: ['vs19_690_054', 'vs19_690_053', 'vs19_690_050', ...]
```

All 12 included votes happen to come from the single most recent Camera
sitting (2026-07-15) and are all "Ordine del giorno" (order-of-the-day
motion) votes on the same underlying bill (2822-A) — a real reflection of
how that sitting was structured (many sequential odg votes), not a bug or
an editorial curation choice on this script's part. None of the 12 had an
associated `atto` (`attoLabel` absent for all of them, per the fallback
case above), so their titles are the trimmed `dc:title` alone, e.g.
`"Votazione Ordine del giorno 9/2822-A E ABB/21"` — shorter than the
BRAGA-PDL example above, but still real, unmodified source text, not
fabricated. All 12 were rejected (`Respinto`) by the Chamber.

## Step 3 — import mapping

- `representativeId`: `ocd:rif_deputato`'s numeric id, prefixed with `p` —
  looked up against `representatives.json`'s **Camera** `stableSourceId`
  set. A `voto` record whose deputato isn't found is dropped and counted
  (`dropped_unmapped_deputy`) — **0 drops on this run**, expected for a
  "most recent" scope since departed predecessors would only show up in
  older votes.
- `vote`/`result`: mapped via the tables above, never passed through raw.
- `title`: `dc:title` (trimmed) combined with the cleaned `attoLabel` when
  present (`"{procedural} — {substantive}"`), else the trimmed `dc:title`
  alone.
- `sourceUrl`: `dc:relation` verbatim when present, `null` otherwise —
  never constructed. Present for all 12 votes imported this run.
- `id`: the source's own `ocd:voto` entity id segment (e.g.
  `"vd19_690_076_50204"`) — not a constructed id.
- `provenance`: always `"official"`.
- Output sorted deterministically (date desc, id desc, representativeId
  desc) for reproducible diffs; `VoteService.votes(for:)` re-sorts by date
  at query time regardless, so file order isn't load-bearing for app
  behavior.

## Step 4 — referential integrity

Enforced twice, independently: inside `tools/import_votes.py` itself before
ever writing the file (fails loudly, writes nothing, if any
`representativeId` doesn't resolve), and again by `tools/validate_data.py`
(`validate_votes_reference_representatives()`) re-checking the
already-written files from scratch. `make validate` output on this run:

```
OK: 4788 posizioni valide in Politici/Data/votes.json (1834 KB)
OK: integrità referenziale voti coerente — 4788 posizioni, 399 rappresentanti coinvolti
```

399 of 400 Camera deputies appear in at least one imported vote. The one
exception, verified deliberately rather than assumed to be a bug: **Lorenzo
Fontana** (`p307591`), President of the Chamber of Deputies — by
long-standing Italian parliamentary custom the presiding officer does not
participate in ordinary roll-call votes. This is also the deputy used for
the manual "no imported positions → empty state" check below.

## Manual verification against the official record

Picked one imported vote and two deputies' positions on it, and checked
them against the live official Camera page at the vote's own `sourceUrl`
(`http://documenti.camera.it/apps/votazioni/votazionitutte/schedavotazione.asp?Legislatura=XIX&RifVotazione=690_76&tipo=dettaglio`)
rather than trusting our own pipeline's output:

| | our `Data/votes.json` | official Camera page |
|---|---|---|
| Subject | "Votazione Ordine del giorno 9/2822-A E ABB/21" | "ODG 9/2822-A E ABB/21" |
| Date | 2026-07-15 | 15/7/2026 |
| Outcome | Respinto | "La Camera RESPINGE" |
| Tommaso Foti | Contrario | Contrario ✓ |
| Davide Bergamini | Favorevole | Favorevole ✓ |

Exact match. This confirms the pipeline end-to-end (SPARQL query → raw
cache → mapping → `Data/votes.json`) against an independent source, not
just internal self-consistency.

**Empty-state check**: Lorenzo Fontana (Camera president, 0 imported
positions — see above) and all 201 Senato representatives (entirely out of
scope for this phase) correctly hit `VoteHistoryView`'s and
`RepresentativeProfileView`'s existing Phase 6 empty-state copy ("Nessuna
votazione disponibile in questa versione del prototipo." /
"Nessuna votazione disponibile in questa versione del prototipo.") — no
new empty-state string was needed, since the existing one was never
specific to "no data exists yet" vs. "this deputy has none in the imported
subset."

**Disclosed limitation, consistent with every prior phase in this
session**: this environment has no UI-tap automation, so I could not
personally navigate the simulator to `RepresentativeProfileView`/
`VoteHistoryView` and visually confirm rendering (wrapping, badge colors,
the "Fonte" link opening). The data-level verification above is as far as
this environment can go — a screen-level look is still worth doing before
fully trusting the phase.

## What was NOT changed

Boundaries, the Phase 8 collegio linkage, `districts.geojson`, the fetch
hygiene established in earlier phases, and the project/target/scheme/bundle
identifier are all untouched. Senato votes remain entirely out of scope —
`votes.json` carries Camera positions only, exactly as before this phase
(when it carried none at all).
