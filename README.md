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
| 601 representatives (400 deputies + 201 senators, XIX Legislature) | Real — dati.camera.it / dati.senato.it |
| 147/147 uninominale-collegio → current-deputy linkage | Real, derived (see [`docs/v2/03-linkage-report.md`](docs/v2/03-linkage-report.md)) |
| 12 curated Camera roll-call votes, 4,788 per-deputy positions | Real — dati.camera.it |
| The original 5 fictional sample districts / 14 sample representatives / 37 sample votes | Fictional, preserved at `*.sample.*` for tests only — never shown in the app UI |

## Features

- **Interactive map** of all 147 real Camera dei Deputati collegi
  uninominali, rendered as native `MKPolygon`/`MKMultiPolygon` overlays
  (56 of the 147 are genuine multi-part geometries — mainland collegi that
  include small offshore islands) — tap a collegio to see its detail.
- **601 real representatives** — 400 Camera deputies + 201 Senato
  senators, XIX Legislature, each with party, parliamentary group,
  committee memberships, and (for deputies) how they were elected.
- **147/147 collegio-uninominale ↔ current-deputy linkage** — every real
  ISTAT collegio shows its actual current deputy, resolved from the
  official Camera SPARQL graph (structural join on circoscrizione + collegio
  sub-code, verified against by-elections and vacancies — see the linkage
  report).
- **12 curated real Camera votes** with 4,788 individual per-deputy
  positions (favorevole/contrario/astenuto/assente), each traceable to its
  official "scheda votazione" source page.
- **Address search with autocomplete** (`MKLocalSearchCompleter`) resolving
  any Italian address to its real collegio via point-in-polygon geometry,
  with an offline five-city fallback table when network geocoding isn't
  available.
- **Searchable representative list** (`RepresentativeListView`) — all 601
  representatives, filterable by party (12 deduplicated party chips merging
  Camera-sigla/Senato-full-name spelling variants of the same party).
- **`CollegiListView`** — a fully searchable, VoiceOver-navigable list of
  all 147 collegi, serving as the accessible alternative to tapping
  polygons on the map (which VoiceOver cannot discover or select).
- **"Informazioni e fonti"** attribution screen, rendered live from
  `Data/sources.json` — every source's name, license, and retrieval date,
  with a link to the original.
- **"Come funziona l'elezione"** explainer on Home, stating plainly which
  deputies are mapped to geography (uninominale) and which aren't
  (plurinominale/estero/Senato).
- **Accessibility**: non-color-only vote-outcome badges (icon + text +
  distinct VoiceOver label for every case), VoiceOver labels/hints across
  every interactive flow, Dynamic Type support (no truncating
  `minimumScaleFactor` on real content), and ≥44×44pt hit targets — see
  [`docs/v2/a11y-checklist.md`](docs/v2/a11y-checklist.md) for the full
  audit and its disclosed limitations.

## Architecture

- **UI:** SwiftUI, MapKit for SwiftUI (`Map`, `MapPolygon`, `MapReader`,
  `MKGeoJSONDecoder`).
- **Pattern:** MVVM/service pattern. A single `ServiceContainer`
  (`DistrictService`, `RepresentativeService`, `VoteService`,
  `GeocodingService`, `ManifestService`, `PartyStyleService`) is built once
  at launch and injected into the view hierarchy via
  `.environment(\.services, services)`; views read it back with
  `@Environment(\.services) private var services` rather than reaching for
  a `.shared` singleton directly.
- **Geometry engine:** districts decode via `MKGeoJSONDecoder` into native
  `MKPolygon`/`MKMultiPolygon` (with interior-ring holes handled
  natively). Point-in-collegio resolution first narrows to bounding-box
  candidates (`District.boundingMapRect`), then runs exact even-odd
  ray-casting only on those candidates — measured at ~0.07s for 1,000
  random Italian coordinates against all 147 real collegi (see
  `PoliticiTests/DistrictBoundariesTests.swift`).
- **Schema v2**: every model carries a `provenance` field
  (`.official`/`.sample`, defaulting to `.sample` when absent so old
  fixtures keep decoding), and enums that model external vocabulary
  (`VoteChoice`, `VoteResult`, `CollegioType`, `ElectionType`) decode
  *tolerantly* — an unrecognized raw value becomes an explicit
  `.sconosciuto` case rather than throwing and blanking the whole file
  (`TolerantStringEnum`, `Politici/Models/TolerantDecoding.swift`).
- **Local-first at runtime, no exceptions**: the app itself makes no
  network calls — no backend, no analytics, no remote image fetching
  (representative "photos" are locally-generated initials avatars, never a
  downloaded image). All data is bundled JSON/GeoJSON, read once at launch.
  Network access is used **only** by the developer-side `tools/` data
  pipeline (see below), never by the shipping app.
- **Language:** every user-facing string is Italian.

## Data pipeline

`Data/districts.geojson`, `Data/representatives.json`, and `Data/votes.json`
are **generated artifacts** — never hand-edited. They're produced by a
`tools/` pipeline that deliberately separates the one network-touching step
from everything else, so every other step is reproducible offline from a
cache:

```
make fetch       # network required — SPARQL queries against dati.camera.it /
                  # dati.senato.it, writes only to tools/raw/ (gitignored)
make import       # offline — merges tools/raw/*.json into Data/*.json
make boundaries   # offline — rebuilds districts.geojson from the local
                  # ISTAT shapefile (tools/raw/collegi/, not fetched by
                  # `make fetch`; see docs/v2/03-boundaries-audit.md), and
                  # prints a per-feature vertex report against a 1500-vertex
                  # gate (see docs/v3/14-pipeline-hardening.md)
make manifest     # offline — regenerates Data/sources.json
make validate     # offline — structural + referential-integrity checks;
                  # runs last so it checks the final state of everything
                  # the steps above produce
make all          # offline — import + boundaries + manifest + validate,
                  # against whatever is already cached under tools/raw/
                  # (never fetches — see `make refresh` below)
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
└── raw/              — gitignored fetch cache, never committed

PoliticiTests/        — unit tests: decoding, geometry, services, accessibility invariants
docs/v2/               — phase-by-phase design notes and verification reports for the v2 rewrite
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
the map, or tap either stat card ("Collegi campione" / "Rappresentanti") to
browse the full searchable lists.

## Known limitations

Disclosed deliberately, not silently — each of these is a scoping decision
made and documented during v2 development, not an oversight discovered
after the fact:

- **~253 Camera deputies (245 plurinominale + 8 estero) are listed but not
  mapped to geography.** Only the 147 uninominale (majoritarian) winners
  have a real collegio to point to; proportional-list and overseas-district
  deputies are visible in the representative list/profile but never plotted
  on the map, exactly as the "Come funziona l'elezione" explainer states.
- **Senato collegi are not rendered at all** — no Senato boundary data has
  been imported in v2 (Camera-only per the boundaries phase's explicit
  scope). All 201 senators are listed and searchable but never mapped.
- **Votes cover 12 curated Camera roll calls, not the full record.**
  Secret-ballot votes are excluded by design — the source data only
  discloses a generic "voted" flag for them, never an actual position, so
  including them would misrepresent "unattributable by law" as "unknown by
  omission." The set is also budget-constrained: the nominal scope target
  is the 25 most recent qualifying votes, but a ~2MB bundle-size budget
  capped the actual import at 12 (see
  [`docs/v2/04-votes-import.md`](docs/v2/04-votes-import.md) for the exact
  math). Senato votes are out of scope entirely.
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
- **`PoliticiUITests` is still unmodified Xcode template boilerplate** — no
  real UI-automation test coverage exists; all verification during v2 was
  either `PoliticiTests` unit coverage or manual simulator/screenshot
  checks (documented per-phase in `docs/v2/*.md`).
- **`IPHONEOS_DEPLOYMENT_TARGET` is 17.0** — the app's real technical
  floor (no API newer than iOS 17 is used). It was audited and lowered
  from 26.5, the Xcode template default it had inherited since creation,
  in v3 Phases 13/13B (`docs/v3/13-baseline-audit.md`,
  `docs/v3/13b-deployment-target.md`).

## v3 roadmap

Not started, not promised on any timeline — captured here so future work
has a documented starting point rather than a blank slate:

- **Senato collegio boundaries** — extend the boundaries pipeline to the
  Senato uninominali layer (ISTAT publishes it alongside Camera's) and
  link current senators the same way Camera deputies are linked now.
- **A plurinominale representation layer** — some UI treatment for the
  ~253 currently-unmapped deputies beyond "visible in the list," e.g.
  grouping by circoscrizione even without a precise polygon.
- **Expanded votes coverage** — either a materially larger curated set (if
  bundle size allows a redesign, e.g. per-collegio or per-representative
  lazy loading instead of one bundled file) or a documented on-demand fetch
  path that stays consistent with the local-first *runtime* constraint.
- **Offline geocoding beyond the five-city fallback** — a bundled
  comuni-centroid table so every Italian comune resolves to *a* coordinate
  without depending on live `CLGeocoder` network access.
- **Possible live data refresh** — explicitly deferred pending a decision
  on whether that's compatible with "local-first" at all, or whether it
  would need to become an explicit, user-initiated, clearly-labeled
  exception.
- **Push notifications for new votes** — explicitly deferred: this needs a
  backend (something to push *from*), which doesn't exist and isn't
  planned; listed here only so it isn't quietly forgotten as a future
  option, not as a near-term item.
- **SwiftData (or similar) persistence** — only if/when the app grows
  actual user state (follows, bookmarks, preferences) to persist; nothing
  in the current app needs it, so it hasn't been added speculatively.

## License & attribution

App code license: see repository root (unspecified/proprietary unless a
`LICENSE` file says otherwise). Data is redistributed under each source's
own license — CC BY 4.0 (Camera, ISTAT) and CC BY 3.0 (Senato) — see
[`docs/DATA_SOURCES.md`](docs/DATA_SOURCES.md) for exact terms, or the
in-app "Informazioni e fonti" screen for the same information live from
the shipping data.
