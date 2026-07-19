# POLITICA — V3 Factual Baseline
### Precise current-state extraction for a new V3 architecture conversation. Contains **no** V3 feature plan.

Compiled 2026-07-18 from the source-grounded audit `implementation-evidence-v1-v2.md` and the committed repository documentation at tag `v2.0-prototype`. Confidence labels: **[E1]** verified from source/git · **[E2]** committed docs · **[E3]** unpreserved session narrative · **[E4]** audit-session direct execution · **[E5]** user-reported manual verification · **[E6]** *non verificabile* from available material. Full history, decision register, and 26-loop failure log: `POLITICA_IMPLEMENTATION_HISTORY_V1_V2.md`. Open conflicts/questions: `POLITICA_HISTORY_GAPS_AND_CONFLICTS.md`.

---

## 1. Identity and repository state [E1 unless noted]

- **Display name:** Politica ("Politica Italia" in README). **Xcode project/target/scheme:** Politici. **Bundle id:** `com.giuliocrp.Politici`. Never renamed at any point; the difference is intentional and constitutionally protected by `CLAUDE.md` constraint #1.
- **Remote:** `https://github.com/giuliocrp/politica.git`. Visibility (private per user report) [E6 from git alone].
- **History:** single linear chain, 17 commits, zero merge commits. `main` was **fast-forwarded** to `v2`'s tip; `main = v2 = origin/main = origin/v2 = 72448dc22c69ef8dfdb5ae33376186e14450bdf7`.
- **Tags:** exactly one — annotated `v2.0-prototype` → `72448dc`. **There is no `v1.0.0` tag**; "v1.0.0" is a documentation-only label for boundary commit `6d3b866` (identified via commit message + reflog). Working tree byte-identical to the tag at audit time.
- **Key commits:** `3ab4e58` (initial template) · `6d3b866` (v1 boundary) · `b0b6c77`…`a084f3d` (v2 Phases 0–11) · `72448dc` (docs + tag). Full map in Document A, Appendix A.
- **Platform facts:** SwiftUI + MapKit; `SWIFT_VERSION = 5.0`; `IPHONEOS_DEPLOYMENT_TARGET = 26.5` — a stock-template default present since the first commit, never lowered, despite the app using **no API newer than iOS 17** (`Map`/`MapPolygon`/`MapReader`, `NavigationStack`, `ContentUnavailableView`). Rationale for non-action undocumented [E6].
- **Build/test commands** (documented + used): `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Politici.xcodeproj -scheme Politici -destination 'generic/platform=iOS Simulator' build`; tests via a discovered simulator name. The `DEVELOPER_DIR` prefix is deliberate command-scoped toolchain selection (never global `xcode-select` mutation).

## 2. Runtime architecture [E1]

- `@main PoliticiApp` builds `ServiceContainer.live` once → `.environment(\.services, …)`; `ContentView` owns one `NavigationStack` over `[AppRoute]` with a single `navigationDestination` switch. Views read services via `@Environment(\.services)` only.
- **ServiceContainer (6):** `DistrictService` (bbox-prefiltered `district(for:)`), `RepresentativeService`, `VoteService` (newest-first), `GeocodingService` (`CLGeocoder` + hardcoded 5-city offline fallback — **byte-identical to v1**; conforms to `GeocodingProviding`), `ManifestService` (`sources.json`), `PartyStyleService` (`parties.json`; gray fallback). **Outside the container by design:** `AddressAutocompleteService` (`MKLocalSearchCompleter`, `.address`, Italy-biased) as a per-screen `@StateObject` in `AddressSearchView` (session-scoped UI state, per its own doc comment).
- **AppRoute (8 cases):** `.map`, `.addressSearch(initialQuery:)`, `.districtDetail(districtId:)`, `.collegiList`, `.representativeList`, `.representativeProfile(representativeId:)`, `.voteHistory(representativeId:)`, `.fontiEDati`.
- **Screens (9):** Home (stats row per `HomeView.swift` at the tag: "Collegi campione" and "Rappresentanti" dynamic — `allDistricts().count` / `allRepresentatives().count`, i.e. the live 147/601; "Camere del Parlamento" a static hardcoded `"2"`, not a Button, no navigation; featured 4; "Vedi tutti"; "Come funziona l'elezione" DisclosureGroup; info button + footer → Fonti), Map (tap-select via `MapReader`+`SpatialTapGesture`; toolbar "Sfoglia come elenco"; **legend still lists a Senato color though zero Senato features exist** — dead content), AddressSearch, CollegiListView (all 147, searchable name/circoscrizione), RepresentativeListView (all 601, searchable, **12** party chips deduplicated by shortName), DistrictDetail (+`RepresentativeRow`,+`InitialsAvatar` 52/96 pt), RepresentativeProfile (provenance badge; attendance hidden when nil), VoteHistory (+`VoteRow`,+non-color `VoteBadge`; "Fonte" Link kept as its own VoiceOver element), FontiEDati (manifest-driven cards, disclaimer, 3 avvertenze).
- **Component convention:** small views shared by exactly two screens live beside their primary consumer; 3+ consumers may graduate to their own file (written rule in `CLAUDE.md`).
- **Runtime network boundary:** zero app-owned networking. Only Apple services (`CLGeocoder`, `MKLocalSearchCompleter`), each degrading offline. All data bundled, read once at launch.
- **Error/empty strategy:** tolerant decoding; conditional rendering of optionals; exact Italian empty states — "Nessun rappresentante collegato in questa versione del prototipo." / "Nessuna votazione disponibile in questa versione del prototipo." / out-of-coverage "Non è stato possibile associare l'indirizzo a un collegio elettorale."

## 3. Data model (schema v2) [E1]

- **DataProvenance** `.sample`/`.official` on every model; decoder default `.sample` when absent (keeps pre-v2 fixtures decoding). Display: "Dati dimostrativi"/"Fonte ufficiale".
- **TolerantStringEnum** (`Models/TolerantDecoding.swift`): unknown raw → the enum's `unknownCase` (`.sconosciuto`) instead of throwing. Conformers **must call `decodeTolerant` from their own `init(from:)`** — Swift's synthesized Decodable outranks a protocol-extension witness (documented in the type). Conformers: `CollegioType`, `ElectionType`, `VoteChoice`, `VoteResult`.
- **District:** `id` (=`CU20_COD` as string), `name` (=`CU20_DEN`), `chamber` ("Camera"), `polygons: [MKPolygon]`, computed `boundingMapRect`, `collegioType`, `circoscrizione: String?`, `subCode: String?`, `provenance`, `sourceName`. v1's `Coordinate`/`polygonRings` removed.
- **Representative:** `id` (`p######`/`s####`), `name`, `chamber`, `districtId: String?` (**147 non-null**, all uninominale deputies), `party`, `parliamentaryGroup`, `committees`, `attendanceRate: Double?` (**nil for all 601**), `photoName` (SF Symbol; superseded visually by initials avatars), `provenance`, `legislature` ("XIX"), `electionType`, `stableSourceId: String?` (bare numeric from the source URI; unique across 601; **the votes join key**), `sourceUrl: URL?`. Known drift: the `districtId` doc comment still describes the pre-linkage state [E1].
- **Vote:** `id` (source `ocd:voto` segment, e.g. `vd19_690_076_50204`), `representativeId`, `title`, `date`, `vote: VoteChoice` (+`symbolName`/`accessibilityLabel` for `VoteBadge`), `result: VoteResult`, `sourceUrl: String?` (verbatim `dc:relation` or null — never constructed), `provenance`.
- **SourcesManifest/DataSource** ← `sources.json` (`schemaVersion: 2`). **PartyStyleEntry** `{value, shortName, colorHex}` ← `parties.json`.

## 4. Shipping data inventory [E1, re-measured]

| Dataset | Content | Size |
|---|---|---|
| `districts.geojson` | **147** Camera collegi uninominali (ISTAT, D.Lgs. 177/2020); **56 MultiPolygon / 91 Polygon**; EPSG:4326; simplified 1000 m Douglas-Peucker | 1,158,457 B (~1.10 MB; gate 3 MB) |
| `representatives.json` | **601** = 400 Camera + 201 Senato (196 elettivo + 5 a vita: Cattaneo, Monti, Piano, Rubbia, Segre); Camera electionType **147 uninominale / 245 plurinominale / 8 estero**; 147/147 collegio linkage; 100% official | 439,399 B |
| `votes.json` | **4,788** per-deputy positions across **12** roll-call events (12 distinct official sourceUrls); Contrario 2,938 / Assente 980 / Favorevole 836 / Astenuto 34; all 12 events `Respinto`, all from the sitting of 2026-07-15, all odg motions on bill 2822-A, all atto-less titles; 399/400 deputies appear (exception: Lorenzo Fontana, Chamber President, by custom); 100% official | 1,878,366 B (~1.79 MB; gate 2 MB) |
| `parties.json` | **19** exact-string entries (10 Camera siglas incl. MISTO; 9 Senato full names incl. Misto) → **12** distinct shortNames (e.g. FDI + "Fratelli d'Italia" → "FdI"); every colorHex ≥4.5:1 vs white (test-enforced); entries deliberately NOT merged cross-chamber at the color level | — |
| `sources.json` | **5** entries: Camera people (CC BY 4.0, 2026-07-18) · Camera votazioni (CC BY 4.0, 2026-07-18) · Senato (CC BY 3.0, 2026-07-18) · ISTAT collegi (CC BY 4.0, 2026-07-18) · sample fixtures (n/a, 2026-07-17). Cross-checked 1:1 vs `docs/DATA_SOURCES.md` | — |
| `*.sample.*` fixtures | v1's fictional 5 districts / 14 representatives / 37 votes; test-only, loaded by explicit resource name; never a shipping default | — |

## 5. Developer pipeline (`tools/`) [E1]

- **Targets:** `fetch` (the **only** network step; SPARQL → gitignored `tools/raw/`; stamps `.fetch_metadata.json`) · `import` · `validate` · `manifest` · `boundaries` (processes the **manually downloaded** ISTAT shapefile; does not fetch it) · `all` (includes fetch). Refresh: `make fetch && make all`.
- **Endpoints/queries:** Camera `https://dati.camera.it/sparql` (`camera_deputati.rq`; `camera_votazioni_scope.rq` + `camera_votazioni_dettaglio.rq`); Senato `https://dati.senato.it/sparql` (three queries — senatori/gruppi/commissioni — merged by senator URI). All queries pinned `.rq` files, never inline.
- **Client (`sparql_client.py`):** stdlib urllib; `USER_AGENT = "PoliticaApp-DataPipeline/1.0 (tools/fetch_*.py; civic-tech prototype, non-commercial)"` (required — dati.senato.it rejects the default `Python-urllib` UA); `TIMEOUT_SECONDS=60`; `MAX_ATTEMPTS=3`, exponential backoff from 2 s; 4xx never retried.
- **Importers:** `import_representatives.py` — merge + linkage; `normalize_circoscrizione` (uppercase, strip accents/punct, split on "/" keep Italian segment) joining `(circoscrizione_norm, subCode)`; `UNINOMINALE_TIPO_ELEZIONE = {"maggioritario","maggioritario suppletiva"}`; `ESTERO_COVERAGE_VALUES`; **gate `MIN_LINKED_COLLEGI = 133`** (90% — below it: fail loudly, write nothing). `import_votes.py` — `RAW_VOTE_CHOICE` map; `clean_atto_label` (html.unescape + `ATTO_LABEL_ARTIFACT_RE` stripping a literal `^^…XMLSchema#string` leak); `build_title` (procedural — atto when present); budget: config `maxPositionRecords=5000` + hard `MAX_OUTPUT_BYTES = 2 MiB` checked on serialized bytes **before** writing (refused a real 2.20 MB output once); newest-first, **stops at the first whole vote that would exceed budget** (never bin-packed, never intra-vote truncation). `import_boundaries.py` — schema-v2 transform; `chamber:"Camera"` capitalized to match the non-tolerant Swift enum; one-time `districts.sample.geojson` backup; 3 MB gate; hard failure if `CU20_DEN` stops matching `"{circoscrizione} - {CU20_C1}"`.
- **Validation (`validate_data.py`):** re-checks from written files, from scratch: `EXPECTED_CAMERA…=400`, `EXPECTED_SENATO…=201`, `EXPECTED_DISTRICT_COUNT=147`, size caps, id uniqueness, `validate_linkage`, `validate_votes_reference_representatives`; exit≠0 with diagnostics.
- **Manifest (`make_manifest.py`):** `retrievedAt` from fetch metadata (not run time); the votes note computed from **actual** imported counts.
- **Determinism/fail-loud:** every importer computes+validates fully in memory, then writes; failures write nothing; outputs deterministically sorted.
- **Config:** `votes_scope.json = {mode:"recent", n:25, voteUris:[], maxVotes:25, maxPositionRecords:5000}` (explicit-URI mode supported/validated, unused).
- **Boundary toolchain:** `ogr2ogr` (GDAL) EPSG:32632→4326 + `-simplify` 1000 m Douglas-Peucker (plan had said mapshaper/Visvalingam; no per-feature vertex gate evidenced).

## 6. Key verified domain facts [E1/E2]

- Camera 400 = exact constitutional size; 414 XIX mandati − 14 ended; current-mandate `MINUS` on `ocd:endDate` verified count-neutral.
- Senato inclusion rule: no `fineMandato` bound → 201; Napolitano correctly excluded (`fineMandato 2023-09-22`).
- Linkage keys: SPARQL `?el ocd:tipoElezione` + `?el dcterms:spatial` ("{CIRCOSCRIZIONE} - U0N", **only** on maggioritario[-suppletiva]); the older `?collegio` (`dc:coverage`) is **plurinominale-granularity** (all 55 values P0N/none) and unusable for uninominale identity. 28 circoscrizioni = exactly the D.Lgs. 177/2020 list; Valle d'Aosta bilingual name handled by the "/" split. Result: **147/147 exact bijection, 0 ambiguous, 0 vacant; by-election holders Giulio Centenaro (50202) and Alberto Di Rubba (50201)**.
- Votes ontology: vote-level `dc:title` is always a generic procedural template; real subject on the atto's `rdfs:label` (OPTIONAL); `dc:relation` = official scheda deep link; per-deputy `ocd:voto` with `dc:type` vocabulary {Favorevole, Contrario, Astensione→`.astenuto`, "Non ha votato"→`.assente` (disclosed best fit), "Ha votato" (secret only)}; **secret ballots (`votazioneSegreta 1`; 98 of 37,959 XIX votazioni) never disclose positions** — excluded by design as inherent unattributability, not missing data. `ocd:rif_deputato` numeric id ≡ `stableSourceId`.
- `MKGeoJSONDecoder` decodes GeoJSON MultiPolygon to **one `MKMultiPolygon`** (not flattened MKPolygons) — settled, code-commented knowledge; `GeoJSONLoader` unwraps both shapes. Missing this silently empties 56/147 districts.
- Point-in-polygon: bbox prefilter (`boundingMapRect.contains`) → even-odd ray cast per candidate, holes-aware (`interiorPolygons`), multi-part via `contains(_:inAny:)`; measured ~0.07 s / 1,000 random Italian coordinates / 147 collegi.
- Manual external verification on record: vote `RifVotazione=690_76` — Foti `Contrario`✓, Bergamini `Favorevole`✓ vs. the official page [E2; live fetch E3].

## 7. Tests and verification state

- **Static at tag [E1]:** `PoliticiTests` **92** methods (91 XCTest + 1 Swift Testing) across 11 files — SchemaV2 23 · ServiceLookup 11 · Decoding 9 · DistrictBoundaries 8 · Initials 8 · PointInPolygon 7 · GeocodingProviding 7 · PartyStyleService 6 (incl. WCAG ≥4.5:1) · VoteChoiceAccessibility 6 · DateFormatting 5 · template 1. `PoliticiUITests`: **3 template methods, no real UI automation** (unchanged since v1).
- **Observed [E4]:** 96–97 passed / 0 failed in the audit session's own `xcodebuild test` runs at/near the tag (iPhone 17 Pro simulator). The 92-vs-96/97 gap is an **unreconciled, disclosed discrepancy** — resolve only by re-running and reading the log.
- **Integrity-test provenance [E1]:** the vote↔representative check went removed-with-comment (`f6867eb`) → reinstated-vacuous-with-comment (`8b16be1`) → genuinely-exercised-comment-only-change (`6625944`). Rule now written down: shipping data and tests disagree ⇒ fix the data, never the test.
- **Manual-only areas:** all UI interaction; VoiceOver (never driven by any agent — the checklist discloses it); Dynamic Type screenshots exist for HomeView only (M + XXXL) [E4]; hit targets computed from layout, not Inspector-measured. The five pending human checks in `a11y-checklist.md` are reported completed and working by the user [E5]; the repo records them as pending.

## 8. Invariants V3 must preserve (standing written constraints + verified conventions)

1. Never rename project/target/scheme/bundle id (`Politici` / `com.giuliocrp.Politici`); display name stays `Politica`.
2. In-app strings Italian-only; repository docs English; never cross the two.
3. Shipping app local-first at runtime — **no** networking under `Politici/`; `tools/fetch_*` is the only network surface.
4. Never present sample as real; never fabricate — null over guess; unknown vocabulary → explicit `.sconosciuto` + logged warning; best-fit mappings only if disclosed and justified.
5. `Data/*` are generated artifacts — never hand-edited; fix the producing script and re-run.
6. `tools/raw/` never committed; queries pinned as `.rq` files.
7. `*.sample.*` fixtures: test-only, name-loaded, never a shipping default; new real datasets follow the same preservation pattern.
8. Shipping-bundle referential integrity always green; when data and tests disagree, fix the data.
9. Attribution renders from the manifest; `retrievedAt` means fetch time; `docs/DATA_SOURCES.md` manually re-synced after `make manifest`.
10. Methodology: audit/verify before implementing; diagnose root cause before changing code or test; report findings (including inconvenient ones) in a committed phase doc.

## 9. Reusable extension seams

fetch→cache→import→validate→manifest pattern for any new dataset · `TolerantStringEnum` for any new external vocabulary · `GeocodingProviding` for geocoding evolution · `ServiceContainer` for new services · `AppRoute` for new screens · the sample-fixture convention · the dual budget-cap pattern (record cap + pre-write byte cap, stop-at-whole-record-group) · the `MIN_LINKED_*` quality-gate pattern for any new linkage · `stableSourceId` numeric ids as cross-graph join keys · `parties.json` shortName layer for user-facing grouping without data-layer merges · the settled `MKGeoJSONDecoder`/`MKMultiPolygon` unwrapping.

## 10. Fragile areas (verified)

`CU20_DEN` parse rule (guarded, but a parse rule on a denomination string) · atto-combined title path never exercised by shipped data · one-sitting/one-bill votes slice may shape UX assumptions · `docs/DATA_SOURCES.md` manual sync · deployment target 26.5 · dead Senato legend entry in `MapView` · stale `Representative.districtId` doc comment · `make all` re-runs `fetch` inside the documented shorthand · VoiceOver completeness rests on user report, not automation.

## 11. Open factual questions (details in Document C)

Repo visibility; tag pushed? GitHub Release exists? · v1.0.0 tag: intended and skipped, or documentation-only by design? · 92 vs 96–97 test count · the CLGeocoder-deprecation-warning history (audit found none in the targeted SDK) · ISTAT `RetrievedAt 2025-07-18` (SOURCES.txt as quoted) vs manifest `2026-07-18` · Senato-legend intent · 26.5 rationale · do the original kickoff/phase-prompt/completion-summary artifacts survive anywhere? · Senato ISTAT layer fields/CRS (present in cache, unexamined) and Senato SPARQL election predicates (never explored) · whether older votazioni carry attos (to exercise the combined-title path).

## 12. Decisions requiring user/product input before V3 design

Senato ambition (boundaries, linkage, votes?) · plurinominale representation approach · votes scope/storage strategy · live refresh vs. strict snapshot (and how it squares with "local-first") · photos (rights) and attendance (methodology) — both currently "no" · tagging/release scheme (retro-tag `6d3b866`?) and repo visibility · CI · deployment-target change.

## 13. Performance envelope (current, measured/verified)

147 overlays render smoothly per manual checks; `district(for:)` ~0.07 s / 1,000 lookups; bundle data ≈ 3.3 MB total (1.10 + 0.43 + 1.79 + small files) against per-file gates of 3 MB (districts) and 2 MB (votes). Adding the Senato uninominale layer (its feature count is not recorded in the available material — the sibling ISTAT layer sits unexamined in the cache) would add a second overlay layer of comparable order; re-run the perf test and restate the byte-budget policy before any growth.

*End of Document B.*
