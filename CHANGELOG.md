# Changelog

This project doesn't follow strict [SemVer](https://semver.org/) yet (no
public releases), but entries are grouped by tagged/named milestone, newest
first, in the spirit of [Keep a Changelog](https://keepachangelog.com/).
Each entry corresponds to one phase's commit on its branch (`v2`/`v3`/`v4`)
— see `docs/v2/*.md` / `docs/v3/*.md` / `docs/v4/*.md` for the full
investigation and verification behind each.

## v4.0-prototype (2026-07-28)

Took the v3 prototype from "the geography and the people are real" to "the
*context* is real too": both chambers' proportional-list geography, the
regione/circoscrizione context that explains who represents whom, a
stratified vote sample large enough to pass a methodology gate written a
release earlier, the group-membership history that gate demanded, the one
metric it then permitted, offline comune-level resolution answered from the
publisher's own assignment, and an explicit decision about staleness. Two
phases produced deliberate non-shipping outcomes and one open question is
carried forward unresolved rather than closed by assumption. See
`README.md` for the shipped state and `docs/v4/*.md` for the per-phase
reports; the plan those phases executed is `docs/plan/`.

- **V4 master plan** (`3907689`): per-phase specs, shared
  baseline/open-questions/rules (`docs/plan/00-baseline-and-rules.md`), and
  the canonical per-session workflow — committed before any phase ran, so
  every later gate decision was measured against a written spec rather than
  a remembered one.
- **Phase 23 — Baseline audit & hygiene** (`4f251a3`): re-verified the
  volatile baseline facts (branch, 136/139 tests, bundle bytes) and dumped
  all five raw ISTAT layers, answering **Q2** — `UT_Collegi2020` is the
  comune-level base table (8,213 rows / 7,904 comuni) every collegi layer
  aggregates from, which is what made Phases 30/30B possible without a new
  download. Four hygiene findings recorded with their disposition; **none
  met the "trivially safe" bar, so nothing was fixed**.
- **Phase 24 — Real UI tests + accessibility audits** (`4bcd006`): replaced
  the Xcode template `PoliticiUITests` with 7 deterministic smoke flows and
  4 `performAccessibilityAudit()` runs over 8 screens, and **redefined the
  test-count baseline** (136 declared / 139 runtime → **144/144**, the ×4
  `testLaunch` multiplier gone). Every structural audit type raised zero
  issues; three types were recorded rather than asserted and handed to
  Phase 32A.
- **Phase 25 — Plurinominale geography** (`15f3f95`) — **GO-PLURI**:
  resolved **Q1** from feature attributes (each layer's null-attribute row
  is a residual placeholder for the un-split territory, so 49 Camera / 26
  Senato are real), shipped both plurinominale boundary layers with
  `CP`/`SP`-prefixed ids, the map/list collegio-type filter, per-collegio
  pages, and 245/245 plurinominale-deputy linkage.
- *Interstitial fixes* (`7af1dce`, `a7d4c71`, `b6f70b2`): two stale
  generated-note corrections in `tools/make_manifest.py`, then a plan-baseline
  sync recording the side-task rules and `docs/v4/25a-doc-sync.md` — the
  first side-task record, notable because the spawned session had been
  forked from a **stale base** and its diff was discarded and re-applied by
  hand (baseline rule 8).
- **Phase 26 — Senato regione + `electionType`** (`02750b3`, follow-ups
  `d0b9910`) — **GO-REG**: every elective senator gained a `regione` from
  `osr:regioneElezione`, Senato collegio pages a "Senatori proporzionali
  della regione {name}" section, senator profiles a "Regione:" line. The
  senator-`electionType` decision deferred since v3 was **taken here with
  explicit user approval** — 121 plurinominale + 73 uninominale + 2 estero,
  the 5 a-vita left `null`. No network act.
- **Phase 27 — Stratified votes + lazy loading** (`ff1b71b`, follow-ups
  `aa78bfe`) — **user-gated network**: replaced the "most recent N" scope
  the Phase 21 exit had killed with a coverage-driven stratified pick — 30
  votes, 3 from each of 10 sittings across ~9 months, 11,899 positions —
  and answered **Q3** (dati.camera.it `LIMIT/OFFSET` paging over a total
  `ORDER BY` is stable: zero URI overlap, monotonic dates). `votes.json`
  grew 711 KB → 1.77 MB, which is why vote decoding moved off the main
  thread behind a loading state.
- **Phase 28 — Group-membership history** (`fe0038a`) — **GO-STORICO,
  user-gated network**: answered **Q4** by discovering the `ocd:startDate`
  predicate and importing 468 half-open `[start, end)` intervals for the
  400 serving deputies, at 100 % coverage of the shipped votes. That
  flipped the last of `docs/v3/votes-methodology.md`'s six lines.
  **Infrastructure only — no metric UI.**
- **Phase 29 — Group-alignment metric** (`744d045`, follow-ups `17cc2a7`):
  the gate now reading **6 of 6**, one vote-derived metric ships — the share
  of a deputy's expressed positions matching their group's majority *at each
  vote's date*. **Q7** closed by explicit user sign-off (2026-07-23): a
  group-majority tie excludes the vote from the denominator, the minimum
  denominator is 10, and below it the metric renders **nothing** rather than
  0 %. Profile-only, Camera-only, never listed, ranked or coloured;
  `Alignment.insufficientData` carries no number, so the misrender is
  non-representable.
- **Phase 30 — Offline comuni geocoding** (`0e76a75`, follow-ups `5186a51`)
  — **GO-COMUNI, user-gated acquisition**: answered **Q5** with the finding
  that the product was **already local** — the `UT_Collegi2020` layer of the
  ISTAT package this repo has carried since v2 — so the acquisition path was
  "none required", the licence was the CC BY 4.0 already recorded, **no
  download and no network act occurred**, and the comuni vintage matches the
  shipped collegi *by construction*. 7,904 comuni with an interior point
  each; homonyms disambiguated by province.
- **Phase 30B — Comuni resolve via the published assignment** (`2768d8a`,
  closeout `b5b73a7`) — **GO-ASSIGN**: inverted Phase 30's answer for
  **name** queries — the app now cites ISTAT's own `CU20_COD`/`SU20_COD`
  rather than a value derived from simplified geometry, and geometry is kept
  for the **coordinate** path alone. That made the honest answer expressible:
  the six comuni divided between several collegi (Roma spans **seven** Camera
  collegi, 11.67 % of the population by `POP_2011`) are shown with **all** of
  them, never one.
- **Phase 31 — Staleness disclosure + live-refresh ADR** (`e21a236`,
  closeout `f2ab6f2`): **live refresh stays deferred**, re-derived from the
  shipped artifacts rather than inherited — 91 % of the bundle cannot change
  within the legislature, and refreshing the comuni table would *break* its
  legally-pinned join. What does age is the 8.88 % about named people
  (~1.6 group switches per month, measured), so the deliverable is
  **disclosure**: a Home footer line, `Ultimo aggiornamento dei dati: {date}`
  — deliberately not the phase file's wording, because the value is a max
  over a spread. Also fixed there: **every date the app rendered was one
  calendar day early west of Rome**, because the display formatters ran on
  the device timezone while every parser produces midnight Europe/Rome.
- **This phase — 32A: documentation, accessibility, release prep**: the v4
  accessibility checklist (`docs/v4/a11y-checklist.md`), README /
  `CLAUDE.md` / `docs/DATA_SOURCES.md` refreshed to the shipped state, this
  changelog entry, `docs/releases/v4.0-prototype.md`, and the final
  verification (`docs/v4/32a-release.md`). The accessibility work was not a
  formality: **Phase 24's audits were viewport-limited**, so its 62-finding
  inventory covered only each screen's first viewport. Rebuilding them to
  page through whole screens raised the same eight screens from 63 to **123**
  findings and the full app to **200** across 16 screen states — figures from
  the certifying run, and a lower bound rather than an exact count: the merge
  takes the maximum per element key and findings the auditor cannot attribute
  collapse onto one label, so an earlier run of the same code arrived at
  139/205 ([`docs/v4/a11y-checklist.md`](docs/v4/a11y-checklist.md) §1.3,
  which is why the triage is by cause and not by instance). The rebuild also
  turned up two real defects, both fixed here: `AddressSearchView` did not
  scroll, so Roma's three Senato collegi were listed in code and
  **unreachable on screen**; and both segmented pickers carried their
  identifier on the container, propagating it onto every segment. Tagging
  and pushing were
  deferred to Phase 32B pending the release actions below.
- **Phase 32B — release decisions + the tag** (2026-07-29): the user's
  decisions recorded verbatim in the addendum to
  [`docs/v4/32a-release.md`](docs/v4/32a-release.md), four pre-tag
  corrections landed first (the accessibility counts reconciled to the
  certifying run, the device-side gap disclosed in this entry, the
  reachability rule written into `CLAUDE.md`, and the reachability sweep
  recorded as deferred V5 work), and only then the **local annotated
  `v4.0-prototype` tag** at that decisions commit. That phase pushed nothing
  and made no GitHub call; it printed the push commands, which the user then
  performed — see the release actions below.

### Release actions (status after the 2026-07-29 post-release verification)

The user performs every remote action personally; no phase of this plan
pushes, tags remotely, or makes a GitHub call. Approval and per-item status
are quoted verbatim in
[`docs/v4/32a-release.md`](docs/v4/32a-release.md)'s "Decisions received"
addendum; what happened after the tag is in its "Post-release actions"
section, verified with two read-only commands (`git fetch origin --tags`,
`git ls-remote origin`).

- [x] **Branch `v4` pushed** — `f97a35a` by the user before Phase 32B ran,
      and Phase 32B's decisions commit `93527d4` after it. `origin/v4` =
      `93527d4`; the branch still exists on the remote.
- [x] **Tag `v4.0-prototype`** — **approved**, and created by Phase 32B as a
      **local annotated tag** at that phase's decisions commit, so the tag
      contains the complete release record. `v1.0.0`, `v2.0-prototype` and
      `v3.0-prototype` are untouched, and no other tag was created.
- [x] **Tag pushed** — **performed by the user**; the deliberate hold
      Phase 32B recorded is resolved as pushed. `refs/tags/v4.0-prototype` on
      the remote is the **same annotated object** (`7ded589`), peeling to
      `93527d4`. All four tags are on the remote, each resolving to the same
      commit it does locally.
- [x] **`v4` merged into `main`** — pull request **#3**, merged on GitHub as
      a **merge commit** (not squashed, not rebased): `origin/main` =
      **`7ea6a23`**, whose parents are `3dc224e` and `93527d4`. Every V4
      commit hash quoted in this entry therefore resolves on `main` too, and
      the tag sits **inside** `main`'s history. Same shape as the v3 line's
      PR #2.
- [ ] **Repository visibility / GitHub Release** — **still pending user
      decision**; release URL placeholder `<github-release-url>`. Neither was
      decided, public-vs-private is not determinable from the repository, and
      nothing is inferred from the v3 record. Whether a Release was published
      for the tag was not checked — that would have needed a network act
      outside the authorized read-only pair.
- [x] **V3/V4 commissioning brief archival** (Q6, open since v3 Phase 13) —
      **closed as never produced**, by the user's decision. Searched in
      Phases 13, 23 and 32A with the same result each time; the document was
      never provided, and nothing may be fabricated in its place, so no
      phase could ever have closed it. Not carried into V5.

**Known gap in this release — no device-side accessibility pass.** The 200
recorded `.contrast` / `.dynamicType` / `.textClipped` findings are triaged
by cause in [`docs/v4/a11y-checklist.md`](docs/v4/a11y-checklist.md), but
the residue after that triage needs a **measured contrast and Dynamic Type
judgment on a real device, in both appearances** — which no headless session
can produce, and which therefore did not happen for this release. The
auditor evaluates translucent `.regularMaterial` against an opaque
approximation and flags even `.primary` text, so its verdict cannot on its
own justify changing a colour. A full VoiceOver traversal (element order,
whether state changes are announced) is likewise still a human check, open
since the v2 checklist. This is not a blocker for tagging a prototype; it is
the honest gap in it.

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

### Release actions (status as of the post-22B record, 2026-07-21)

- [x] **Tag `v3.0-prototype`**: approved ("Proceed with Phase 22B." in
      response to the pending-decisions block — quoted in
      `docs/v3/22-release.md`), created locally by Phase 22B at the
      decisions commit, then **pushed by the user** together with the
      branch; `v3` was merged to `main` via PR #2 (`0baedaa`).
- [x] **GitHub Release**: **published by the user directly on GitHub**
      (2026-07-21, reported in-session). The release URL was not
      reachable unauthenticated at check time (HTTP 404 — consistent
      with a private repository), so no link is asserted here:
      placeholder `<github-release-url>` stands until a public URL
      exists or is provided. Repository visibility itself therefore also
      remains unstated rather than guessed.
- [x] **Retrospective `v1.0.0` tag**: **created by the user directly**
      (lightweight tag at `6d3b866`, "Complete Prototype v1"), observed
      on the remote post-22B. Phase 22B itself created no such tag — the
      plan's create-only-on-separate-instruction constraint bound the
      assistant's actions, and the user exercised the decision
      personally instead.
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
