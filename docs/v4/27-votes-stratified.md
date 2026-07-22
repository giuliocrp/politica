# V4 Phase 27 — Stratified Votes Expansion + Lazy Loading [USER-GATED network: **executed**]

Executes the redesign Phase 21 recorded as the only viable path: replaces
"the N most recent" with a **stratified selection** and expands
`Data/votes.json` from 12 same-day events to **30 events across 10 sittings
spanning ~9 months**, under every existing gate, and ships the lazy,
off-main vote decoding Phase 21 deferred (its trigger — the file growing —
now fires). The `docs/v3/votes-methodology.md` gate table is re-measured in
this same commit: **1 of 6 → 5 of 6** (line 6 still blocks; Phase 29 stays
NOT RUN).

Every number below was produced by a quoted command in this session on
**2026-07-22**.

---

## 1. Approvals (quoted verbatim)

Two network acts were gated. Both approvals were given in-session, in
direct response to the network framing.

**Currency probe + metadata window (network acts #1, #2):**

> "Approved for #1 and #2 only — the currency re-verify and the
> metadata-only window probe. Do NOT run #3 (the detail fetch) until I
> approve it separately."

(with six pre-fetch conditions: byte projection with a stop at ≥90%; show
the selection before fetching; prove determinism by diff not inspection;
re-measure the test baseline; state what the count change touches;
confirm the `retrievedAt` advance and its re-sync files — all discharged
in §3–§6 below.)

**Detail fetch (network act #3):**

> "Approved — run the detail fetch (#3), chunked at 10 URIs, fail-loudly on
> any chunk, nothing partial."

(with seven additions — committed selection manifest; measured-vs-projected
bytes with a stop, not a trim, on `MAX_OUTPUT_BYTES`; post-27 `Data/`
size; the determinism-not-stability caveat; rule-9 in-app copy; Phase 24
re-pin brittleness + prefer-structural; and confirm line 6 leaves Phase 29
NOT RUN — each discharged and cross-referenced below.)

No other network act was performed. No app networking was added (the
runtime stays strictly local-first; all network work is the `tools/`
developer pipeline).

---

## 2. Refetch-protocol checklist

1. **Legislature XIX re-verified current at fetch time**, before any other
   network act: `tools/probes/probe_senato_legislature_currency.rq` via
   `run_probe.py` (the aggregate-free `SELECT DISTINCT` the protocol pins).
   21 distinct `?legislatura` values; the highest **integer is 19**, with
   nothing beyond it (the two non-integer labels are the historical
   "Assemblea Costituente" / "Consulta Nazionale"). XIX is current.
2. **Source counts diffed before/after** (a deliberate scope change, not
   drift): the votes cache went from **25 votazioni / 9,975 rows** (the
   "recent" scope, fetched 2026-07-18) to **30 votazioni / 11,946 rows**
   (the stratified `explicit` scope, fetched 2026-07-22).
3. **Manifest + attribution re-synced in this commit:** `Data/sources.json`
   (`retrievedAt` 2026-07-18 → **2026-07-22**, derived count 12 → **30**,
   note now describes the stratified sample), `docs/DATA_SOURCES.md`,
   `tools/SOURCES.md`, and the gitignored working-cache `tools/raw/SOURCES.txt`
   (a new "Camera dei Deputati — Votazioni" entry so the deputies fetch date,
   2026-07-18, stays untouched and correct).
4. **Probe output quarantined:** all probe responses under
   `tools/probes/output/` (gitignored) — never an import source. The
   committed reproducible artifact is the URI list + annotated manifest in
   `tools/config/votes_scope.json`.

---

## 3. The metadata-only window probe (#2) + Q3

`tools/probes/probe_camera_votes_metadata_window.py` +
`probe_camera_votes_metadata_window.rq` (both committed) fetch, per Camera
Assemblea XIX votazione, **metadata only** — `URI + date + segreta + finale
+ atto label`, no per-deputy positions — paged with `LIMIT/OFFSET` over the
total, stable `ORDER BY DESC(?date) ?v`.

**Q3 answered (dati.camera.it OFFSET/paging, previously unobserved):** two
pages of `LIMIT 2000 OFFSET {0, 2000}` returned **zero URI overlap**,
**monotonic** non-increasing dates, and a **clean page boundary** (page 2
began exactly where page 1 ended, at 2026-02-12). OFFSET paging is
supported and stable with a total ordering; each page returned exactly
2,000 rows, nowhere near a row cap.

**Window (deduplicated, metadata only):** 4,000 votazioni / **3,960
non-secret** (40 secret excluded), spanning **2025-10-22 … 2026-07-21 =
272 days ≈ 8.9 months**, across **82 sittings**, with **1,552 atto-bearing**
non-secret votes (**40 distinct atti**) and **80 final votes** (36
atto-bearing). The `SELECT DISTINCT` returned exactly one row per votazione
(4,000 rows = 4,000 distinct URIs), confirming **no votazione is multi-atto**
— so the detail join cannot double any positions.

**Key structural finding (drives the selector):** atto-bearing votes are
**temporally segregated**. The recent ~5 months (sittings ≥625, Mar–Jul)
are procedural/odg-only with the atto linkage absent; atto-bearing final
votes cluster in **Oct 2025 – Feb 2026** (26 sittings carry ≥1). A tight
6-month even spread lands most buckets in the atto-poor zone.

---

## 4. The offline selector, its pinned rules, and the selection

`tools/select_votes_scope.py` (committed, **offline**, deterministic) reads
the probe output and writes the chosen URI list into `votes_scope.json`'s
existing `explicit` mode — `fetch_camera_votes.py` needs no scope-logic
change. **Pinned rules** (full text in the script's docstring):

1. Candidates = non-secret votes only.
2. Group by sitting (≥3 non-secret votes to qualify as a stratum).
3. Span = the **full metadata window** (newest → oldest qualifying sitting),
   ≥6 months by construction and asserted.
4. Choose 10 sittings evenly spread across that window (endpoints forced);
   each interior bucket takes, within ±½ bucket-spacing of its target date,
   the sitting with the **most atto-bearing final votes** (then most
   atto-bearing, nearest date, higher seduta).
5. Within each sitting take 3 votes: **atto-bearing final first**, then
   atto-bearing, then procedural (each by ascending sequence).
6. Assert the result meets the targeted gate lines (≥30 events, ≥10
   sittings, ≥6 months, ≥2 distinct atti) — fail loudly otherwise.

The full-window + prefer-atto rule was chosen over three measured
alternatives (a tight-6-month even spread gave only 5/30 atto-bearing / 2
finals / 3 atti; the full-window even-nearest gave 10/5/6; full-window
prefer-atto gave **15/9/9** — the shipped choice).

**The 30 chosen votes:**

| sitting | date | votes (seq) | atto / final | flips gate line |
|---|---|---|---|---|
| 694 | 2026-07-21 | 3,2,1 | 0 / 0 | 1, 2 (recency anchor) |
| 680 | 2026-06-22 | 3,2,1 | 0 / 0 | 1, 2 |
| 664 | 2026-05-20 | 3,2,1 | 0 / 0 | 1, 2 |
| 648 | 2026-04-22 | 3,2,1 | 0 / 0 | 1, 2 |
| 634 | 2026-03-25 | 3,2,1 | 0 / 0 | 1, 2 |
| 614 | 2026-02-12 | 35,6,1 | 3 / 2 | **4** |
| 599 | 2026-01-22 | 44,28,1 | 3 / 2 | **4** |
| 581 | 2025-12-10 | 89,88,1 | 3 / 2 | **4** |
| 577 | 2025-12-03 | 100,2,1 | 3 / 2 | **4** |
| 552 | 2025-10-22 | 12,9,8 | 3 / 1 | **3** (6-month anchor), **4** |

Totals: **30 events, 10 sittings, 2025-10-22…2026-07-21 (8.9 months), 15
atto-bearing, 9 final votes, 9 distinct atti.**

**Determinism — proven by diff, not inspection (condition):** the selector
was run twice; `votes_scope.json` came out **byte-identical** both times
(`diff` empty), SHA-256
`b66a92135eae73929184cdcc01386a0f91281d61b6bbd995f003d00cf59f5a67`. All
tie-breaks are integer keys.

**Determinism is not stability across refetches (addition #4).** The
selection is a byte-identical function of a *fixed* metadata window. It is
**not** stable across a future refetch: because the recent-window atto
linkage appears to lag in the open data, a later window may legitimately
have different atto-bearing sittings and select a different 30. That is
expected and honest, not a defect — the committed URI list is the artifact
of record for *this* sample.

**Selection manifest committed (addition #1):** `votes_scope.json` carries,
alongside the 30 `voteUris`, a `selection` array annotating each with its
date, sitting, sequence, atto-bearing flag, final flag, and observed atto
label — so the editorial basis for what ships is reproducible from a clean
checkout (the probe output that fed it is gitignored). `fetch_camera_votes.py`
and `import_votes.py` read only `voteUris` and ignore the annotation.

---

## 5. Fetch (#3), import, and measured-vs-projected bytes

**Detail fetch, chunked at 10 URIs/request, fail-loud** (added to
`fetch_camera_votes.py`; a single 30-URI shot's ~12k rows could cross the
~10k row cap Phase 15b saw on the Senato endpoint): 3 clean chunks of
**3,990 / 3,971 / 3,985 rows = 11,946 total**, each far from any cap. Any
chunk failing raises through `fetch_detail` → `fail()` → non-zero exit
before `OUTPUT_PATH` is written — never a partial cache.

**Import** (`import_votes.py`, `explicit` mode, unchanged logic):

```
OK: 11899 posizioni + 30 eventi scritti in Politici/Data/votes.json (1726 KB)
  votazioni incluse: 30/30 candidate (maxVotes=30, maxPositionRecords=13000)
  ATTENZIONE: 47 posizioni scartate (deputato non in representatives.json)
```

**Measured vs projected (addition #2):**

| | projected (pre-fetch) | measured | |
|---|---|---|---|
| bytes/position | ≤ 148.7 B | **148.58 B** | ✓ |
| positions/event | ≤ 399 | **396.6** (min 394, max 399) | ✓ |
| `votes.json` bytes | ≤ 1,779,098 (84.8%) | **1,767,926 (84.3%)** | ✓, 15.7% headroom |
| positions | — | 11,899 | |

The import did **not** hit `MAX_OUTPUT_BYTES` (84.3% < 100%), so no
event was dropped to fit — no trim was needed and none was applied. Both
byte gates (`import_votes.py::MAX_OUTPUT_BYTES` and
`validate_data.py::MAX_VOTES_FILE_BYTES`, both 2 MiB) pass. `maxPositionRecords`
was raised 5,000 → **13,000** (fits 30 events × ≤399 with headroom, while
the 2 MiB byte gate stays the real limiter); `maxVotes` = 30 (= the
selection).

**Content reconciliation (generated-data protocol):** every one of the
11,899 shipped positions traces to a raw-cache `(votazione, deputato,
tipoVoto)` row with **0 untraceable and 0 choice-mismatches**; 11,946 raw −
**47 dropped** = 11,899 shipped; the 47 drops are **5 distinct
since-departed deputies** (302824, 307304, 307571, 308883, 32460) across
the older sittings — legitimate turnover, not a bug; all 30 event results
match the raw `approvato` mapping.

**`git diff` of the generated files** is exactly the expected two: `votes.json`
(the data change, same normalized schema and serializer — a pure content
diff) and `sources.json` (`retrievedAt` + derived count/note). No unexpected
change; `generatedAt` was already 2026-07-22.

---

## 6. Lazy loading (off the main thread)

`VoteService` is now `@Observable` with an `idle → loading → loaded/failed`
`state`. `loadIfNeeded() async` is **idempotent under concurrent callers**
(the first sets `.loading` and starts one task; others await it; once
`loaded`/`failed` later calls return at once). Decoding runs in a
`Task.detached` (off the main actor) carrying a DEBUG `!Thread.isMainThread`
assertion, and the result is applied back on the `MainActor`. The three
consumers — `VotazioniListView`, `VoteHistoryView`, and
`RepresentativeProfileView`'s recent-votes section — call `loadIfNeeded()`
from `.task` and render a `ProgressView` while loading.

The vote data-models (`Vote`, `VotesFile`, `VoteEventRecord`,
`VotePositionRecord`, `VoteEvent`, `VoteChoice`, `VoteResult`) and
`DataProvenance` were marked `nonisolated` (they are pure Sendable value
types that only defaulted to `@MainActor` under the project's
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`), and `LocalJSONLoader.decode`
too, so the off-main decode uses no main-actor-isolated conformance.
`VoteChoice`/`VoteResult` got self-contained nonisolated tolerant decoders
(same `.sconosciuto` fallback) rather than the `@MainActor`
`TolerantStringEnum.decodeTolerant`, keeping the shared protocol,
`CollegioType`, `ElectionType`, and `MandateType` untouched. **Build: zero
warnings, zero errors** (`** BUILD SUCCEEDED **`, Debug and the change is
inert-equivalent in Release).

**Cold-decode duration, same standalone harness on both files** (a faithful
`JSONDecoder().decode(VotesFile.self)` replica; median of 7 runs):

| | file | events / positions | median | cold (1st run) |
|---|---|---|---|---|
| before | 711,439 B | 12 / 4,788 | 7.71 ms | 9.34 ms |
| after | 1,767,926 B | 30 / 11,899 | **19.50 ms** | 24.42 ms |

A ~2.5× growth to ~20 ms — a visible hitch if run on the main thread at
launch, which is exactly what the off-main lazy load now avoids. The
`testShippingDecodeRunsOffTheMainThread` DEBUG test asserts the decode
actually ran off-main.

---

## 7. Test changes (all deliberate, listed) — new baseline 167

Re-measured **before**: `.xcresult` `totalTestCount = 164` (occurrence rule
152 `func test` + 1 `@Test` + 11 UITests; `sort -u` under-reads at 163 —
the shared `testGroupingForEsteroNeverReturnsAnyone` in `CircoscrizioneTests`
+ `RegioneTests`).

| Test | Change |
|---|---|
| `VoteBrowsingTests.testShippingVotesFileMatchesPhase20Invariants` | pinned event count **12 → 30** |
| `VoteBrowsingTests.testShippingAggregatedTallySumsEqualPositionCounts` | pinned event count **12 → 30** |
| `VoteBrowsingTests.testSampleFlatFixtureLoadsViaFallbackWithNoEvents` | → `async`, `await loadIfNeeded()` (still asserts zero synthesized events) |
| `VoteBrowsingTests.testShippingServiceJoinsEventFieldsIntoVotes` | → `async`, `await loadIfNeeded()` |
| `SchemaV2Tests.testVoteServiceSortsRealVotesNewestFirst` | → `async`, `await loadIfNeeded()` |
| `ServiceLookupTests` (both `votes(for:)` tests) | → `async`, `await loadIfNeeded()` |
| `DecodingTests.testShippingVotesAreNonEmptyAndWithinBudget` | budget bound **5000 → 13000** (`maxPositionRecords`; 2 MiB byte gate is the real limit) |
| **+ `VoteBrowsingTests.testLoadIfNeededTransitionsIdleToLoaded`** | new — idle→loaded state |
| **+ `VoteBrowsingTests.testConcurrentLoadIfNeededIsIdempotent`** | new — 25 concurrent callers, one load, no doubled positions |
| **+ `VoteBrowsingTests.testShippingDecodeRunsOffTheMainThread`** (DEBUG) | new — decode-off-main assertion |

**New baseline: 167 declared / 167 runtime, 0 failures** (`.xcresult`
`totalTestCount 167`, passed 167). 164 + 3 new lazy tests = 167;
occurrence count 155 + 1 + 11 = 167. "Zero regressions" now means 167 plus
documented deliberate additions.

**Phase 24 UI flows re-pinned (addition #6).** The old anchors
(`vs19_690_076`, `p300480`'s position on it, title `"ABB/21"`) came from
sitting 690, which the stratified sample does not include — so both flows
would fail loudly, exactly as Phase 24 predicted. Re-pinned:
- **Flow 5 (`testVotazioniListScopeLineTalliesAndSourceLink`) → fully
  structural**: it no longer pins any vote id. It finds the first
  `vote.event.*` row (excluding `.source.`) whatever event it is, asserts
  the four tallies + Esito, and asserts a `vote.event.source.*` link exists.
  The scope-line assertion is now content-based (contains "votazioni",
  data-driven N > 0) rather than an exact-string regex, since the copy
  changed (§8).
- **Flow 6 (`testVoteHistoryOutcomeChipAndTitleSearchCompose`) re-pinned**:
  `p300480` (Giachetti) is **Contrario** on `vs19_577_001` (the final vote
  on DDL n. 2423, "consenso informato"), and `"2423"` is a title substring
  unique to that one vote among his — so Contrario keeps it, Favorevole
  empties the filter. This compose logic inherently needs one vote with a
  known position, so it cannot be made structural like flow 5; a
  **comment in the test records that these three anchors break on any future
  votes.json change** ("re-pin", not "regression").

---

## 8. Data-visibility copy (rule 9 / addition #5) — states what the sample is *of*

Not just an updated N — the copy now states the sample is a coverage-driven
stratified pick, part procedural:
- **`VotazioniListView` scope line**: "Campione **stratificato** di N
  votazioni importate — non l'archivio completo", with a caption "Selezione
  per copertura: sedute distribuite su più mesi, in parte voti procedurali
  (ordini del giorno), in parte votazioni finali su atti." (N derived).
- **`Data/sources.json` note** (shown on the "Fonti e dati" screen, derived
  by `make_manifest.py::votazioni_scope_note`): now "Campione stratificato
  di 30 votazioni … selezionate per copertura su 10 sedute distribuite in
  più mesi, in parte voti procedurali … in parte votazioni finali su atti"
  (count and sitting-count both derived from `votes.json`).
- **`README.md`** and **`docs/DATA_SOURCES.md`**: the "12 curated votes /
  single sitting" prose replaced with the 30-vote stratified description,
  and the README roadmap moved the stratified-scope + lazy-loading item from
  "Open (V4 candidate)" to "Shipped in v4".

The `HomeView` "Come funziona" explainer needed no change — it explains
elections/collegi, never the votes sample; the votes entry point CTA
already reads "Votazioni in Aula (campione)".

---

## 9. Methodology gate re-measured (same commit) — 1 of 6 → 5 of 6

Per `docs/v3/votes-methodology.md`'s own re-evaluation protocol, re-measured
from the new `votes.json` in this commit (per-line before/after):

| # | Requirement | Phase 20 | Phase 27 | Status |
|---|---|---|---|---|
| 1 | ≥ 30 events | 12 | **30** (11,899 positions) | ✗ → ✓ |
| 2 | ≥ 3 distinct sittings | 1 | **10** | ✗ → ✓ |
| 3 | ≥ 6 months span | 1 day | **8.9 months** (2025-10-22…2026-07-21) | ✗ → ✓ |
| 4 | ≥ 2 distinct atti | 0 atto-bearing | **15 atto-bearing, 9 distinct atti** | ✗ → ✓ |
| 5 | `astenuto` its own category | ✓ | ✓ (Astenuto 461 of 11,899) | ✓ |
| 6 | group membership at vote date | ✗ | **✗ — still no historical-membership import** | ✗ |

**5 of 6.** Line 6 stays red: `representatives.json` carries only the
*current* parliamentary group, and attributing a 2025 vote to a 2026 group
would be fabrication — that import is **Phase 28's** job.

**Phase 29 (alignment metric) inherits NOT RUN as a known outcome
(addition #7).** The gate requires all six; line 6 fails; therefore no
vote-derived metric may ship and Phase 29 remains a legitimate NOT RUN
until Phase 28 lands. Grep-verified: the pinned metric label / any metric
vocabulary is **absent from all app code** (present only in
`docs/v3/votes-methodology.md`).

---

## 10. Post-27 bundle size (addition #3) — for Phase 30 to measure, not assume

`Politici/Data/` total is now **5,673,574 B (5.41 MiB)**; real-only (excl.
the three `*.sample.*` fixtures) **5,658,809 B (5.40 MiB)** = **54.0% of the
~10 MiB soft ceiling**. `votes.json` grew **711,439 → 1,767,926 B (+1.01
MiB)**, on top of Phase 25's two plurinominale GeoJSON files (+~1.31 MiB).
Both landed after Phase 30's size gate was drafted — **Phase 30 must gate
against this measured 5.40 MiB (≈4.6 MiB of headroom), not against its own
earlier spec.**

---

## 11. Acceptance criteria

| # | Criterion | Outcome |
|---|---|---|
| 1 | Probe table + pinned selector rules committed; every config limit traces to a measurement + headroom | **Met** — §3 (Q3 + window), §4 (pinned rules, selection, determinism); `maxPositionRecords=13000` traces to 30×≤399 + headroom, `maxVotes=30` = selection, byte projection §5 |
| 2 | Validator green with updated constants; both byte gates satisfied with recorded headroom | **Met** — §5: `make validate` exit 0; 84.3% of 2 MiB, 15.7% headroom |
| 3 | Invariant tests over expanded data (tally sums == counts; distinct `voteEventId` set == event-id set; Votazioni scope line new N) | **Met** — §7 (VoteBrowsingTests 12→30), validator invariants, §8 (scope line derives N) |
| 4 | Lazy tests: idempotent concurrent; sample fallback zero events; decode-off-main DEBUG assert; a loading state exercised | **Met** — §6, §7 (3 new tests + fallback test; flow 5 exercises the loading state via `waitForExistence`) |
| 5 | Methodology gate re-measured in the same commit, per-line before/after | **Met** — §9 |
| 6 | No metric string in app code (grep); suite green vs current baseline + documented deliberate changes | **Met** — §9 grep clean; §7 suite 167/167 = 164 + 3 |

**Deviations, stated plainly:**
1. **Full metadata window, not a tight 6-month floor.** The plan said
   "≥6 months"; the shipped selection spans 8.9 months because the atto
   linkage is temporally segregated (§3) and reaching the atto-rich older
   half is what actually flips line 4 (15/9/9 vs 5/2/3 for a tight spread).
   ≥6 months is exceeded, not missed.
2. **`fetch_camera_votes.py` gained detail chunking.** Not a scope-logic
   change (that stays in `votes_scope.json`) — a retrieval-mechanism change
   required to keep 30-event fetches under the row cap, as the plan's
   "existing chunked-VALUES path (10 URIs/request)" anticipated.
3. **App data-models marked `nonisolated`** (§6) — a consequence of
   decoding off-main under default-MainActor isolation, scoped to the vote
   models + `DataProvenance` + `LocalJSONLoader.decode`, leaving the shared
   `TolerantStringEnum` and the District/Representative enums untouched.

---

## 12. Diff scope for this commit

```
Politici/Data/votes.json                       (regenerated — 30 events / 11,899 positions)
Politici/Data/sources.json                     (regenerated — retrievedAt + count/note)
tools/config/votes_scope.json                  (explicit mode: 30 URIs + annotated selection manifest)
tools/fetch_camera_votes.py                    (10-URI detail chunking, fail-loud)
tools/make_manifest.py                         (stratified votes note)
tools/select_votes_scope.py                    (new — offline deterministic selector)
tools/probes/probe_votes_metadata_window.py    (new — metadata window probe)
tools/probes/probe_camera_votes_metadata_window.rq (new)
Politici/Services/VoteService.swift            (@Observable, loadIfNeeded, off-main decode)
Politici/Services/GeoJSONLoader.swift          (LocalJSONLoader.decode nonisolated)
Politici/Models/Vote.swift                     (vote models nonisolated + inlined tolerant decode)
Politici/Models/DataProvenance.swift           (nonisolated)
Politici/Views/VotazioniListView.swift         (loading state + stratified scope copy)
Politici/Views/VoteHistoryView.swift           (loading state)
Politici/Views/RepresentativeProfileView.swift (recent-votes loading state)
PoliticiTests/{VoteBrowsing,SchemaV2,ServiceLookup,Decoding}Tests.swift (async loads, constants, +3 lazy tests)
PoliticiUITests/SmokeFlowUITests.swift         (flows 5 structural, 6 re-pinned)
README.md, docs/DATA_SOURCES.md, docs/v3/votes-methodology.md, tools/SOURCES.md (copy/attribution sync)
docs/v4/27-votes-stratified.md                 (new — this report)
docs/plan/README.md                            (Phase 27 status row: pending -> done)
```

(`tools/raw/.fetch_metadata.json` and `tools/raw/SOURCES.txt` were also
updated but are gitignored — the committed mirrors are `sources.json` and
`tools/SOURCES.md`.)

Remote actions are the user's. Not run here:

```
git push origin v4
```
