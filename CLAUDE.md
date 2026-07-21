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

## Build Command

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Politici.xcodeproj -scheme Politici -destination 'generic/platform=iOS Simulator' build
```

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
