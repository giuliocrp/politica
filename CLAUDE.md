# CLAUDE.md

## Project Purpose

Politica (display name "Politica"; Xcode project/target/scheme name "Politici")
is a local-first iOS app for exploring Italian parliamentary civic
information — real electoral colleges, real representatives, and a curated
set of real roll-call votes, rendered on a native MapKit map entirely
offline at runtime. As of v2, the data is real and officially sourced (see
`docs/DATA_SOURCES.md`), but the app remains an **independent, unofficial
prototype** — not affiliated with, endorsed by, or a source of record for
the Camera dei Deputati, the Senato della Repubblica, ISTAT, or any other
institution. A handful of fictional fixtures from the original v1
prototype are preserved for tests only (see "The `*.sample.*` convention"
below) and are never shown in the shipping app UI.

## Standing Constraints

These apply to this and all future phases of work on this repository:

1. Never rename the Xcode project, target, scheme, or bundle identifier.
2. All **in-app, user-facing** strings must be in Italian. Repository
   documentation (this file, `README.md`, `docs/`, commit messages, code
   comments) is written in English — the two are independent; don't
   Italianize docs or accept English strings inside the app.
3. The **shipping app** is local-first at runtime: no networking code, no
   backend, no analytics, no remote image/asset fetching. This does not
   extend to the `tools/` developer pipeline — its `fetch_*.py` scripts are
   *expected* to query official SPARQL endpoints over the network; what
   they produce is then committed as bundled, offline data. Never blur
   this line by adding network calls to anything under `Politici/`.
4. Never present fictional/sample data as real. Never fabricate
   "real-looking" political data, a plausible-sounding but unsourced value,
   or a constructed URL/deep-link the source data doesn't actually provide.
   When a source doesn't have a value, leave the field `null`/absent — don't
   guess. When a raw source value doesn't match an expected vocabulary,
   decode it to an explicit "unknown" case (`TolerantStringEnum`) with a
   logged warning, never a crash and never a silent best-guess mapping to
   an existing case unless that mapping is itself disclosed and justified
   (see `docs/v2/04-votes-import.md` for a worked example: `"Non ha
   votato"` → `.assente` is disclosed as a best fit, not asserted as
   certain).

## Build & Test Commands

```bash
# Build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Politici.xcodeproj -scheme Politici -destination 'generic/platform=iOS Simulator' build

# Find an available simulator
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl list devices available | grep iPhone

# Full test suite (substitute a simulator name from the list above)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Politici.xcodeproj -scheme Politici -destination 'platform=iOS Simulator,name=<SimName>' test
```

Note: xcodebuild's parallel test output occasionally truncates a
passed-test log line mid-name (three documented v3 occurrences, plus a
**fourth in v4 Phase 30** — 203 `passed` log lines against the `.xcresult`'s
`totalTestCount 204`, traced in the log body to
`SmokeFlowUITests.testVotazioniListScopeLineTalliesAndSourceLink()` whose line
was cut mid-word at `' pa` by an interleaved `xcodebuild[…]
IDELaunchParametersSnapshot` diagnostic; the test passed) — the
authoritative signals are the exit code and the failed-line count, and a
missing name must be verified in the log body before being called a
failure. Note the Phase 30 sighting truncated at the **line tail** rather
than mid-*name*: the class and method were intact and only the `passed`
verdict word was mangled, so a `grep -c "passed"` undercounts while a
`grep "Test case"` name inventory still finds it — check both before
concluding a test is missing. A **fifth sighting, in the v4 Phase 31
closeout**, was the other shape again — the same
`IDELaunchParametersSnapshot` diagnostic cut
`DataVintageTests.testShippingVintageMatchesIndependentlyComputedMaxRetrievedAt`
**mid-name** at `…testShippingVintageMatchesIn`, which defeats a name
inventory *and* a `passed` count. Both truncation shapes are now on record,
so neither log-side check is sufficient alone: the `.xcresult`'s
`totalTestCount`/`passedTests`/`failedTests` is the only authority.
**v4 Phase 32A stops counting sightings, because they stopped being rare.**
Across that phase's ten `xcodebuild test` runs, **five full-suite runs
truncated a line and every one of the five short single-test runs did
not** — 8 truncated lines in total, all mid-name, all on tests the
`.xcresult` reported as passed. It also widened the pattern: the
interleaving diagnostic is **not always** `IDELaunchParametersSnapshot` —
`VoteChoiceAccessi…` was cut by an `iOSSimulator: Failed to launch app with
identifier:` message and `SmokeFlowUITests.testVoteHistoryOutcomeChipAndTitleSe…`
by `IDETestOperationsObserverDebug`. So: expect a long run's log to
disagree with the `.xcresult` by one or two lines, never pattern-match on
the interrupting message, and read the count from the `.xcresult`. The
UI-test target has also flaked on simulator-clone
infrastructure — a running tally, since these recur: the template
`PoliticiUITests` twice (Phase 17/18 reports), then
`AccessibilityAuditUITests.testAccessibilityAuditDistrictDetailBothChambers`
once in Phase 29 (131 s vs. its ~65 s siblings; the heaviest-navigation audit,
which relaunches and re-drives the map twice), then **twice more in v4
Phase 32A** — an `FBSOpenApplicationServiceErrorDomain` "failed to launch"
on the app in the baseline run and on the `xctrunner` in an audit-only run,
both of which the infrastructure retried on its own so the runs still ended
green — **five-plus** occurrences.
**The log can hide a failure, not just a pass.** The truncation note above is
written around log lines that undercount *passes*; the post-v4 concurrency
sweep hit the opposite and more dangerous direction — a run whose `.xcresult`
reported `testsFailedCount 1` while `grep -c "Test case.*failed"` on the log
returned **0**. Had the log been trusted, a red run would have been reported
green. This is the same divergence, so the same rule settles it, but state it
in both directions: the `.xcresult` is the authority for failures as well as
for counts, and a log grep must never be the evidence that a run was clean.

**Accessibility audits fail under machine load, and the failure moves.** The
same sweep saw two consecutive full-suite runs fail with
`com.apple.xcode.xctest.accessibilityAudit Code=-56 "Audit failed to complete
in time"` — on a *different* test each run
(`testAccessibilityAuditDistrictDetailBothChambers`, then
`testAccessibilityAuditVotazioniAndVoteHistory`), never the same one twice.
`performAccessibilityAudit()` carries an internal deadline, and the heaviest
audits miss it when the host is loaded; 1-minute load averages were in the
hundreds, driven by the preceding full-suite runs' own parallel simulator
clones. A third run, started only once the 1-minute average had fallen below
8, passed 231/231 with zero failures. So: **a `-56` audit timeout is a
statement about the host, not the screen** — the tell is that it relocates
between runs, whereas a real defect pins the same test. Let the machine settle
before re-running rather than re-running immediately, which only deepens the
contention being diagnosed.

Re-run once and diagnose before suspecting the code. **Caveat on the re-run:**
running the flaky test *alone* removes the parallelism (concurrent simulator
clones) that triggers the flake, so an isolated green is *weaker* evidence than
a clean full-suite green — the honest state after a flake is "one full-suite run
at N−1/N with a diagnosed environmental failure"; a second full-suite run is
what actually settles it.

Note (re-running after a bundled-data change): **changes to a bundled data
file (anything under `Politici/Data/` — the app decodes and displays these)
made *after* a validating test run require either a re-run or a documented
check proving no test depends on the changed content.** A green suite only
certifies the tree it ran against; regenerating `votes.json`, `sources.json`,
etc. afterward invalidates that certification unless the change is provably
test-irrelevant. Phase 24 re-ran on the exact committed tree after a late
comment edit; Phase 27 regenerated `sources.json` (a displayed note) after
its validating run and instead grep-confirmed no test asserts the note text
(only `schemaVersion == 2` / non-empty `sources`) — both are legal under
this rule; the grep-and-document path just has to be written down, not
taken silently.

Note (declared test count): when re-deriving the "declared" count from
source, count **occurrences** of `func test…(` (+ `@Test`), never
`sort -u` unique names. XCTest identifies each test as `Class/method`, so
two classes may legally carry an identically-named test — a common,
desirable case when one test class deliberately mirrors another (e.g.
`RegioneTests` mirrors `CircoscrizioneTests`, both with
`testGroupingForEsteroNeverReturnsAnyone`). `sort -u` silently collapses
those into one and undercounts declared vs. the `.xcresult`
`totalTestCount`; the earlier `sort -u` figures (136/144/158) were correct
only because no collision then existed. The runtime-from-log count in
`docs/v4/23-baseline-audit.md` §2 is already collision-safe — its regex
captures `Test case 'Class.method()'`, class prefix included — so only the
from-source declared count needs the occurrence rule. `.xcresult`'s
`totalTestCount` remains the final authority.

Note (`make manifest` in a fresh checkout or new worktree): in a normal
working checkout `make manifest` is reproducible and safe — it reads each
real source's `retrievedAt` from `tools/raw/.fetch_metadata.json`, so
re-running it leaves those dates byte-identical. The one catch is that
this cache is **gitignored** (it lives under `tools/raw/`), so in a
**fresh checkout or a new git worktree** it is absent and
`make_manifest.py` silently falls back to `date.today()`, rewriting
**every** `retrievedAt` to the current date — a spurious change the scoped
`sources.json` diff protocol would otherwise attribute to real work. So
the precaution applies specifically when the cache might be absent (fresh
checkout, new worktree): first confirm `tools/raw/.fetch_metadata.json`
exists and holds the real committed fetch dates; if it is absent,
reconstruct it from the `retrievedAt` values already in the committed
`sources.json` (and say so in the report) before running `make manifest`.
(A hardening candidate — making `make_manifest.py` fail loudly on an
absent cache — is tracked in the deferred list in
`docs/plan/00-baseline-and-rules.md`, not here.)

## Durable conventions established in v4

- **Plurinominale collegio ids are prefixed `CP`/`SP`** (`CP120101`,
  `SP120001`) — Phase 25. Uninominale Camera ids are bare ISTAT codes and
  Senato's carry the v3 `S` prefix, so without a distinct prefix a
  plurinominale collegio would collide with a uninominale one (`120101`
  names both a Camera uninominale and a Camera plurinominale collegio in
  ISTAT's own numbering). Every id across all four boundary files is unique
  and the validator enforces it.
- **Senator `electionType` is populated, `null` only where the source has
  no answer** — Phase 26, with explicit user approval on the vocabulary
  mapping: 121 plurinominale + 73 uninominale + 2 estero, and the 5 a-vita
  senators keep `null` because they were not elected at all. This closed a
  v3 deferral; it did not invent a category.
- **Membership intervals are half-open `[start, end)` and `membershipAt`
  returns `nil` outside coverage** — Phase 28. A caller renders "unknown",
  never the last-known or the current group. The composed interval id is
  minted at import because the source node is a blank node.
- **Comuni provenance: the assignment is cited, the geometry is not** —
  Phases 30/30B. A comune-**name** query answers with the
  `CU20_COD`/`SU20_COD` assignment ISTAT publishes (a sourced fact, and
  legitimately a *set* — Roma spans seven Camera collegi and all seven are
  shown); geometry is retained only for the **coordinate** path. Refreshing
  the comuni table against a current-vintage ISTAT product would *break*
  the D.Lgs. 177/2020 join, so it is deliberately pinned to that vintage.
- **A metric constant is never a bare number in a view.** Phase 29's
  minimum denominator (10), tie rule and copy all live on `GroupAlignment`
  and are user-signed-off; `Alignment.insufficientData` carries **no**
  number, so "0 %" is not representable when the denominator is too small.
- **Display formatters are pinned to Europe/Rome, like the parsers** —
  Phase 31. Every `Date` the app renders is a Rome calendar day parsed from
  a bare `yyyy-MM-dd`; a device-timezone formatter rendered it one day
  early west of Rome. `DateFormatting` exposes `make…(timeZone:)` factories
  so the guard is testable on any host.
- **Everything in `Models/` is `nonisolated`; main-actor isolation is for
  services only.** The project sets `SWIFT_DEFAULT_ACTOR_ISOLATION =
  MainActor` with `SWIFT_APPROACHABLE_CONCURRENCY = YES`, so every
  declaration — *including every protocol conformance* — is `@MainActor` by
  default, and a main-actor-isolated conformance cannot be used from a
  nonisolated context (a hard error under the Swift 6 language mode). The
  models are pure Sendable value types decoded from bundled JSON by
  `VoteService`'s deliberately **off-main** decode and by nonisolated XCTest
  methods, so `nonisolated` is the honest declaration, not a silencer. Two
  traps, both on record:
  - **`nonisolated` on a type does *not* cover a conformance declared in a
    separate `extension`** — that extension picks up the file default
    independently. `nonisolated struct Vote` with a plain
    `extension Vote: Codable` left `Vote`'s `Decodable` conformance
    main-actor-isolated *while `VoteService` decoded it off the main actor*.
    Write `nonisolated extension Vote: Codable`. Conformances declared
    inline on a `nonisolated` type, and nested types inside one, are covered.
  - **Where the isolation is real, annotate the test, not the type.**
    `ComuneService`/`GeocodingService`/`DistrictService` hold mutable state
    and load eagerly on the main actor for the SwiftUI environment; their
    test classes carry `@MainActor`. Stripping isolation off a stateful
    service to quiet a test warning would be the dishonest fix.
  These warnings are **invisible on incremental builds** — only a full
  recompile of the test target shows them, so a partial rebuild that touches
  two files will report a handful and hide the rest.
- **Test-count baseline definition** — since Phase 24 the declared and
  runtime counts are equal (the template's ×4 `testLaunch` multiplier is
  gone), and "zero regressions" means the current `.xcresult`
  `totalTestCount` plus the sum of documented deliberate additions. The
  `.xcresult` is the authority, never a log grep (see the truncation note
  above).
- **Accessibility audits cover whole screens, not first viewports** —
  Phase 32A. `performAccessibilityAudit()` only ever sees what is on
  screen, so an audit that never scrolls certifies one viewport.
  `AccessibilityAuditUITests.audit(_:viewports:)` pages through a screen
  and merges the per-viewport inventories (max per key, a deliberate lower
  bound). Any new screen gets a `viewports` value that reaches its bottom,
  or a written note saying which bound was chosen and why.
- **An `accessibilityIdentifier` belongs on a leaf or on a `.combine`
  container, never on a plain container with identified descendants** —
  Phase 30B found it, Phase 32A fixed the last two instances (the two
  segmented `Picker`s, whose container identifier was propagating onto both
  segments). A segmented `Picker` is *not* one accessibility element.
- **Existing in the accessibility tree is not the same as being reachable
  on screen.** Wherever a UI test's claim is that a user can *see or use*
  something, it must assert **hittability after scrolling**
  (`scrollUntilHittable`), never `.exists` — XCUITest counts tree elements
  regardless of whether any of them can be reached, and
  `performAccessibilityAudit()` only ever describes the current viewport.
  Three defects in the v4 cycle shared this single cause: Phase 31's Home
  footer rendered below the fold and was never visually verified; Phase
  24's audits traversed only each screen's first viewport (63 findings
  against **123** on the same eight screens, same tree, same day); and
  Phase 32A found `AddressSearchView`
  never scrolled, so Roma's three Senato collegi — Phase 30B's central
  deliverable — were unreachable while `SmokeFlowUITests` flow 7 passed
  throughout, because it asserted `.exists` on rows that were in the tree and
  off the screen. `XCTAssertFalse(…exists)` remains the correct assertion for
  **absence**: something absent from the tree is unreachable by construction,
  so no scrolling can strengthen it. The suite has not yet been swept for the
  remaining `.exists`-as-reachability sites — they are enumerated in
  `docs/plan/00-baseline-and-rules.md`'s deferred table.

## The V4 plan & per-session workflow

The V4 master plan lives in **`docs/plan/`** — one file per phase
(`phase-23.md` … `phase-32b.md`), shared baseline/rules in
`docs/plan/00-baseline-and-rules.md`, index + status table + the
canonical per-session prompt in `docs/plan/README.md`. Phase reports go
to `docs/v4/`, and the executing session flips the phase's status row in
the same commit as its report.

Standing execution rules (full list in `00-baseline-and-rules.md`):
verify preconditions against actual repo state before writing anything;
gates decided on quoted evidence with NO-GO/NOT-RUN as first-class
outcomes; every network act user-gated with approval quoted verbatim in
the report; **never push, tag (outside phase 32B), or touch GitHub — the
user performs all remote actions personally; print commands instead.**

## Data Files

`Politici/Data/districts.geojson`, `Politici/Data/districts_senato.geojson`,
`Politici/Data/representatives.json`, `Politici/Data/votes.json`,
`Politici/Data/parties.json`, and `Politici/Data/sources.json` are
**generated artifacts** — never hand-edit them. They're produced by the
`tools/` pipeline: `make import`, `make boundaries` (Camera),
`make boundaries-senato`, `make manifest`, `make validate` — bundled as
the fully offline `make all` (validate deliberately last) — or
`make refresh` (network-touching `make fetch` followed by `make all`) to
pull fresh source data first. See `README.md`'s "Data pipeline" section
and `docs/DATA_SOURCES.md` for the full per-source detail and refresh
procedure. If a value in one of these files looks wrong, fix the pipeline
script that produced it and re-run — don't patch the JSON/GeoJSON
directly. Since v3 Phase 20, `votes.json` is the normalized
`{"events":[...],"positions":[...]}` schema keyed on the source-backed
`voteEventId` (the ocd:votazione URI slug); the frozen `votes.sample.json`
keeps the older flat shape and decodes via `VoteService`'s fallback path.

### The generated-data change protocol

After any pipeline run, inspect the `git diff` of every generated file
and explain every change before committing: expected changes are
committed with their explanation, unexpected ones are investigated and
either fixed at the producing script or the file is restored. This
protocol has caught real defects twice (a silently-advancing
`retrievedAt` in Phase 14; a byte-identity break from a `"regione": null`
key in Phase 16) — treat it as load-bearing, not ceremony.

### The refetch protocol (any network fetch)

Re-verify Legislature XIX is still current **at fetch time** (the
aggregate-free `tools/probes/probe_senato_legislature_currency.rq` via
`run_probe.py`); diff source counts before/after; on any drift, stop and
update constants deliberately, never silently; re-sync
`Data/sources.json`, `docs/DATA_SOURCES.md`, `tools/SOURCES.md`, and the
gitignored `tools/raw/SOURCES.txt` in the same commit. **Minimal-scope
fetches are preferred**: a single `fetch_*.py` script may run alone when
only one source needs updating (Phase 17 ran only `fetch_senato.py`);
`make refresh` is the all-sources form. User approval is required before
any fetch, quoted verbatim in the phase report.

### The `*.sample.*` convention

Every real dataset that replaced a fictional v1 fixture has that original
fixture preserved alongside it under a `.sample.` infix — e.g.
`districts.geojson` (real, 147 ISTAT collegi) vs.
`districts.sample.geojson` (fictional, the original 5 rectangles);
likewise `representatives.sample.json`, `votes.sample.json`. These are
**test-only fixtures**, loaded by resource name
(`DistrictService(resource: "districts.sample")`,
`LocalJSONLoader.decode(..., fromResource: "votes.sample")`) where a test
needs small, hand-known, deterministic data (e.g. exact coordinate → known
district-id assertions) that the real 601-representative/147-collegio
dataset can't offer as conveniently. They are never referenced by any
shipping view or service's default resource name, and never described to
a user as anything other than what `provenance: "sample"` says they are.
When adding a new real dataset that replaces a fictional one, follow this
same pattern rather than inventing a different fixture-naming scheme.

## Domain conventions established in v3

- **Chamber-conditional keys, absent not null.** A field that exists for
  only one chamber is *omitted* from the other chamber's records, never
  written as `null`: `mandate` (Senato-only, Phase 17) and
  `circoscrizione` (Camera-only, Phase 18) on representatives;
  `circoscrizione` (Camera) vs `regione` (Senato) on district features.
  The validator enforces both directions.
- **`regione` vs `circoscrizione` are different concepts — never
  conflate.** Camera groups its 147 collegi into 28 `circoscrizione`
  values; Senato's 74 collegi group by the 20 administrative regions,
  unsplit, carried as `regione`. Reusing one name for the other would
  misrepresent the source.
- **Senato ids are unconditionally `"S"`-prefixed** (`S20001` form) — 32
  of 74 raw ISTAT codes would collide with Camera ids otherwise; 221
  unique combined ids are validator-enforced.
- **`MandateType` semantics**: the three raw values are the source's
  verbatim `osr:tipoMandato` literals (`"elettivo"`, the a-vita
  appointment string, the Presidente-emerito string); `.sconosciuto` is a
  decode-time fallback only — the importer fails loudly on unknown
  vocabulary and never writes it. Serving Presidente-emerito count must
  be 0 (validator drift detector). The a-vita badge wording is the
  source's own gender-neutral category phrasing — the source has no
  gender field and gender is never inferred from names.
- **Senato linkage**: only senators whose `tipoElezione` starts with
  `"Eletto uninominale"` link to a collegio (73 at import time); the one
  alias (`"VALLE D'AOSTA"` → ISTAT's bilingual name) is the only
  permitted fuzziness — any other join mismatch fails loudly and must be
  verified and documented, never added ad hoc. Senators' `electionType`
  stays null (an explicitly deferred decision — see
  `docs/v3/17-senato-mandates.md`).
- **Probes convention**: one-off verification scripts live committed
  under `tools/probes/`, their `output/` is gitignored and is **never an
  import source**; network probes run only under the refetch protocol
  with user approval. Endpoint findings on record: `dati.senato.it`
  rejects SPARQL aggregates (403/400 — use plain `SELECT`/`SELECT
  DISTINCT` only) and caps results around ~10k rows; `dati.camera.it`
  accepted plain SELECTs and 10-URI `VALUES` detail queries cleanly
  (Phase 21) — chunk anything that could approach a cap.
- **Favorites**: `UserDefaultsFavoritesStore` (seventh service,
  `@Observable`) persists `{"schemaVersion":1,"representativeIds":[...]}`
  under `"favorites.v1"`; corrupt payloads self-heal to empty with a
  console warning; unresolvable ids are skipped at render but retained in
  the store. Purely local, never leaves the device.
- **No vote-derived metric ships** until every line of
  `docs/v3/votes-methodology.md`'s six-line gate passes — that document
  binds any future metric work.
- **Frozen history**: `docs/v2/*`, `docs/history/*` (including
  `backfills/`) are never edited. Corrections land in living documents or
  new `docs/v3/*` reports; lettered sub-phases (13B, 15b) are the
  accepted shape for user-gated inserts between planned phases, and user
  decisions are quoted verbatim in the report that acts on them.

## Working methodology established across v2

These aren't hard rules in the sense of #1–4 above, but they're the
approach every v2 phase actually followed (and every v3 phase after it)
that produced a working, reconciled result each time — deviating from
them is more likely to produce fabricated-looking or
silently-inconsistent work than a genuine shortcut:

- **Audit/verify before implementing.** Before writing pipeline code
  against a new data source, inspect the *actual* raw data first (a live
  SPARQL introspection query, an `ogrinfo` schema dump, a direct file
  read) rather than trusting a task's stated assumption about its shape.
  Several real phases changed course because of this: the boundaries
  phase's `CU20_C1` field turned out not to be a "region" despite its
  name; the linkage phase's existing `?collegio` SPARQL variable turned
  out to be the wrong granularity entirely (plurinominale, not
  uninominale) and required live introspection to find the right one.
  Document what was actually found, not just what was assumed, in the
  corresponding `docs/v2/*.md` report.
- **Diagnose root cause before changing either the code or the test.**
  When a test fails, don't reflexively loosen the assertion to make it
  pass — figure out whether the implementation or the test's own
  expectation is wrong, and fix that specific thing. Example: when
  `DistrictBoundariesTests` failed after the ISTAT boundaries import, the
  fix was tracing it to a genuine `MKGeoJSONDecoder` behavior gap
  (MultiPolygon geometry decodes to one `MKMultiPolygon`, not flattened
  `MKPolygon` entries) and fixing `GeoJSONLoader` — not adjusting the
  test's expected multi-part-district count downward until it passed.
  Where a test's own expected values need independent verification (e.g.
  "this coordinate resolves to this real collegio id"), verify them
  against the source data with a standalone script before hardcoding them,
  not by trusting whatever the implementation currently returns.
- **Report what was found, including inconvenient findings, not just what
  was fixed.** Every non-trivial phase has a `docs/v2/*.md` report
  documenting real findings (schema surprises, judgment calls, things that
  turned out already done, budget constraints that reduced scope below
  the nominal target) — these are written *for* future work to trust
  without re-deriving, so they need to be honest about limitations, not
  just a changelog of successes.

## File Layout Conventions

```
Politici/
├── App/           — @main entry point and root NavigationStack/view
├── Models/         — Codable domain types + schema-v2 provenance/tolerant-decoding infrastructure
├── Services/       — data loading, lookups, geocoding; injected via ServiceContainer
├── Utilities/      — pure helpers (PointInPolygon, DateFormatting, Initials, ColorHex) with no service state
├── Views/          — SwiftUI screens, one file per screen; typed navigation via AppRoute
└── Data/           — bundled JSON/GeoJSON (generated artifacts — see "Data Files" above)

tools/              — data pipeline: fetch (network) / import, boundaries, validate, manifest (all offline)
├── queries/         — pinned .rq SPARQL query files, never inline query strings
├── config/          — pipeline scope/budget config (e.g. votes_scope.json)
├── probes/          — committed verification scripts; output/ gitignored, never an import source
└── raw/             — gitignored fetch cache — never commit anything here

docs/v2/            — phase-by-phase v2 reports (frozen — never edit)
docs/v3/            — phase-by-phase v3 reports + votes-methodology.md + a11y-checklist.md
docs/history/       — audited v1–v2 implementation record (frozen — never edit)
docs/DATA_SOURCES.md — canonical, cross-checked per-source license/attribution reference
```

- Services are accessed through the SwiftUI environment (`@Environment(\.services)`),
  not via ad hoc singletons reached for directly from views.
- Small view components shared by exactly two related screens live alongside
  their primary consumer (e.g. `RepresentativeRow`/`InitialsAvatar` in
  `DistrictDetailView.swift`, `VoteRow`/`VoteBadge` in `VoteHistoryView.swift`,
  `BulletRow` in `FontiEDatiView.swift`) rather than in a separate "shared
  components" file. A component reused by three or more screens (e.g.
  `RepresentativeRow`, now used by `HomeView`, `RepresentativeListView`,
  and `DistrictDetailView`) can outgrow this and move to a dedicated file —
  use judgment, but don't default to a shared-components file prematurely.
- Design/process notes for v2 work live under `docs/v2/`; source/license
  attribution detail lives in `docs/DATA_SOURCES.md` (must stay in sync
  with `Data/sources.json` — see that file's own cross-check note).
