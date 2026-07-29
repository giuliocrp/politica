# Politica Italia

A local-first iOS app for exploring Italian parliamentary civic
information: real electoral colleges, real representatives, and a curated
set of real roll-call votes, rendered on a native MapKit map — entirely
offline at runtime.

**Politica is an independent, unofficial prototype.** It is not affiliated
with, endorsed by, or a product of the Camera dei Deputati, the Senato
della Repubblica, ISTAT, or any other institution. It uses no institutional
logos or emblems. Data is a point-in-time snapshot (see "Data sources &
provenance" below) — always cross-check anything you rely on against the
official sources linked in the app's "Informazioni e fonti" screen or
[`docs/DATA_SOURCES.md`](docs/DATA_SOURCES.md).

## What's real, and what isn't

Every dataset the app ships is now real and officially sourced, with one
narrow exception:

| Dataset | Status |
|---|---|
| 147 Camera dei Deputati collegi uninominali (boundaries) | Real — ISTAT, D.Lgs. 177/2020 |
| 74 Senato della Repubblica collegi uninominali (boundaries) | Real — ISTAT, same release (v3 Phase 16) |
| 49 Camera + 26 Senato collegi plurinominali (boundaries) | Real — ISTAT, same release (v4 Phase 25) |
| 601 representatives (400 deputies + 201 senators, XIX Legislature) | Real — dati.camera.it / dati.senato.it |
| 147/147 uninominale-collegio → current-deputy linkage | Real, derived (see [`docs/v2/03-linkage-report.md`](docs/v2/03-linkage-report.md)) |
| 73/74 Senato collegio → current-senator linkage | Real, derived (v3 Phase 17; the one uncovered collegio has no claimant in the source — see [`docs/v3/17-senato-mandates.md`](docs/v3/17-senato-mandates.md)) |
| 245/245 plurinominale deputy → plurinominale-collegio linkage | Real, derived (v4 Phase 25) |
| Senator mandate categories (196 elettivo + 5 a vita), senator `electionType` + `regione` (v4 Phase 26), deputy circoscrizioni (28 + Estero) | Real, verbatim/derived from the sources |
| 30 curated Camera roll-call votes (stratified sample), 11,899 per-deputy positions | Real — dati.camera.it |
| 468 Camera group-membership intervals for the 400 serving deputies | Real — dati.camera.it `ocd:aderisce` (v4 Phase 28) |
| 7,904 comuni with their published collegio assignment + one interior point each | Real — ISTAT `UT_Collegi2020`, same D.Lgs. 177/2020 release (v4 Phases 30/30B) |
| The original 5 fictional sample districts / 14 sample representatives / 37 sample votes | Fictional, preserved at `*.sample.*` for tests only — never shown in the app UI. The in-app sources screen lists this fixture with the manifest's own note stating it is entirely invented |

## Features

- **Chamber-aware, layer-aware interactive map** of all 296 real collegi —
  221 uninominali (147 Camera + 74 Senato) and 75 plurinominali (49 Camera +
  26 Senato, v4 Phase 25) — switchable via two segmented pickers (chamber,
  and collegio type) — rendered as native `MKPolygon`/`MKMultiPolygon`
  overlays (90 of the 221 uninominali are genuine multi-part geometries) —
  tap a collegio to see its detail. `CollegiListView` mirrors both pickers,
  so every layer is reachable without the map.
- **601 real representatives** — 400 Camera deputies + 201 Senato
  senators, XIX Legislature, each with party, parliamentary group, and
  committee memberships; deputies carry how they were elected and their
  circoscrizione, senators their verbatim mandate category (the 5 life
  senators get a dedicated profile badge).
- **147/147 Camera and 73/74 Senato collegio ↔ current-member linkage** —
  every collegio page shows its actual directly-elected deputy or
  senator, resolved by structural joins on the official SPARQL graphs
  (verified against by-elections and vacancies; the one Senato collegio
  with no serving senator in the source shows an honest empty state).
- **Plurinominale context on Camera collegio pages** (v3 Phase 18): each
  page also lists the proportional-list deputies of its circoscrizione,
  with an explainer that they represent the whole circoscrizione. Since v4
  Phase 25 each plurinominale collegio also has a **page of its own**,
  listing the deputies actually elected there (Camera; the Senato
  plurinominale layer ships as geography with an honest empty state).
- **Regione context on Senato collegio pages** (v4 Phase 26): the mirror of
  the above — each Senato collegio page lists the proportional senators of
  its regione, and senator profiles carry a "Regione: {name}" line.
- **30 curated real Camera votes** with 11,899 individual per-deputy
  positions (favorevole/contrario/astenuto/assente), each traceable to its
  official "scheda votazione" source page — browsable per representative
  (with outcome filters and title search) and per votazione (the
  "Votazioni" screen with per-event tallies; v3 Phase 20). This is a
  **stratified sample chosen for coverage** (v4 Phase 27), not "the N most
  recent": 3 votes from each of 10 sittings spread across ~9 months,
  deliberately part procedural and part final votes on atti — decoded lazily
  off the main thread. One derived metric now ships (v4 Phase 29): a per-deputy
  within-group **alignment** figure on the profile, strictly behind the
  six-line methodology gate — see
  [`docs/v3/votes-methodology.md`](docs/v3/votes-methodology.md).
- **Preferiti** (v3 Phase 19) — star representatives from their profile
  and find them again from Home; stored only on-device in `UserDefaults`.
- **Address search with autocomplete** (`MKLocalSearchCompleter`), answering
  along **two deliberately distinct paths** (v4 Phase 30 + 30B):
  - a **comune name** is answered from the **collegio assignment ISTAT itself
    publishes** for that comune, carried in the bundled table of all 7,904
    Italian comuni — a sourced fact rather than a value derived from
    simplified geometry, fully offline. It is legitimately multi-valued: the
    six comuni divided between several uninominale collegi (Roma spans seven
    on the Camera side) are shown with **all** of them, never with one
    presented as the answer. Homonyms like `Castro` are disambiguated by
    province first.
  - **anything else** — a street address, `"Roma Termini"` — is resolved to a
    coordinate (`CLGeocoder` when online, then the same comuni table's
    interior points, then the original five-city substring fallback) and then
    to a collegio by **point-in-polygon** against the shipped boundaries.
- **Searchable representative list** (`RepresentativeListView`) — all 601
  representatives, filterable by party (12 deduplicated party chips merging
  Camera-sigla/Senato-full-name spelling variants of the same party).
- **`CollegiListView`** — a fully searchable, chamber-aware and
  layer-aware, VoiceOver-navigable list of all 296 collegi (221 uninominali
  + 75 plurinominali), serving as the accessible alternative to tapping
  polygons on the map (which VoiceOver cannot discover or select).
- **"Informazioni e fonti"** attribution screen, rendered live from
  `Data/sources.json` — every source's name, license, retrieval date and
  (since v4 Phase 32A) its provenance note, with a link to the original.
  The note is what makes the one fictional entry say on screen that it is
  fictional. Reachable from the Home footer, which also states the last
  retrieval across all sources (v4 Phase 31).
- **"Come funziona l'elezione"** explainer on Home, stating plainly which
  representatives are mapped to geography (both chambers' uninominale
  winners) and which aren't (plurinominale/estero, life senators).
- **Accessibility**: non-color-only vote-outcome badges (icon + text +
  distinct VoiceOver label for every case), VoiceOver labels/hints across
  every interactive flow, Dynamic Type support (no truncating
  `minimumScaleFactor` on real content), and ≥44×44pt hit targets — see
  [`docs/v2/a11y-checklist.md`](docs/v2/a11y-checklist.md) for the v2
  audit, [`docs/v3/a11y-checklist.md`](docs/v3/a11y-checklist.md) for
  the v3 surfaces, and
  [`docs/v4/a11y-checklist.md`](docs/v4/a11y-checklist.md) for the v4
  surfaces plus the full triage of the automated
  `performAccessibilityAudit()` findings — each with its disclosed
  limitations and pending human checks.

## Architecture

- **UI:** SwiftUI, MapKit for SwiftUI (`Map`, `MapPolygon`, `MapReader`,
  `MKGeoJSONDecoder`).
- **Pattern:** MVVM/service pattern. A single `ServiceContainer`
  (`DistrictService`, `RepresentativeService`, `VoteService`,
  `GeocodingService`, `ManifestService`, `PartyStyleService`, the
  `@Observable` `FavoritesStore` from v3 Phase 19, and — added in v4 —
  `MembershipService` (Phase 28) and `ComuneService` (Phase 30)) is built
  once at launch and injected into the view hierarchy via
  `.environment(\.services, services)`; views read it back with
  `@Environment(\.services) private var services` rather than reaching for
  a `.shared` singleton directly.
- **Geometry engine:** districts decode via `MKGeoJSONDecoder` into native
  `MKPolygon`/`MKMultiPolygon` (with interior-ring holes handled
  natively). Point-in-collegio resolution first narrows to bounding-box
  candidates (`District.boundingMapRect`), then runs exact even-odd
  ray-casting only on those candidates — measured well under 1s for 1,000
  random Italian coordinates per chamber (see
  `PoliticiTests/DistrictBoundariesTests.swift`).
- **Schema v2**: every model carries a `provenance` field
  (`.official`/`.sample`, defaulting to `.sample` when absent so old
  fixtures keep decoding), and enums that model external vocabulary
  (`VoteChoice`, `VoteResult`, `CollegioType`, `ElectionType`,
  `MandateType`) decode *tolerantly* — an unrecognized raw value becomes
  an explicit `.sconosciuto` case rather than throwing and blanking the
  whole file (`TolerantStringEnum`,
  `Politici/Models/TolerantDecoding.swift`). Since v3 Phase 20,
  `votes.json` uses a normalized `{"events":[...],"positions":[...]}`
  schema keyed on the source-backed `voteEventId` (the frozen flat
  `votes.sample.json` fixture still decodes via a fallback path).
- **Local-first at runtime, no exceptions**: the app itself makes no
  network calls — no backend, no analytics, no remote image fetching
  (representative "photos" are locally-generated initials avatars, never a
  downloaded image). All data is bundled JSON/GeoJSON, read once at launch.
  Network access is used **only** by the developer-side `tools/` data
  pipeline (see below), never by the shipping app.
- **Language:** every user-facing string is Italian.

## Data pipeline

Every file under `Politici/Data/` — the four boundary GeoJSONs,
`representatives.json`, `votes.json`, `memberships_camera.json`,
`comuni.json`, `parties.json` and `sources.json` — is a
**generated artifact**, never hand-edited. They're produced by a `tools/` pipeline
that deliberately separates the one network-touching step from everything
else, so every other step is reproducible offline from a cache:

```
make fetch            # network required — SPARQL queries against dati.camera.it /
                       # dati.senato.it, writes only to tools/raw/ (gitignored)
make import            # offline — merges tools/raw/*.json into Data/*.json
                       # (representatives, votes, then memberships last —
                       # it reads the just-built representatives.json)
make boundaries        # offline — rebuilds districts.geojson (Camera) from the
                       # local ISTAT shapefile (tools/raw/collegi/, not fetched
                       # by `make fetch`; see docs/v2/03-boundaries-audit.md),
                       # with a per-feature vertex report against a 1500-vertex
                       # gate (see docs/v3/14-pipeline-hardening.md)
make boundaries-senato # offline — same pipeline, Senato layer →
                       # districts_senato.geojson (v3 Phase 16)
make boundaries-plurinominale-camera
make boundaries-plurinominale-senato
                       # offline — same pipeline, the two plurinominale layers →
                       # districts_plurinominali_{camera,senato}.geojson
                       # (v4 Phase 25)
make comuni            # offline — rebuilds comuni.json (7,904 comuni: the
                       # published collegio assignment per chamber, plus one
                       # interior point each) from the UT_Collegi2020 layer of
                       # that same local ISTAT package (v4 Phase 30 / 30B)
make manifest          # offline — regenerates Data/sources.json
make validate          # offline — structural + referential-integrity checks;
                       # runs last so it checks the final state of everything
                       # the steps above produce
make all               # offline — boundaries (×4) + comuni + import + manifest
                       # + validate, against whatever is already cached under
                       # tools/raw/ (never fetches — see below)
```

One-command refresh of the SPARQL-derived data (fetch, then rebuild
everything from it):

```bash
make refresh
```

`make refresh` (`fetch` + `all`) and `make fetch` are the only two targets
that touch the network — every other target, including `all`, is fully
offline against the `tools/raw/` cache left by a previous fetch.

Every SPARQL query is a pinned, versioned `.rq` file under `tools/queries/`
(never an inline string) — see `tools/sparql_client.py` for the shared
fetch client (retry/backoff, descriptive User-Agent, fetch-metadata
stamping) and `tools/import_*.py` for the merge logic.

**Honesty rules the pipeline follows throughout** (see `CLAUDE.md` and the
`docs/v2/*.md` phase reports for how each was actually verified, not just
asserted):
- Never present fictional data as real, and never fabricate a "real-looking"
  value where the source data doesn't have one (e.g. a missing `sourceUrl`
  is left `null`, never a constructed guess at a deep link).
- An unrecognized raw value from a source (a new vote-position vocabulary
  word, an unexpected enum) decodes to an explicit "unknown" case with a
  logged warning — never a crash, never a silent guess.
- Hard caps (e.g. the votes pipeline's `maxPositionRecords` bundle-size
  budget) skip whole records with a printed warning rather than truncating
  or silently degrading the ones that are kept.
- Every import step re-validates its own output (`make validate`) and
  cross-checks referential integrity (every `districtId`/`representativeId`
  reference must resolve) before anything is considered done.

See [`docs/DATA_SOURCES.md`](docs/DATA_SOURCES.md) for the exact source, license,
and transformation for each dataset, and `docs/v2/*.md` for the full
phase-by-phase investigation and verification behind each one.

## Project structure

```
Politici/
├── App/            — @main entry point (PoliticiApp) + root NavigationStack (ContentView)
├── Models/          — Codable domain types + schema-v2 provenance/tolerant-decoding infrastructure
├── Services/        — data loading, lookups, geocoding; injected via ServiceContainer
├── Utilities/        — pure helpers (PointInPolygon, DateFormatting, Initials, ColorHex) with no service state
├── Views/           — SwiftUI screens, one file per screen; typed navigation via AppRoute
└── Data/            — bundled JSON/GeoJSON (generated — see "Data pipeline" above)

tools/               — the offline-first-except-fetch data pipeline (see "Data pipeline")
├── queries/          — pinned .rq SPARQL query files
├── config/           — pipeline scope/budget config (e.g. votes_scope.json)
├── probes/           — committed one-off verification scripts; their output/ is gitignored
└── raw/              — gitignored fetch cache, never committed

PoliticiTests/        — unit tests: decoding, geometry, services, accessibility invariants
PoliticiUITests/      — XCUITest smoke flows + whole-screen performAccessibilityAudit() runs (v4 Phases 24/32A)
docs/plan/             — the V4 master plan: per-phase specs, shared baseline/rules, status table
docs/v2/               — phase-by-phase design notes and verification reports for the v2 rewrite
docs/v3/               — phase-by-phase reports for the v3 work (Senato, context, favorites, votes)
docs/v4/               — phase-by-phase reports for the v4 work (geography, votes, metric, comuni, staleness)
docs/releases/         — per-release notes (CHANGELOG.md stays canonical)
docs/history/          — frozen, audited v1–v2 implementation record (never edited)
docs/DATA_SOURCES.md   — canonical per-source license/attribution reference
```

## Building, running, and testing

```bash
# Build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Politici.xcodeproj -scheme Politici \
  -destination 'generic/platform=iOS Simulator' build

# Find an available simulator
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl list devices available | grep iPhone

# Run the full test suite against one of them
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Politici.xcodeproj -scheme Politici \
  -destination 'platform=iOS Simulator,name=<SimName>' test
```

Or, in Xcode: open `Politici.xcodeproj`, select the **Politici** scheme, pick
any iOS 17+ simulator, and Build & Run (`⌘R`). From Home: type an address or
tap a sample city to search, tap "Esplora la Mappa Interattiva" to browse
the map (switch chamber with the Camera/Senato picker), tap the "Collegi
uninominali" / "Rappresentanti" / "Preferiti" stat cards for the searchable
lists, or "Votazioni in Aula (campione)" for the imported roll-call votes.

## Known limitations

Disclosed deliberately, not silently — each of these is a scoping decision
made and documented during v2 development, not an oversight discovered
after the fact:

- **253 Camera deputies (245 plurinominale + 8 estero) have no collegio
  polygon of their own.** Only the 147 uninominale (majoritarian) winners
  have a precise collegio to point to. Since v3 Phase 18 the
  plurinominale deputies do appear on every Camera collegio page of their
  circoscrizione (with an explainer that they represent the whole
  circoscrizione, not that collegio) and their profiles show
  "Circoscrizione: {name}"; estero deputies remain list-only by design.
- **128 of 201 senators are listed but not mapped to geography.** Since v3
  Phases 16–17 the map renders both chambers' uninominale collegi (147
  Camera + 74 Senato) and 73 currently-serving senators are linked to the
  real Senato collegio that elected them, the same way deputies are; the
  senators elected via proportional lists (121), the two overseas
  constituencies, and the 5 life senators have no uninominale collegio to
  map — exactly like Camera's plurinominale/estero deputies. One Senato
  collegio (Lazio - U02) has no currently-serving senator in the source
  data at all and shows an honest empty state (see
  [`docs/v3/17-senato-mandates.md`](docs/v3/17-senato-mandates.md)).
- **Votes cover 30 curated Camera roll calls, not the full record — a
  stratified sample across 10 sittings and ~9 months (v4 Phase 27).**
  Secret-ballot votes are excluded by design — the source data only
  discloses a generic "voted" flag for them, never an actual position, so
  including them would misrepresent "unattributable by law" as "unknown by
  omission." The set is budget-constrained (a 2 MiB per-file gate; see
  [`docs/v2/04-votes-import.md`](docs/v2/04-votes-import.md)). A v3 "most
  recent N" expansion was probed and **measurably exited** (Camera votes
  come in same-day bursts, so no such scope spans more than one sitting —
  [`docs/v3/21-votes-expansion.md`](docs/v3/21-votes-expansion.md)); v4
  Phase 27 replaced it with a **stratified selection** — 3 votes from each
  of 10 date-spread sittings, preferring atto-bearing final votes — that
  spans sittings and months within the same gate (see
  [`docs/v4/27-votes-stratified.md`](docs/v4/27-votes-stratified.md)).
  Senato votes are out of scope entirely.
- **Exactly one vote-derived metric ships, strictly behind the gate.** The
  six-line gate any metric must pass is
  [`docs/v3/votes-methodology.md`](docs/v3/votes-methodology.md); Phase 27's
  stratified sample flipped the four sample-shape lines (≥30 events, ≥3
  sittings, ≥6 months, ≥2 distinct atti) and **Phase 28's
  group-membership-history import flipped the sixth** (group-at-vote-date, at
  100 % coverage of the shipped sample), so the gate passes **6 of 6**. On that
  basis **Phase 29 ships a per-deputy group-alignment figure** — the share of a
  deputy's expressed positions (favorevole/contrario/astenuto; absences
  excluded) matching their group-at-vote-date majority, over the shipped sample
  only. It is profile-only, **never on lists, never ranked, never colored as a
  judgment**, shown only above a minimum denominator (10) with that denominator
  visible, and it exists for Camera deputies only. See
  [`docs/v4/29-alignment-metric.md`](docs/v4/29-alignment-metric.md).
- **`attendanceRate` is not populated** for any real representative — no
  source in this pipeline publishes a documented, reproducible attendance
  methodology, and inventing one would be fabrication.
- **No representative photos.** Avatars are locally-generated initials
  circles, not real photos — the source data's `?foto` URLs are real but
  using them would mean fetching remote images at runtime, which conflicts
  with the local-first constraint (and image-rights clearance was never
  sought for a prototype).
- **Senato's 201-count follows a documented inclusion rule**: any senator
  with no `fineMandato` (mandate end date) bound, elected or life-appointed
  alike — see [`docs/v2/02-post-import-audit.md`](docs/v2/02-post-import-audit.md)
  for the verification against the raw SPARQL cache, including why life
  senators are included and one former President (deceased, mandate ended)
  is correctly excluded.
- **All data is a snapshot** as of each source's `retrievedAt` date in
  `Data/sources.json` / the in-app "Informazioni e fonti" screen — nothing
  refreshes automatically; re-running `make refresh` is required to update
  it, and the app has no way to know it's stale beyond the displayed date.
  Since v4 Phase 31 the Home footer states the last retrieval across all
  sources ("Ultimo aggiornamento dei dati: …"), so the vintage is visible
  without opening the sources screen. What that staleness actually costs is
  measured per class in
  [`docs/v4/31-live-refresh-adr.md`](docs/v4/31-live-refresh-adr.md): ~91 %
  of the bundle cannot change within the legislature, while the parts that
  can are the ones about named people — measured at 19 group switches
  (14 deputies) in a trailing 12 months, and ≥5 of 400 Camera seats changing
  occupant inside the 9-month vote window.
- **Accessibility has automated coverage, not a clean bill of health.**
  `PoliticiUITests` is no longer template boilerplate: since v4 Phase 24 it
  carries real smoke flows, and since v4 Phase 32A its
  `performAccessibilityAudit()` runs page through **whole screens** rather
  than each screen's first viewport. Every *structural* audit type —
  element detection, hit regions, element descriptions, traits,
  parent/child relationships — raises **zero** issues on all 16 audited
  screen states. Three types are **recorded rather than asserted**
  (`.contrast`, `.dynamicType`, `.textClipped`): 200 findings, every one of
  them triaged in [`docs/v4/a11y-checklist.md`](docs/v4/a11y-checklist.md),
  and most of them awaiting a measurement no headless run can make. MapKit
  polygon overlays remain undiscoverable by VoiceOver — a platform limit,
  mitigated by `CollegiListView` rather than solved.
- **The UI-test target runs on shared simulator-clone infrastructure that
  intermittently fails to launch the app** — observed in v3 Phases 17/18,
  in v4 Phase 29, and twice more during v4 Phase 32A (where the
  infrastructure retried and the suite still ended green). A single failure
  there is diagnosed before it is believed.
- **`IPHONEOS_DEPLOYMENT_TARGET` is 17.0** — the app's real technical
  floor (no API newer than iOS 17 is used). It was audited and lowered
  from 26.5, the Xcode template default it had inherited since creation,
  in v3 Phases 13/13B (`docs/v3/13-baseline-audit.md`,
  `docs/v3/13b-deployment-target.md`).

## Roadmap (post-v4)

What v3 and v4 actually did to the old roadmap, stated plainly, plus what
remains — not promised on any timeline:

**Shipped in v3** (see `docs/v3/*.md` and `CHANGELOG.md`):
- Senato collegio boundaries + senator linkage (Phases 16–17).
- The plurinominale representation layer, as per-circoscrizione grouping
  on Camera collegio pages (Phase 18).
- Local favorites (Phase 19) — via `UserDefaults`, which settled the old
  "SwiftData persistence" question for the current scale: nothing yet
  needs more than that.
- Per-event vote browsing on a source-backed event identity (Phase 20).

**Attempted in v3, measurably exited**:
- Expanded votes coverage — the Phase 21 scope probe showed no
  "most recent N" scope that fits the 2 MiB gate can span more than one
  sitting day; the recorded path forward is a *stratified* selection
  design (per-sitting caps, or hand-curated atto-bearing votes via the
  existing `"explicit"` scope mode), which needs its own probe
  ([`docs/v3/21-votes-expansion.md`](docs/v3/21-votes-expansion.md)).

**Shipped in v4** (see `docs/v4/*.md`, and `CHANGELOG.md`'s
`v4.0-prototype` entry for the phase-by-phase record):
- Real UI-automation coverage and automated accessibility audits, retiring
  the "template boilerplate" limitation (Phase 24,
  [`docs/v4/24-ui-tests.md`](docs/v4/24-ui-tests.md)), rebuilt in Phase 32A
  to audit whole screens rather than first viewports
  ([`docs/v4/a11y-checklist.md`](docs/v4/a11y-checklist.md)).
- The plurinominale collegi layer — 49 Camera + 26 Senato boundaries, a map
  and list filter, per-collegio pages, and 245/245 deputy linkage (Phase 25,
  [`docs/v4/25-plurinominale-geography.md`](docs/v4/25-plurinominale-geography.md)).
- Senato `regione` context and the deferred senator-`electionType` decision,
  taken with explicit user approval (Phase 26,
  [`docs/v4/26-senato-regione.md`](docs/v4/26-senato-regione.md)).
- The stratified votes-scope redesign the Phase 21 exit called for — 30
  votes across 10 sittings and ~9 months via `tools/select_votes_scope.py`
  writing `votes_scope.json`'s `explicit` mode — plus the lazy, off-main
  vote decoding its file growth (711 KB → ~1.77 MB) triggered (Phase 27,
  [`docs/v4/27-votes-stratified.md`](docs/v4/27-votes-stratified.md)).
- The Camera group-membership-history import (Phase 28,
  [`docs/v4/28-membership-history.md`](docs/v4/28-membership-history.md)) —
  per-deputy `ocd:aderisce` intervals in `Data/memberships_camera.json`
  (468 intervals, half-open `[start, end)`) with a
  `MembershipService.membershipAt(representativeId:date:)` lookup, flipping
  the last methodology-gate line. **Infrastructure only — no metric UI.**
- The per-deputy **group-alignment metric** (Phase 29,
  [`docs/v4/29-alignment-metric.md`](docs/v4/29-alignment-metric.md)) — a pure
  `GroupAlignment.alignment(…)` (over an internal `tally(…)`) computed from
  `(events, positions, memberships)`, shown on
  the Camera deputy profile only, above a minimum denominator of 10, with the
  denominator visible, never listed/ranked/colored. Ships behind the re-measured
  6/6 gate and explicit user sign-off on the tie rule and threshold (Q7).
- The Home **data-vintage line** and the ADR that decided live refresh
  (Phase 31, [`docs/v4/31-live-refresh-adr.md`](docs/v4/31-live-refresh-adr.md)).
  Also fixed there: every date the app rendered was one calendar day early
  on devices west of Rome, because the display formatters ran on the device
  timezone while every parser produces midnight Europe/Rome.

- The Home **data-vintage line** and the ADR that decided live refresh
  (Phase 31), plus the timezone fix below.
- Documentation, the v4 accessibility checklist and release preparation
  (Phase 32A, [`docs/v4/32a-release.md`](docs/v4/32a-release.md)) — which
  also found and fixed a real defect in Phase 30B's multi-collegio result
  screen: `AddressSearchView` did not scroll, so Roma's three Senato
  collegi were listed in code and unreachable on screen.

**Closed during v4** (were open questions at the end of v3):
- ~~Populating senators' `electionType` from `osr:tipoElezione`.~~ **Done**
  in v4 Phase 26, with explicit user approval on the vocabulary mapping:
  121 plurinominale + 73 uninominale + 2 estero; the 5 life senators keep
  `null` because the source gives them no election type
  ([`docs/v4/26-senato-regione.md`](docs/v4/26-senato-regione.md) §3).
- ~~Offline geocoding beyond the five-city fallback (bundled
  comuni-centroid table).~~ **Done** in v4 Phase 30 — see
  [`docs/v4/30-comuni-geocoding.md`](docs/v4/30-comuni-geocoding.md) — and
  inverted in Phase 30B, which answers a comune name from the assignment
  ISTAT publishes rather than from geometry.
- ~~Possible live data refresh — still deferred pending the "is that
  compatible with local-first at all" decision.~~ **Decided** in v4
  Phase 31: **stays deferred**, now on measured grounds rather than a
  pending question — ~91 % of the bundle cannot change within the
  legislature, refreshing the comuni table would break its legally-pinned
  collegio join, and the ~9 % that does age already has a human-reviewed
  refresh path in `make refresh`. The trigger conditions that would
  re-open it are pinned in
  [`docs/v4/31-live-refresh-adr.md`](docs/v4/31-live-refresh-adr.md) §5.

**Open (post-v4 candidates)** — each is a recorded decision, not an
oversight; the full list with per-item reasoning is the "Explicitly
deferred" table in
[`docs/plan/00-baseline-and-rules.md`](docs/plan/00-baseline-and-rules.md):
- **Senato votes** — an unexplored source surface, deliberately kept out of
  Phase 27 rather than doubling that phase's risk.
- **A Senato group-membership import** — the Camera has one (Phase 28); the
  Senato's group-switching exposure is therefore *unmeasured*, which
  Phase 31 §2.3 records as a fact rather than closing.
- **Measured on-device contrast and Dynamic Type judgment** for the 200
  recorded accessibility findings — the residue Phase 32A could not decide
  headlessly.
- **Push notifications for new votes** — still deferred (needs a backend
  that doesn't exist and isn't planned); listed so it isn't quietly
  forgotten.
- **Representative photos**, **SwiftData migration**, **`attendanceRate`**,
  and **MapKit polygon VoiceOver discoverability** — all standing
  deferrals, the last two permanent (no source methodology; a platform
  limitation).

## License & attribution

App code license: see repository root (unspecified/proprietary unless a
`LICENSE` file says otherwise). Data is redistributed under each source's
own license — CC BY 4.0 (Camera, ISTAT) and CC BY 3.0 (Senato) — see
[`docs/DATA_SOURCES.md`](docs/DATA_SOURCES.md) for exact terms, or the
in-app "Informazioni e fonti" screen for the same information live from
the shipping data.
