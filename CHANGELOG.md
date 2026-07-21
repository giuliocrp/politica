# Changelog

This project doesn't follow strict [SemVer](https://semver.org/) yet (no
public releases), but entries are grouped by tagged/named milestone, newest
first, in the spirit of [Keep a Changelog](https://keepachangelog.com/).
Each entry corresponds to one phase's commit on its branch (`v2`/`v3`) —
see `docs/v2/*.md` / `docs/v3/*.md` for the full investigation and
verification behind each.

## v3.0-prototype (2026-07-21)

Extended the v2 prototype to full dual-chamber geography, senator
mandates and linkage, electoral context for proportional-list deputies,
local favorites, and per-event vote browsing — every expansion gated on
verified source evidence, with two gates deliberately concluding in
documented non-shipping outcomes (a NO-GO later reversed by a probe, and
a measured early exit). See `README.md` for the shipped state and
`docs/v3/*.md` for the per-phase reports.

- **Phase 13 — Baseline audit** (`1d2eba5`): `v3` branch from audited
  `main`; established the canonical dual test-baseline definition (94
  declared / 97 runtime, the ×4 `testLaunch` cause named); deployment-
  target audit (real floor iOS 17.0); fixed a dead map legend and a stale
  `districtId` comment; corrected a one-year `retrievedAt` typo (C5);
  archived v2 backfills under `docs/history/backfills/`.
- **Phase 13B — Deployment target 17.0** (`492152f`): user-approved drop
  from the inherited 26.5 template default to the audited 17.0 floor,
  applied across all targets with an exact-baseline test match.
- **Phase 14 — Pipeline hardening** (`b371465`): made `make all` fully
  offline with `validate` last (fixing a defect where validation ran
  before boundaries/manifest), added `make refresh`; 1500-vertex
  per-feature gate (measured max 695); probes convention
  (`tools/probes/`, output gitignored); committed `tools/SOURCES.md`
  provenance mirror; found and fixed fetch-metadata stamping that
  silently advanced `retrievedAt` on offline runs.
- **Phase 15 — Senato source exploration** (`a1cac30`): read-only
  GO/NO-GO evidence — **GO(MAP)** (74 ISTAT Senato collegi verified, id
  collisions found, `regione`-not-`circoscrizione` naming decided) and
  **NO-GO(LINK)** on the then-existing cache (no joinable collegio key);
  MandateType designed from the verbatim source vocabulary (196 elettivo
  + 5 a-vita serving; Napolitano correctly excluded).
- **Phase 15b — Linkage predicate probe** (`3828ebd`): user-approved live
  introspection reversed the NO-GO: found `osr:tipoElezione`/
  `osr:regioneElezione`/`osr:collegioElezione` (never in the cached
  query), verified 73 linkable senators with 73/73 effective join match
  (one disclosed Valle d'Aosta naming alias), set
  `MIN_LINKED_SENATO = 66`; documented the endpoint's aggregate
  rejection and ~10k-row cap.
- **Phase 16 — Senato boundaries + chamber-aware map** (`5f6650a`):
  shipped `districts_senato.geojson` (74 collegi, S-prefixed ids, 221
  unique across chambers), chamber-aware `DistrictService`,
  `ChamberPicker` on map and collegi list, dual-chamber address results;
  Camera boundaries byte-identical; eager decode kept by explicit user
  decision (13.1 ms measured).
- **Phase 17 — Senator mandates + Senato linkage** (`c491548`): every
  senator carries the verbatim mandate category (gender-neutral a-vita
  badge on exactly 5 profiles); user-approved Senato-only refetch under
  the full protocol (zero drift vs 15b); **73/74** collegi linked to
  their serving senator — the uncovered `S120002` (Lazio - U02) has no
  claimant in the source at all; retired the "no senator linked" copy.
- **Phase 18 — Plurinominale/estero context** (`0d75506`): GO-CIRC gate
  passed on all five conditions (55 coverage literals enumerated, 28/28
  circoscrizioni matched, 147/147 cross-check); every deputy carries a
  canonical `circoscrizione` ("Estero" for the 8 overseas); Camera
  collegio pages gained the per-circoscrizione plurinominale section;
  profiles the "Circoscrizione:" line.
- **Phase 19 — Preferiti** (`873fc5f`): local favorites —
  `UserDefaultsFavoritesStore` (`favorites.v1` payload, corrupt-payload
  self-heal, dedup) as the seventh service, `@Observable` by recorded
  decision; profile star toggle, Preferiti screen, dynamic Home count.
  App-only; zero pipeline/data changes.
- **Phase 20 — Vote browsing + methodology gate** (`89e0b16`):
  GO-EVENT-ID (the source's own votazione URI slug, bijective with the
  12 shipped events); `votes.json` normalized to
  `{"events":[...],"positions":[...]}` by measurement (flat-plus-field
  would crowd the 2 MiB gate at 97.6%; normalized is 33.9%, content
  equivalence proven); Votazioni per-event screen with tallies and
  source links; VoteHistory outcome chips + title search; wrote
  `docs/v3/votes-methodology.md` — the six-line gate any future metric
  must pass (current sample: 1 of 6) — **no metric ships**.
- **Phase 21 — Votes expansion probe: measured early exit** (`9c7a436`):
  the four-scope probe (20/30/40/50 recent events) found all 50 most
  recent non-secret votes come from one sitting day; 40/50 breach the
  2 MiB gate, 30 adds volume but zero diversity, and even 3 sitting days
  would need 155% of the gate — **no expansion; data untouched**; the
  stratified-selection redesign is the recorded V4 path.
- **This phase — 22A: documentation, accessibility, release prep**:
  v3 accessibility checklist (`docs/v3/a11y-checklist.md`), README/
  `CLAUDE.md`/`docs/DATA_SOURCES.md` refreshed to the shipped state,
  this changelog entry, `docs/releases/v3.0-prototype.md`, final
  verification (`docs/v3/22-release.md`). Tagging and pushing are
  deferred to Phase 22B pending the release actions below.

### Release actions (status as of Phase 22B, 2026-07-21)

- [x] **Tag `v3.0-prototype`**: approved ("Proceed with Phase 22B." in
      response to the pending-decisions block — quoted in
      `docs/v3/22-release.md`) and created **locally** by Phase 22B at
      the decisions commit. Not pushed; push commands printed in the
      22B record, not executed.
- [ ] **Repository visibility / GitHub Release**: *pending user
      decision* — release URL placeholder: `<github-release-url>`.
- [ ] **Retrospective `v1.0.0` tag** at the v1 close: **not created** —
      requires a separate explicit instruction that was not given;
      deliberately not re-asked.
- [ ] **V3 commissioning brief archival** (open since Phase 13): still
      pending — the brief was never provided; archive under
      `docs/history/` if/when it surfaces.

## v2.0-prototype (2026-07-18)

Rewrote every data layer from fictional sample content to real,
officially-sourced Italian parliamentary data, while keeping the app
itself local-first, honest about its own limitations, and fully
accessible. See `README.md` for the current feature set and known
limitations, and `docs/DATA_SOURCES.md` for exact source/license/retrieval
detail.

- **Phase 0 — Audit** (`b0b6c77`): baseline repo audit before any v2
  change; established `CLAUDE.md`'s standing constraints (never rename
  project/target/scheme/bundle id, Italian-only UI, local-first,
  never fabricate).
- **Phase 1 — Test bootstrap** (`bdff254`): replaced the unmodified Xcode
  test-target boilerplate with real coverage — geometry, decoding, and
  service-lookup tests, the foundation every later phase built on.
- **Phase 2 — Schema v2** (`d9a922f`): added `provenance` tracking
  (`.official`/`.sample`) to every model, tolerant enum decoding
  (`TolerantStringEnum` — an unrecognized raw value becomes an explicit
  "unknown" case instead of throwing), and the `Data/sources.json`
  manifest infrastructure.
- **Phase 3 — Attribution screen** (`e6e5ffe`): added "Informazioni e
  fonti" (`FontiEDatiView`), rendering the sources manifest live with an
  unofficial-status disclaimer — the app's legal/honesty anchor, wired in
  before any real data existed to display.
- **Phase 4 — Address autocomplete** (`b92ffd8`): `MKLocalSearchCompleter`
  autocomplete behind a `GeocodingProviding` seam, layered over the
  existing `CLGeocoder` + 5-city-fallback flow.
- **Phase 5 — Real representative data import** (`f01dd15`, `f6867eb`):
  built the `tools/` SPARQL fetch/import pipeline (network-touching fetch
  step strictly separated from offline import) and replaced
  `representatives.json`'s 14 fictional records with **601 real records**
  (400 Camera deputies + 201 Senato senators, XIX Legislature) from
  dati.camera.it/dati.senato.it. `districts.geojson` and `votes.json`
  still fictional at this point — the original fixtures preserved at
  `*.sample.*`.
- **Phase 6 — Post-import reconciliation** (`8b16be1`): fixed the gaps the
  import left behind — shipped `votes.json` as a valid empty schema-v2
  collection (was orphaned, referencing stale fictional ids), added
  `Data/parties.json` + `PartyStyleService` so real party sigla render
  correctly instead of falling through to a gray default, added the
  boundaries-are-still-demonstrative disclosure, hardened fetch-script
  retry/backoff, and gave `stableSourceId` a real, non-fabricated meaning
  (the bare numeric id from each source URI).
- **Phase 7 — ISTAT electoral-college boundaries** (`9841fea`): replaced
  the 5 fictional rectangular districts with the **147 real Camera
  collegi uninominali** (ISTAT, D.Lgs. 177/2020), and upgraded the
  geometry engine to native `MKPolygon`/`MKMultiPolygon` (56 of 147 are
  genuine multi-part geometries) with a bounding-box prefilter before
  exact point-in-polygon testing. Found and fixed a real `MKGeoJSONDecoder`
  behavior gap (`MultiPolygon` geometry decodes to a single `MKMultiPolygon`,
  not flattened `MKPolygon` entries) that silently dropped every
  multi-part district until diagnosed with standalone probes. Original 5
  fictional districts preserved at `districts.sample.geojson`.
- **Phase 8 — Deputy-to-collegio linkage** (`2820bec`): fixed the
  boundary metadata (`region` — actually a sub-collegio suffix, not a
  region — replaced with truthful `circoscrizione`/`subCode` fields), then
  linked **147/147** current Camera uninominale deputies to their real
  ISTAT collegio via a structural join on the SPARQL graph's
  `dcterms:spatial` (found after discovering the existing `?collegio`
  field was the wrong granularity — plurinominale, not uninominale).
  Verified zero ambiguity, 2 by-election holders, 0 vacancies.
- **Phase 9 — Curated Camera votes import** (`6625944`): replaced the
  empty `votes.json` with **12 curated real Camera roll-call votes**
  (4,788 per-deputy positions) — scoped to non-secret "electronic" votes
  (secret ballots excluded: the source only discloses a generic "voted"
  flag for those, never an actual position), budget-capped from a nominal
  25-vote target to fit a ~2MB bundle size.
- **Phase 10 — UI completion for real data** (`8a1aa90`): audited and
  confirmed party styling (colors/short names) was already complete and
  WCAG-compliant from Phase 6; built the searchable, party-filterable
  `RepresentativeListView` (previously no way to browse all 601 — only a
  4-item Home preview existed), added local-first initials avatars
  (replacing generic SF Symbol placeholders), and added the "Come
  funziona l'elezione" explainer.
- **Phase 11 — Accessibility pass** (`a084f3d`): found `MapView` had zero
  VoiceOver support (polygon tap-selection is fundamentally undiscoverable
  by VoiceOver) and built `CollegiListView` as the accessible alternative
  path; made vote-outcome badges non-color-only (SF Symbol + text +
  distinct Italian VoiceOver label per case); combined/labeled/hinted
  interactive elements across every screen; fixed the one
  Dynamic-Type-fighting `minimumScaleFactor` usage; brought five
  under-44pt custom controls up to a real hit-target size.
- **This phase — Documentation & tag**: rewrote `README.md` to describe
  the actual shipped v2 state (no more "5 sample districts" / "prototype
  v2 roadmap" language describing what's now already built); added
  `docs/DATA_SOURCES.md` as the canonical, cross-checked source reference;
  added this changelog; tagged `v2.0-prototype`.

## v1.0.0 — original prototype (2026-07-16 – 2026-07-17)

The original prototype: fictional sample data demonstrating the app's
architecture and UX before any real-data work began.

- `3ab4e58` — Initial commit.
- `6d3b866` — Completed prototype v1: SwiftUI + MapKit app with 5 fictional
  rectangular sample districts (Roma Centro, Milano Centro, Napoli Nord,
  Torino Sud, Firenze Urban), 14 fictional representatives, 37 fictional
  votes; `CLGeocoder` + hardcoded 5-city fallback geocoding;
  MVVM/service-pattern architecture with `ServiceContainer` dependency
  injection; app icon and display name ("Politica") finalized.
- `5d8e36a` — Added the Xcode `.gitignore` and cleaned up previously
  tracked build artifacts.
