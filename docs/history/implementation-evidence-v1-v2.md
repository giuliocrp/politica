# Politica / Politici — Implementation Evidence: v1.0.0 → v2.0-prototype

Historical forensics report. Produced without modifying any tracked file,
without network fetches, without touching `tools/raw/`, and without
committing, tagging, merging, or switching the working tree. All release
content was inspected with `git show`, `git ls-tree`, and `git diff`
against the relevant commit/tag — no tag was checked out.

## 1. Evidence and methodology

**Repository state at the start of this audit**: `git status` reported a
clean working tree ("nothing to commit, working tree clean") on branch
`main`, `HEAD` at commit `72448dc`. This satisfied the pre-flight
requirement to stop and list changes if the tree were dirty — it was not
dirty, so the audit proceeded.

**How evidence was gathered**: `git log --graph --decorate --oneline
--all`, `git tag --list --sort=creatordate`, `git reflog show <ref>` for
branch-history reconstruction, and `git show <ref>:<path>` /
`git ls-tree -r --name-only <ref>` for point-in-time file contents — never
`git checkout`. Data counts were computed by piping `git show
<ref>:Politici/Data/*.json` output directly into short, disposable Python
one-liners (read-only; nothing written back to the repository). Where the
current working tree is confirmed byte-identical to the `v2.0-prototype`
tag (verified below, §3), evidence gathered by reading the working tree
directly is equivalent to reading the tag and is cited as such.

**Source-priority discipline applied throughout**: source code/data/tests
at the cited commit outrank git history, which outranks committed docs
(`README.md`, `CHANGELOG.md`, `CLAUDE.md`, `docs/v2/*`,
`docs/DATA_SOURCES.md`), which outrank narrative summaries, which outrank
original planning prompts. Where these disagreed, the higher tier is what
this report asserts, and the disagreement itself is noted.

**Confidence categories used throughout this report** (see §22 for the
full table) — five as specified, plus one this repository's history
required distinguishing:

1. **Verified from source/git** — read directly from a cited commit's tree via `git show`/`git ls-tree`/`git diff`.
2. **Recorded in committed documentation** — asserted in a committed `.md` file, not independently re-derived from code for this report.
3. **Reported by historical Claude Code summaries** — narrative claims from prior AI-assistant conversation turns *that are not themselves preserved in the repository* (e.g. described a diagnostic process using scratch scripts that were deleted and never committed).
4. **Directly executed in this authoring session** — a build/test run this report's author (Claude) personally invoked and observed the output of, in the same continuous session as this report, distinguished from category 3 because it is a first-hand, current-session observation rather than a secondhand summary of a past one.
5. **Manually verified by the user** — explicitly attributed to the human user having checked something themselves (e.g. a simulator walkthrough), never claimed unless the source material says so.
6. **Non verificabile dal repository** — cannot be established from anything in the repo; stated explicitly with what evidence would be needed instead of guessed.

A plan proves intent, not implementation — where a source (a prompt, a
comment) describes an intention, and the shipped code differs, this report
states what shipped and flags the deviation (see §17).

## 2. Canonical naming and release map

Per this task's explicit instruction, these identifiers are treated as
fixed and are not reinterpreted:

| Term | Meaning |
|---|---|
| Politica | User-facing app display name (`INFOPLIST_KEY_CFBundleDisplayName`) |
| Politici | Xcode project, target, and scheme name; bundle id root `com.giuliocrp.Politici` |
| v1.0.0 | Original fictional/sample-data prototype (alias: "V0") |
| v2.0-prototype | Real-data and accessibility prototype (alias: "V1") |

**Finding, stated plainly because it materially affects §3**: there is
**no git tag named `v1.0.0`** anywhere in this repository — local or
remote-tracking. `git tag --list --sort=creatordate` returns exactly one
tag: `v2.0-prototype`. The "v1.0.0" label used throughout this report (and
in `CHANGELOG.md`) is a **documentation-only designation**, not a
git-verifiable release boundary. See §3 for how the v1.0.0 boundary commit
was identified in the absence of a tag, and §22 for how this affects
confidence on every v1-boundary claim.

## 3. Git/tag/commit timeline

### Tag verification (task pre-flight step 3)

```
git tag --list --sort=creatordate
  -> v2.0-prototype
```

`git rev-parse v2.0-prototype` → `a7593ad...` (the **tag object**, an
annotated tag); `git rev-parse v2.0-prototype^{commit}` → `72448dc22c69ef8dfdb5ae33376186e14450bdf7`
(the commit it points to). `git cat-file -t v2.0-prototype` confirms it is
an **annotated** tag object (carries its own message, tagger, and date),
not a lightweight ref.

`v1.0.0` does not exist as a tag. Its boundary is inferred (not verified
via a tag) from two independent pieces of evidence that agree:
1. Commit message content: `6d3b866` — *"Complete Prototype v1: all
   phases, icon, display name rename"*.
2. Branch-history evidence: `git reflog show main` shows
   `main@{1}: commit: Complete Prototype v1: ...` immediately followed by
   `main@{0}: merge v2: Fast-forward` — i.e. `6d3b866` is the last commit
   made directly on `main` before the `v2` branch's work was fast-forwarded
   back onto it. `git reflog show v2` independently confirms `v2@{14}:
   branch: Created from HEAD` at `6d3b866`.

This report therefore treats `6d3b866fb85947506b2d03a0b289a6e791de3086`
as the v1.0.0 boundary commit — **verified from git structure**, but
explicitly **not** a tag, and the "v1.0.0" name for it is a documentation
convention (`CHANGELOG.md`), not a git artifact.

### Branch relationship (recoverable locally)

The full history is a **single linear chain** — `git log --all --merges
--oneline` returns nothing; there is no merge commit anywhere in this
repository's history. `git branch -a` shows exactly two local branches
(`main`, `v2`) and two remote-tracking branches (`origin/main`,
`origin/v2`), **all four currently pointing at the identical commit**
`72448dc`. Reconstructed sequence, from `git reflog show HEAD`:

1. `main` accumulates the two pre-v1 commits and the v1.0.0 boundary
   commit (`3ab4e58` → `5d8e36a` → `6d3b866`).
2. `v2` branch created from `HEAD` at `6d3b866` (`v2@{14}`).
3. All 12 v2-phase commits (`b0b6c77` through `a084f3d`) and the final
   documentation commit (`72448dc`) are made directly on `v2`, one after
   another — 13 commits, zero merges, zero branches-off-branches.
4. `main@{0}: merge v2: Fast-forward` — `main` is fast-forwarded to `v2`'s
   tip. No merge commit was created (a fast-forward moves the branch
   pointer; it does not add a commit), so `main` and `v2`'s histories are
   now byte-identical, not just convergent.
5. The annotated tag `v2.0-prototype` was created pointing at `72448dc`,
   the tip of that fast-forwarded `main`.

Remote: `git remote -v` shows a single remote, `origin`, at
`https://github.com/giuliocrp/politica.git` (fetch and push). Whether that
GitHub repository is public or private is **Non verificabile dal
repository** — nothing in a local git clone records that setting; it would
require checking the GitHub repository's own settings page or API.

### Chronological commit table

| # | Commit | Date | Subject | Release/phase | Significance |
|---|---|---|---|---|---|
| 1 | `3ab4e58` | 2026-07-16 | Initial Commit | pre-v1 | Stock Xcode "App" template — `Item.swift`, flat `ContentView.swift`/`PoliticiApp.swift`, no Models/Services/Views structure, no district/representative/vote code at all. Bundle id `com.giuliocrp.Politici` and target/scheme name `Politici` already present here — never renamed at any later point (verified: `git show 3ab4e58:Politici.xcodeproj/project.pbxproj` shows the same `PRODUCT_BUNDLE_IDENTIFIER` values as the tag). |
| 2 | `5d8e36a` | 2026-07-17 | Add Xcode gitignore and clean up tracked artifacts | pre-v1 | Adds `.gitignore` (Xcode/macOS/SPM patterns only at this point — no `tools/raw/` or Python patterns yet, since `tools/` doesn't exist until commit 9). |
| 3 | `6d3b866` | 2026-07-17 | Complete Prototype v1: all phases, icon, display name rename | **v1.0.0 boundary** (no tag — see above) | Single commit that builds the entire v1 feature set: Models/Services/Utilities/Views, 5 fictional districts, 14 fictional representatives, 37 fictional votes, `README.md`. The "display name rename" in the message is scoped precisely — `git diff 3ab4e58 6d3b866 -- Politici.xcodeproj/project.pbxproj` shows exactly a 2-line addition of `INFOPLIST_KEY_CFBundleDisplayName = Politica;` to the Debug and Release configs. Bundle id/target/scheme/`PRODUCT_NAME` are untouched. |
| 4 | `b0b6c77` | 2026-07-17 | chore(v2): audit repo, create v2 branch, add CLAUDE.md guardrails | v2 Phase 0 | `v2` branch created from `6d3b866`. Adds `docs/v2/00-audit.md` (baseline snapshot) and the original `CLAUDE.md`. |
| 5 | `bdff254` | 2026-07-17 | test(v2): bootstrap PoliticiTests with geometry, decoding, and service coverage | v2 Phase 1 | First real automated test coverage — v1 shipped with template-only tests (see §14). |
| 6 | `d9a922f` | 2026-07-17 | feat(v2): schema v2 — provenance, tolerant decoding, sources manifest | v2 Phase 2 | Adds `DataProvenance`, `TolerantStringEnum`, `SourcesManifest`/`ManifestService` — the infrastructure every later real-data phase depends on. |
| 7 | `e6e5ffe` | 2026-07-17 | feat(v2): add Informazioni e fonti attribution screen with disclaimers | v2 Phase 3 | `FontiEDatiView` + `.fontiEDati` route, wired before any real data existed to attribute. |
| 8 | `b92ffd8` | 2026-07-17 | feat(v2): MKLocalSearchCompleter address autocomplete behind GeocodingProviding | v2 Phase 4 | `AddressAutocompleteService`, `GeocodingProviding` protocol seam. |
| 9 | `f01dd15` | 2026-07-17 | chore(v2): create tools directory and ignore tools/raw | v2 Phase 5 (setup) | `tools/raw/` added to `.gitignore`; pipeline scaffold begins. |
| 10 | `f6867eb` | 2026-07-18 | feat(v2): import real representative data from Camera/Senato open data | v2 Phase 5 | `representatives.json` → 601 real records. `Representative.districtId` becomes optional. Vote↔representative referential-integrity test **weakened** here (see §18). |
| 11 | `8b16be1` | 2026-07-18 | fix(v2): reconcile bundle integrity, honest empty states, sigla styling, pipeline hygiene | v2 Phase 6 | `votes.json` shipped empty (valid schema, no records) — referential-integrity test reinstated but **vacuously true** (see §18). `Data/parties.json`/`PartyStyleService` added. |
| 12 | `9841fea` | 2026-07-18 | feat(v2): official ISTAT electoral-college boundaries with MultiPolygon engine | v2 Phase 7 | `districts.geojson` → 147 real ISTAT collegi, `MKGeoJSONDecoder`/`MKPolygon`/`MKMultiPolygon` geometry engine (see §10). |
| 13 | `2820bec` | 2026-07-18 | feat(v2): link current deputies to ISTAT colleges; fix collegio circoscrizione metadata | v2 Phase 8 | 147/147 uninominale→deputy linkage; `region`→`circoscrizione`/`subCode` correction (see §11). |
| 14 | `6625944` | 2026-07-18 | feat(v2): curated official Camera votes with per-deputy positions | v2 Phase 9 | `votes.json` → 4,788 real positions across 12 vote events. Referential-integrity test becomes **genuinely** non-vacuous here (see §18). |
| 15 | `8a1aa90` | 2026-07-18 | feat(v2): UI completion for real data — search, party filters, initials avatars, and explainer copy | v2 Phase 10 | `RepresentativeListView`, `InitialsAvatar`, "Come funziona l'elezione" explainer. |
| 16 | `a084f3d` | 2026-07-18 | feat(v2): accessibility pass — VoiceOver, Dynamic Type, non-color vote indicators, collegi list | v2 Phase 11 | `CollegiListView`, non-color-only `VoteBadge`, VoiceOver/Dynamic Type/hit-target work (see §15). |
| 17 | `72448dc` | 2026-07-18 | docs(v2): README v2, data source documentation, changelog for v2.0-prototype | **v2.0-prototype tag target** | `README.md` rewritten, `docs/DATA_SOURCES.md` and `CHANGELOG.md` added, `CLAUDE.md` refreshed. Tag `v2.0-prototype` points here. |

All 17 commits fall between and including the two release boundaries — 14
commits separate the v1.0.0 boundary (`6d3b866`) from the `v2.0-prototype`
tag target (`72448dc`), all on branch `v2` before its fast-forward into
`main`.

**Do both tags point directly at release commits, or at pre-merge branch
commits?** `v2.0-prototype` points at `72448dc`, which — per the reflog —
*is* the exact commit `main` was fast-forwarded to; there is no distinct
"merge commit" it could instead point to, because none exists. So yes,
directly at the release commit, and that same commit is simultaneously the
tip of `main`, `v2`, `origin/main`, and `origin/v2`. There being no
`v1.0.0` tag, the question doesn't apply to that boundary — it's a bare
commit on `main`, never tagged.

## 4. v1.0.0 implementation snapshot

All facts in this section were read via `git show 6d3b866:<path>` /
`git ls-tree -r --name-only 6d3b866`; none required checkout.

### Directory and file layout

```
Politici.xcodeproj/
Politici/
├── App/{PoliticiApp,ContentView}.swift
├── Assets.xcassets/ (AccentColor, AppIcon — icon.png, Contents.json)
├── Models/{District,Representative,Vote}.swift
├── Services/{ServiceContainer,GeoJSONLoader,DistrictService,RepresentativeService,VoteService,GeocodingService}.swift
├── Utilities/{PointInPolygon,DateFormatting}.swift
├── Views/{AppRoute,HomeView,MapView,AddressSearchView,DistrictDetailView,RepresentativeProfileView,VoteHistoryView}.swift
└── Data/{districts.geojson,representatives.json,votes.json}
PoliticiTests/PoliticiTests.swift
PoliticiUITests/{PoliticiUITests,PoliticiUITestsLaunchTests}.swift
README.md, icon.png, .gitignore
```
32 files total (excluding the `.xcodeproj` internals). Matches the tree
already documented in the committed `docs/v2/00-audit.md` — independently
re-verified for this report via `git ls-tree`, not merely trusted.

### App entry point and dependency injection

`Politici/App/PoliticiApp.swift`: `@main struct PoliticiApp: App` holds
`private let services = ServiceContainer.live` and injects it once via
`.environment(\.services, services)` on the root `WindowGroup`'s content.
`ContentView.swift` owns `@State private var path: [AppRoute]` and a
`NavigationStack(path:)` with a single `.navigationDestination(for:
AppRoute.self)` switch. This exact pattern (`ServiceContainer.live`
constructed once in `PoliticiApp`, environment-injected, read back via
`@Environment(\.services)`) is unchanged in structure through v2 — v2
only adds services to the container, it doesn't change the injection
mechanism.

### Models

- `Chamber: String, Codable, CaseIterable, Hashable` — `.camera`/`.senato`, unchanged raw values through v2.
- `Coordinate: Codable, Hashable` — plain `{latitude, longitude}` struct with a `clLocationCoordinate2D` computed property. **Removed entirely in v2** (superseded by native `MKPolygon`/`CLLocationCoordinate2D` — see §10).
- `District: Identifiable, Hashable`, custom `Decodable` parsing a GeoJSON `Feature` directly: `id`, `name`, `chamber`, `polygonRings: [[Coordinate]]` (first ring exterior, further rings holes — **but no code in v1 ever reads a second ring**; `exteriorCoordinates` only reads `polygonRings.first`). A `centroid` computed property existed but had no call site found in v1's Views (grep across `Politici/Views/*.swift` at `6d3b866` for `centroid` returns no match) — **Non verificabile dal repository** why it existed; possibly a preview/debug leftover, not confirmable from source alone.
- `Representative: Codable, Identifiable, Hashable` — `id, name, chamber, districtId: String` (**non-optional**), `party, parliamentaryGroup, committees: [String], attendanceRate: Double` (**non-optional**), `photoName`. No `provenance`, no `electionType`, no `stableSourceId`, no `sourceUrl` — all added in v2.
- `Vote: Identifiable, Hashable` — `VoteChoice` (favorevole/contrario/astenuto/assente — **no `.sconosciuto` case**), `VoteResult` (approvato/respinto — **no `.sconosciuto` case**), both plain `Codable` (throwing on an unrecognized raw value, not tolerant). `Vote` itself: `id, representativeId, title, date, vote, result, sourceUrl: String?`, with a self-contained `yyyy-MM-dd` `DateFormatter` for encode/decode.

### Services and utilities

- `ServiceContainer`: bundles exactly 4 services — `DistrictService`, `RepresentativeService`, `VoteService`, `GeocodingService` — via a `static let live` and an `EnvironmentKey`. (v2 adds `ManifestService` and `PartyStyleService` — 6 total; §5.)
- `DistrictService.district(for:)`: **no bounding-box prefilter** — iterates every district and calls `PointInPolygon.contains(coordinate, in: district.exteriorCoordinates)` directly (linear scan, exterior ring only, no holes).
- `RepresentativeService`/`VoteService`: identical shape to their v2 counterparts (`allX()`, `x(withId:)`/`x(for:)`) — this part of the architecture was stable from v1 onward.
- `GeocodingService`: `CLGeocoder` first, then a **hardcoded 5-city fallback table** (Roma/Milano/Napoli/Torino/Firenze coordinates), matched via `.folding(options: [.diacriticInsensitive, .caseInsensitive])` substring containment. This exact fallback mechanism and matching approach is **unchanged in v2** (same file, same table, same folding call — confirmed by direct comparison of `GeocodingService.swift` at both refs).
- `GeoJSONLoader`: v1's `loadDistricts` decodes a hand-rolled `DistrictFeatureCollection: Decodable { let features: [District] }` wrapper — plain `JSONDecoder`, no `MKGeoJSONDecoder`. `MapBounds` is a hand-rolled `{northEast, southWest}` struct with its own bounding-math `region` computed property (replaced in v2 by an `MKMapRect`-backed version — §10).
- `PointInPolygon.contains(_:in:)`: even-odd ray-casting over a plain `[CLLocationCoordinate2D]` ring. **No holes support, no MultiPolygon support** — operates on one flat ring only. This single-ring function is retained unchanged in v2 as the low-level primitive; v2 adds `MKPolygon`- and multi-part-aware wrapper functions around it rather than replacing it (§10).
- `DateFormatting`: Italian-locale long/short/relative formatters — unchanged in v2.

### SwiftUI screens and navigation routes

`AppRoute` (v1): `.map`, `.addressSearch(initialQuery:)`, `.districtDetail(districtId:)`, `.representativeProfile(representativeId:)`, `.voteHistory(representativeId:)` — **5 cases**. No `.fontiEDati`, `.collegiList`, or `.representativeList` (all added in v2).

Screens: `HomeView` (search field, map CTA, 3-stat row, 4-item featured-representatives list — no "Come funziona l'elezione", no "Vedi tutti", no info-button toolbar item), `MapView` (§4's Geospatial subsection below), `AddressSearchView`, `DistrictDetailView` (hosts `RepresentativeRow` and a `PartyStyle` enum — a hardcoded `switch` over the 7 *fictional* party display names, e.g. `"Fratelli d'Italia"`, `"Movimento 5 Stelle"` — confirmed present at `6d3b866`, i.e. `PartyStyle` predates v2 entirely; v2's Phase 6 replaced it with data-derived `PartyStyleService`, it didn't introduce the concept), `RepresentativeProfileView`, `VoteHistoryView`.

### MapKit implementation

`MapView.swift`: `Map(position:)` with `MapPolygon(coordinates: district.exteriorCoordinates)` per district — the SwiftUI-native coordinate-array initializer, not `MKPolygon`/`MKGeoJSONDecoder`. Selection via `MapReader` + `SpatialTapGesture` converting the tap location to a coordinate, then `DistrictService.district(for:)`. Legend (2 colored dots), a bottom `selectionCard` with a "Vedi dettagli del collegio" button. This selection mechanism — tap-to-coordinate-to-point-in-polygon — is retained conceptually through v2; what changes is the geometry backing it (single exterior ring only, in v1) and, in v2 Phase 11, the discovery that this mechanism has no VoiceOver equivalent at all (§15).

### GeoJSON parsing and point-in-polygon approach

Covered above (`GeoJSONLoader`, `PointInPolygon`) — summary: hand-rolled `Decodable` GeoJSON parsing into a flat `[[Coordinate]]` ring array; ray-casting against the exterior ring only; no bounding-box prefilter; no holes; no MultiPolygon.

### Address search and fallback behavior

`AddressSearchView` (v1): free-text field + 5 sample-city quick-pick buttons, calling `GeocodingService.geocode(address:)` (CLGeocoder → 5-city fallback) then `DistrictService.district(for:)`. **No autocomplete** (`MKLocalSearchCompleter`/`AddressAutocompleteService` are v2 Phase 4 additions) — confirmed by `grep -n "MKLocalSearchCompleter\|Autocomplete" ` against `AddressSearchView.swift` at `6d3b866` returning no match.

### Bundled data — exact record counts (re-verified for this report, not trusted from prior docs)

| File | Records | Breakdown |
|---|---|---|
| `districts.geojson` | **5** | 3× Camera (Roma Centro `IT-RM-C01`, Milano Centro `IT-MI-C01`, Napoli Nord `IT-NA-C01`), 2× Senato (Torino Sud `IT-TO-S01`, Firenze Urban `IT-FI-S01`) |
| `representatives.json` | **14** | Camera 9 / Senato 5; parties: Partito Democratico ×3, Fratelli d'Italia ×2, Movimento 5 Stelle ×2, Lega ×2, Forza Italia ×2, Alleanza Verdi e Sinistra ×2, Azione - Italia Viva ×1 |
| `votes.json` | **37** | `representativeId` values `REP001`–`REP014` |

### Sample cities and sample districts

Roma (`Roma Centro`), Milano (`Milano Centro`), Napoli (`Napoli Nord`),
Torino (`Torino Sud`), Firenze (`Firenze Urban`) — one rectangular
district per city, matching the `GeocodingService` fallback table 1:1 by
city name (not coincidence — this is the mechanism the whole v1 demo flow
was built around).

### App icon / display name

`INFOPLIST_KEY_CFBundleDisplayName = Politica` (both Debug and Release
configs), set in the v1.0.0 boundary commit itself (§3, table row 3).
`icon.png` present at repo root and inside `AppIcon.appiconset/` from the
same commit. `PRODUCT_BUNDLE_IDENTIFIER = com.giuliocrp.Politici` present
since the very first commit — never changed.

### Test-target status

`PoliticiTests/PoliticiTests.swift`: one Swift Testing `@Test func
example() async throws {}` — **empty body, no assertions**.
`PoliticiUITests/PoliticiUITests.swift`: XCTest template `testExample()`
(empty) and `testLaunchPerformance()` (launch-time measurement only, no
functional assertion); `PoliticiUITestsLaunchTests.swift`: template
launch-screenshot test. **No meaningful automated coverage of any kind
existed at v1.0.0** — confirmed by reading every test file's full content
at `6d3b866`, not inferred from file names.

### README / documentation state

`README.md` at `6d3b866` (108 lines, confirmed identical to what this
report's author read before rewriting it for v2 documentation): describes
the "prototype" framing, 5 sample cities, `CLGeocoder`+fallback flow, and
closes with a "Roadmap — Prototype v2" section listing intentions (real
parliamentary data APIs, full national shapefiles, SwiftData caching, push
notifications, accessibility pass) — see §17 for which of these shipped,
shipped differently, or remain unshipped.

### Deployment target and build settings

`IPHONEOS_DEPLOYMENT_TARGET = 26.5` — confirmed present **already at the
very first commit** (`3ab4e58`), not introduced during v1 feature work.
`SWIFT_VERSION = 5.0`. This is a stock Xcode-template default (the
project was created against whatever SDK the machine had installed), not
a considered "iOS 26.5 required" decision — the app uses no API newer
than iOS 17 (`Map`/`MapPolygon`/`MapReader`, `NavigationStack`,
`ContentUnavailableView`) at either release. **Unchanged through
v2.0-prototype** (`git show v2.0-prototype:Politici.xcodeproj/project.pbxproj`
shows the same value) — this is a piece of technical debt present since
project creation, carried through both releases, never addressed in any
v2 phase (see §19).

### Known limitations (as of v1.0.0, reconstructed from evidence — v1 has no equivalent of `docs/DATA_SOURCES.md`/README "Known limitations" section to quote directly)

Entirely fictional data (all three `Data/*.json` files hand-authored, no
pipeline); 5-city-only geographic coverage; no real geocoding fallback
beyond those 5 cities; no automated test coverage; no accessibility work;
`PartyStyle` recognizes only the 7 fictional party names it was written
against. These are inferred from the shipped code/data at `6d3b866`, not
quoted from a v1-authored limitations list (none exists).

## 5. v2.0-prototype implementation snapshot

Verified via `git show v2.0-prototype:<path>` / `git ls-tree -r
--name-only v2.0-prototype`; cross-confirmed identical to the current
working tree (`git diff v2.0-prototype -- .` → 0 lines of output).

### App/ and ServiceContainer

Unchanged injection *mechanism* from v1 (§4); `ServiceContainer` now bundles
**6** services: `districtService, representativeService, voteService,
geocodingService, manifestService, partyStyleService` — `ManifestService`
and `PartyStyleService` are v2 additions (Phases 2 and 6 respectively).

### Models and schema-v2 changes

- `DataProvenance: String, Codable, Hashable` — `.sample`/`.official`,
  with a `displayName` ("Dati dimostrativi"/"Fonte ufficiale"). Every v2
  model carries a `provenance` field.
- `TolerantStringEnum` protocol (`Politici/Models/TolerantDecoding.swift`):
  `RawRepresentable where RawValue == String` + `static var unknownCase:
  Self`, with a `decodeTolerant(from:)` default implementation
  (`Self(rawValue: raw) ?? unknownCase`). The type's own doc comment
  explains *why* conformers must call `decodeTolerant` explicitly from
  their own `init(from:)` rather than relying on the protocol extension
  alone: Swift's compiler-synthesized `Decodable` for raw-value enums
  takes precedence over a protocol extension's default witness, so a bare
  `enum Foo: String, TolerantStringEnum` declaration would silently keep
  the throwing behavior.
- `District` (v2): `Coordinate`/`polygonRings` **removed**; replaced by
  `polygons: [MKPolygon]`, `provenance: DataProvenance`, `collegioType:
  CollegioType` (tolerant enum: uninominale/plurinominale/sconosciuto),
  `circoscrizione: String?`, `subCode: String?`, `sourceName: String?`.
  `boundingMapRect` computed from `polygons` (§10).
- `Representative` (v2): `districtId` is now `String?`; new fields
  `provenance`, `legislature: String?`, `electionType: ElectionType`
  (tolerant: uninominale/plurinominale/estero/sconosciuto),
  `stableSourceId: String?`, `sourceUrl: URL?`. **Stale-comment finding**:
  `Representative.swift`'s own doc comment on `districtId` still reads
  *"Nil for representatives imported from real open data whose electoral
  college hasn't been mapped to one of this app's sample districts yet"*
  — this was accurate when written (Phase 5) but is no longer accurate as
  of Phase 8 (147 uninominale deputies now have a real, linked
  `districtId`). This is a genuine, citable case of a code comment not
  being updated when a later phase changed the fact it described — noted
  here as evidence, not corrected (this report modifies nothing).
- `Vote` (v2): `VoteChoice`/`VoteResult` both gained `.sconosciuto` and
  became `TolerantStringEnum`-conforming; `Vote` itself gained
  `provenance`.

### DataProvenance behavior

Every v2 model's decoder defaults `provenance` to `.sample` when the key
is absent (`decodeIfPresent(...) ?? .sample`), confirmed for `District`
(`GeoJSONLoader.makeDistrict`) and `Representative`
(`Representative.init(from:)`) — this is what lets the old, provenance-less
`*.sample.*` fixtures keep decoding without modification even though the
field didn't exist when they were written.

### Optional fields and tolerant enum decoding

Summarized above per-model; the general mechanism is `TolerantStringEnum`
(one protocol, reused by `CollegioType`, `ElectionType`, `VoteChoice`,
`VoteResult`) — an unrecognized raw value decodes to that enum's
documented "unknown" case rather than throwing.

### Services/ — full inventory

| Service | Role |
|---|---|
| `DistrictService` | Loads `districts.geojson`; `district(for:)` now bbox-prefiltered (§10) |
| `RepresentativeService` | Loads `representatives.json`; same shape as v1 |
| `VoteService` | Loads `votes.json`; same shape as v1 |
| `GeocodingService` | `CLGeocoder` + 5-city fallback, **unchanged from v1**; conforms to `GeocodingProviding` protocol (`func geocode(address:) async throws -> CLLocationCoordinate2D`), a v2 addition enabling `AddressSearchView`'s fake-provider tests (`GeocodingProvidingTests.swift`) |
| `ManifestService` (v2) | Loads `sources.json` into `SourcesManifest`/`DataSource` |
| `PartyStyleService` (v2) | Loads `parties.json`; `color(for:)`/`shortName(for:)`, gray fallback for unmapped values |
| `AddressAutocompleteService` (v2) | Wraps `MKLocalSearchCompleter`, `.address` result type, biased to an Italy-sized region; **not** in `ServiceContainer` — owned per-screen via `@StateObject` in `AddressSearchView`, since its `suggestions` are session-scoped mutable UI state, not an app-wide data repository (per its own doc comment) |

`GeoJSONLoader` (v2): `MKGeoJSONDecoder`-based (§10). `DistrictService`,
`RepresentativeService`, `VoteService`, `ManifestService` all remain
`.shared`-singleton-backed classes injected via `ServiceContainer`, same
pattern as v1.

### Utilities/

`PointInPolygon.swift` (v2): the v1 ring-based `contains(_:in:
[CLLocationCoordinate2D])` function is **retained unchanged** as the
low-level primitive, plus two new overloads: `contains(_:in: MKPolygon)`
(exterior ring, minus any interior-ring holes) and `contains(_:inAny:
[MKPolygon])` (true if inside any part of a multi-part district) — see
§10. `Initials.swift` (v2, new): derives 2-letter initials from a name for
`InitialsAvatar`. `ColorHex.swift` (v2, new): hex-string → `Color`
parsing for `PartyStyleEntry.colorHex`. `DateFormatting.swift`:
unchanged from v1.

### Views and typed AppRoute navigation

`AppRoute` (v2, 8 cases — 3 more than v1's 5): `.map`,
`.addressSearch(initialQuery:)`, `.districtDetail(districtId:)`,
`.collegiList` (Phase 11), `.representativeList` (Phase 10),
`.representativeProfile(representativeId:)`, `.voteHistory(representativeId:)`,
`.fontiEDati` (Phase 3).

New screens beyond v1's 6: `FontiEDatiView` (Phase 3),
`RepresentativeListView` (Phase 10), `CollegiListView` (Phase 11).

### Representative list/search/filter behavior

`RepresentativeListView.swift`: `.searchable(text:)` filtering
`Representative.name` via `.folding(options: [.diacriticInsensitive,
.caseInsensitive], locale: .italian)` (same folding pattern as
`GeocodingService`'s city matching); a horizontal row of `PartyFilterChip`s
built from **distinct `shortName`s**, not raw `party` values — 12 chips
(`Set` of `PartyStyleService.shortName(for:)` applied to all 601
representatives' `party`, per `Data/parties.json`'s 19→12 shortName
mapping) rather than 19, so a Camera-sigla/Senato-full-name pair for the
same party (e.g. `"FDI"` and `"Fratelli d'Italia"`, both → `"FdI"`) filters
as one chip instead of appearing twice.

### Party styling architecture

`Politici/Models/PartyStyleEntry.swift` (`value, shortName, colorHex:
String`) + `Data/parties.json` (19 entries, one per exact `party` string
present in the shipping data — verified 1:1, zero unmapped, zero unused,
via direct comparison in this session) + `PartyStyleService` (dictionary
lookup keyed by exact `party` string, gray fallback for anything absent).
Every `colorHex` was independently re-verified in this report's authoring
session to meet ≥4.5:1 WCAG contrast against white (computed via the
standard relative-luminance formula directly from each hex string) — this
matches the `>= 4.5:1 contrast` claim already asserted in
`PartyStyleEntry.swift`'s own doc comment and enforced by
`PartyStyleServiceTests.testEveryEntryColorMeetsMinimumContrastAgainstWhite`.

### Initials avatars

`InitialsAvatar` (`Politici/Views/DistrictDetailView.swift`, alongside
`RepresentativeRow`): a `Circle` filled with the representative's party
color, overlaid with `Initials.from(name)` text — 2 letters (first+last
name-token initial) derived purely from the `Representative.name` string,
no image asset, no network fetch. Used in `RepresentativeRow` (52pt) and
`RepresentativeProfileView`'s header (96pt); marked
`.accessibilityHidden(true)` at every call site as of Phase 11, since the
row/header's real name text already conveys identity to VoiceOver (§15).

### Attribution screen

`FontiEDatiView.swift`: renders `ManifestService`'s `sources.json` entries
live as `SourceCard`s (name, license, "Dati aggiornati al: …", conditional
"Apri la fonte" link), an unofficial-status disclaimer paragraph, three
`BulletRow` avvertenza bullets, and a licenze note. Exact strings and
source-by-source detail in §16.

### Electoral-system explainer

`HomeView`'s `comeFunzionaSection`: a `DisclosureGroup("Come funziona
l'elezione")` with 3 `BulletRow`s stating — verbatim in the app — that
147 Camera deputies are uninominale-elected and mapped to a real collegio;
other Camera deputies (plurinominale/estero) are listed but not mapped to
geography; Senato senators are listed but Senato collegio boundaries
aren't included in this prototype. Added in Phase 10 (`8a1aa90`).

### Accessible map alternative

`CollegiListView.swift` (Phase 11, `a084f3d`): `.searchable` list of all
147 shipping districts (`DistrictService.allDistricts()`, sorted by
name), search matching name or `circoscrizione` via the same
diacritic/case-insensitive folding pattern used elsewhere, each row
(`CollegioRow`) showing the collegio name and circoscrizione, tapping
navigates to the same `.districtDetail(districtId:)` route `MapView`'s
tap gesture already used. Entry points: a `.toolbar` button ("Sfoglia
come elenco") added to `MapView` (which had no toolbar at all before this
phase — confirmed via `git show a084f3d -- Politici/Views/MapView.swift`),
and `HomeView`'s "Collegi campione" stat card made tappable to the same
destination.

### VoiceOver and Dynamic Type changes

Full detail in §15; summary: `VoteBadge` gained an SF Symbol + a distinct
Italian `accessibilityLabel` per `VoteChoice` case (moved onto `VoteChoice`
itself as `symbolName`/`accessibilityLabel` computed properties, in
`Politici/Models/Vote.swift`, for testability — confirmed via
`PoliticiTests/VoteChoiceAccessibilityTests.swift`); rows/headers with no
nested interactive controls combined via `.accessibilityElement(children:
.combine)`; the one `minimumScaleFactor` usage (`InitialsAvatar`) resolved
by hiding the avatar from accessibility rather than by removing the scale
factor (the real name text elsewhere in the same row/header is never
scaled); five under-44pt custom controls given `.frame(minHeight:
44).contentShape(Rectangle())`.

### Generated Data/ files and sample-fixture conventions

`districts.geojson`, `representatives.json`, `votes.json`, `parties.json`,
`sources.json` are pipeline-generated (§9); `districts.sample.geojson`
(5 features), `representatives.sample.json` (14 records), and
`votes.sample.json` (37 records) preserve the original v1.0.0 fictional
content byte-for-byte in record count (re-verified in this session — §8)
for test-only use, loaded by explicit resource name
(`DistrictService(resource: "districts.sample")`, etc.), never the
default resource any shipping view/service reads.

### Test architecture and current test inventory

Full detail in §14.

## 6. Phase-by-phase v2 history

Each phase below cites its commit and, where one exists, its
`docs/v2/*.md` report — the primary source for "what was found," not just
"what shipped."

- **Phase 0 — Audit** (`b0b6c77`): baseline repo audit, `docs/v2/00-audit.md`, `v2` branch created, `CLAUDE.md` v1.
- **Phase 1 — Test bootstrap** (`bdff254`): first real `PoliticiTests` coverage (geometry/decoding/service lookups).
- **Phase 2 — Schema v2** (`d9a922f`): `DataProvenance`, `TolerantStringEnum`, `SourcesManifest` infrastructure — built *before* any real data existed, so later phases had somewhere to record provenance from day one.
- **Phase 3 — Attribution screen** (`e6e5ffe`): `FontiEDatiView` wired before there was anything real to attribute.
- **Phase 4 — Address autocomplete** (`b92ffd8`): `MKLocalSearchCompleter` layered over the existing `GeocodingProviding` seam.
- **Phase 5 — Real representative import** (`f01dd15`, `f6867eb`): the `tools/` SPARQL pipeline is built and `representatives.json` becomes 601 real records; `districts.geojson`/`votes.json` remain fictional at this point. `docs/v2/01-real-data-import.md` documents the judgment calls (party=sigla vs. full name, no photo URLs used, senators with an ended mandate excluded, `districtId`→optional).
- **Phase 6 — Post-import reconciliation** (`8b16be1`): `docs/v2/02-post-import-audit.md` — fixes gaps Phase 5 left (empty valid `votes.json`, real `PartyStyleService`, boundary-honesty disclosure, fetch-script retry/backoff, `stableSourceId` given real meaning). Verifies the Senato 201-count semantics explicitly (§11).
- **Phase 7 — ISTAT boundaries** (`9841fea`): `docs/v2/03-boundaries-audit.md` — 147 real Camera collegi uninominali; the `MKGeoJSONDecoder`/`MKMultiPolygon` decoding-gap discovery and fix (§10, §18).
- **Phase 8 — Deputy-to-collegio linkage** (`2820bec`): `docs/v2/03-linkage-report.md` — `region`→`circoscrizione`/`subCode` correction, the `?collegio`-wrong-granularity discovery, 147/147 structural linkage (§11, §18).
- **Phase 9 — Curated votes import** (`6625944`): `docs/v2/04-votes-import.md` — secret-ballot exclusion, atto-label title cleaning, 25→12 budget reduction (§12, §18).
- **Phase 10 — UI completion** (`8a1aa90`): `RepresentativeListView` (discovered missing — no `docs/v2/*.md` report for this phase; evidence is the commit itself and this report's own prior-session narrative, category 3), party styling audited and found already complete from Phase 6, initials avatars, explainer copy.
- **Phase 11 — Accessibility** (`a084f3d`): `docs/v2/a11y-checklist.md` — `MapView`'s total lack of VoiceOver support discovered, `CollegiListView` built as the alternative; non-color-only vote badges; Dynamic Type/hit-target work.
- **Documentation phase** (`72448dc`): this repository's `README.md`/`CHANGELOG.md`/`docs/DATA_SOURCES.md`/`CLAUDE.md` brought to the state this report itself relies on as tier-3 evidence.

**Note on Phase 10's missing design-note report**: every other v2 phase
from 5 onward has a corresponding `docs/v2/NN-*.md` file; Phase 10 (UI
completion) does not. This is a **verified-from-git absence**, not an
assumption — `git ls-tree -r --name-only v2.0-prototype -- docs/v2` lists
exactly 7 files (`00-audit.md`, `01-real-data-import.md`,
`02-post-import-audit.md`, `03-boundaries-audit.md`,
`03-linkage-report.md`, `04-votes-import.md`, `a11y-checklist.md`), none
scoped to Phase 10. Everything this report states about Phase 10 beyond
the commit's own diff is therefore category-3 evidence (this session's own
prior-turn narrative), not category-2.

## 7. Architecture evolution

### v1 vs v2 product capability

| | v1.0.0 | v2.0-prototype |
|---|---|---|
| Districts shown | 5 fictional rectangles | 147 real ISTAT Camera collegi uninominali |
| Representatives | 14 fictional | 601 real (400 Camera + 201 Senato) |
| Deputy↔collegio linkage | N/A (fictional, hand-assigned) | 147/147 real, SPARQL-derived |
| Votes | 37 fictional | 4,788 real per-deputy positions across 12 real vote events |
| Representative browsing | 4-item Home preview only | Full searchable, party-filterable list (601) |
| Map alternative | None | `CollegiListView` |
| Attribution | None | `FontiEDatiView` |
| Electoral-system explainer | None | "Come funziona l'elezione" |
| Accessibility | None | Non-color vote badges, VoiceOver labels, Dynamic Type, hit targets |

### v1 vs v2 data sources

| | v1.0.0 | v2.0-prototype |
|---|---|---|
| Districts | Hand-authored | ISTAT shapefile (D.Lgs. 177/2020), CC BY 4.0 |
| Representatives | Hand-authored | dati.camera.it + dati.senato.it SPARQL, CC BY 4.0 / CC BY 3.0 |
| Votes | Hand-authored | dati.camera.it SPARQL, CC BY 4.0 |
| Provenance tracking | None | Every record: `.official` or `.sample` |

### v1 vs v2 data model

| | v1.0.0 | v2.0-prototype |
|---|---|---|
| `District` geometry | `[[Coordinate]]` rings, hand-decoded | `[MKPolygon]` via `MKGeoJSONDecoder` |
| `Representative.districtId` | `String` (non-optional) | `String?` |
| Enum decoding | Throwing (`Codable`) | Tolerant (`TolerantStringEnum`, unknown→explicit case) |
| Provenance | None | `DataProvenance` on every model |

### v1 vs v2 geometry

| | v1.0.0 | v2.0-prototype |
|---|---|---|
| Geometry type | `Polygon` only, exterior ring only | `Polygon` + `MultiPolygon`, interior holes |
| Decoder | Hand-rolled `Decodable` | `MKGeoJSONDecoder` |
| Point-in-polygon prefilter | None (linear scan) | Bounding-box prefilter (`MKMapRect.contains`) before ray-casting |
| Multi-part districts | Not possible | 56 of 147 real collegi are genuinely `MultiPolygon` |

### v1 vs v2 testing

| | v1.0.0 | v2.0-prototype |
|---|---|---|
| `PoliticiTests` | 1 empty template test | ~92 real test methods across 11 files (§14) |
| `PoliticiUITests` | Template only | Template only, **unchanged** |
| Referential-integrity tests | None | Multiple, with a documented weaken→vacuous→genuine episode (§18) |

### v1 vs v2 accessibility

| | v1.0.0 | v2.0-prototype |
|---|---|---|
| VoiceOver labels | None found | Present across all interactive flows (Phase 11) |
| Non-color vote indicators | N/A (no accessibility work) | Icon + text + distinct label per `VoteChoice` |
| Map VoiceOver path | None; not identified as a gap | Identified as the single biggest gap; `CollegiListView` built as the fix |
| Dynamic Type | Not audited | Audited; one `minimumScaleFactor` usage resolved |

### v1 vs v2 legal/provenance handling

| | v1.0.0 | v2.0-prototype |
|---|---|---|
| Attribution screen | None | `FontiEDatiView`, manifest-driven |
| Unofficial-status disclaimer | README only | README **and** in-app `FontiEDatiView` text |
| Source manifest | None | `Data/sources.json`, 5 entries, cross-checked against `docs/DATA_SOURCES.md` |
| Snapshot/staleness warning | Implicit ("prototype") | Explicit in-app bullet + documented `retrievedAt` dates |

### v1 vs v2 operational workflow

| | v1.0.0 | v2.0-prototype |
|---|---|---|
| Data regeneration | Hand-edit JSON directly | `make fetch && make all` pipeline, hand-editing `Data/*` explicitly forbidden by `CLAUDE.md` |
| Network access | None anywhere in the repo | `tools/fetch_*.py` only (developer-side); app runtime still fully offline |
| Validation | None | `make validate` — structural + referential-integrity checks, exits non-zero on violation |

## 8. Data model and bundled-data evolution

### v1.0.0 counts (re-verified this session, §4)

districts 5, representatives 14 (Camera 9 / Senato 5), votes 37.

### v2.0-prototype counts (re-verified this session via `git show
v2.0-prototype:Politici/Data/*.json` piped to Python)

| Metric | Value |
|---|---|
| District feature count | 147 (all Camera; 56 MultiPolygon, 91 Polygon) |
| Representatives by chamber | Camera 400, Senato 201 (total 601) |
| Representatives with non-null `districtId` | 147 |
| Camera representatives by `electionType` | uninominale 147, plurinominale 245, estero 8 |
| Distinct `party` values | 19 |
| Distinct `parliamentaryGroup` values | 19 |
| Unique party short-name count (`Data/parties.json`) | 12 (from 19 `party`-string entries) |
| Vote-position records (`votes.json` length) | 4,788 |
| Unique parliamentary vote events (distinct `sourceUrl`) | **12** |
| `vote` (VoteChoice) breakdown | Contrario 2,938 / Assente 980 / Favorevole 836 / Astenuto 34 |
| `result` (VoteResult) breakdown | Respinto 4,788 (all 12 imported votes were rejected) |
| Representative/vote `provenance` | 100% `.official` (601/601, 4,788/4,788) |
| `sources.json` entries | 5 |
| `sources.json.schemaVersion` | 2 |
| `*.sample.*` fixture counts | districts 5, representatives 14, votes 37 (byte-identical record counts to v1.0.0) |
| File sizes (blob bytes, exact) | `districts.geojson` 1,158,457 B (~1.10 MB); `representatives.json` 439,399 B (~429 KB); `votes.json` 1,878,366 B (~1.79 MB) |

### 12 vote events vs. 4,788 Vote records — the distinction, explicitly

**12** is the count of distinct real Camera **parliamentary roll-call
votes** (parliamentary motions/articles actually voted on by the
Assemblea) — identified in `votes.json` by 12 distinct `sourceUrl` values,
each a real link to that vote's official "scheda votazione" page on
`documenti.camera.it`. **4,788** is the count of individual `Vote` model
**records**, i.e. one record per (vote event × deputy who had a recorded
position on it) — the app's `Vote` schema is a per-deputy-per-vote row, not
a per-motion row. 4,788 ÷ 12 ≈ 399 positions per vote event, consistent
with each of the 12 votes recording a position (favorevole, contrario,
astenuto, or assente/non-ha-votato) for very nearly all 400 sitting
Camera deputies. **It would be incorrect to describe this dataset as
"4,788 separate parliamentary motions"** — it is 12 motions, each
represented by roughly 399 individual deputy-position rows.

## 9. Developer pipeline

Source: `Makefile` and `tools/*.py`/`tools/*.sh`/`tools/queries/*.rq` at
`v2.0-prototype`.

### Makefile targets (exact, from `git show v2.0-prototype:Makefile`)

```
.PHONY: fetch import validate manifest boundaries all

fetch:      tools/fetch_camera.py, tools/fetch_senato.py, tools/fetch_camera_votes.py
import:     tools/import_representatives.py, tools/import_votes.py
validate:   tools/validate_data.py
manifest:   tools/make_manifest.py
boundaries: tools/build_boundaries.sh
all:        fetch import validate manifest boundaries
```

**Network-requiring targets**: `fetch` only (its own comment: "Requires
network access. Writes only under tools/raw/."). **Offline targets**:
`import`, `validate`, `manifest`, `boundaries` (the last processes an
already-downloaded local shapefile under `tools/raw/collegi/` — it does
not fetch the shapefile itself; the shapefile's own acquisition is
undocumented in any committed script, consistent with the task's
prohibition on inspecting `tools/raw/` contents in this audit).

### Script responsibilities (function/constant names cited, not full source)

- **`fetch_camera.py`**: runs `tools/queries/camera_deputati.rq` against
  `https://dati.camera.it/sparql`, writes
  `tools/raw/camera_deputati_sparql.json`.
- **`fetch_senato.py`**: three separate queries
  (`senato_senatori.rq`/`senato_gruppi.rq`/`senato_commissioni.rq`)
  against `https://dati.senato.it/sparql`, merged locally by senator URI.
- **`fetch_camera_votes.py`**: `camera_votazioni_scope.rq` (candidate
  selection) then `camera_votazioni_dettaglio.rq` (full detail for the
  chosen votes), against the same Camera endpoint.
- **`import_representatives.py`**: merges the Camera/Senato raw caches
  into `Data/representatives.json`; owns the collegio-linkage logic (§11) —
  key symbols `normalize_circoscrizione`, `load_uninominale_index`,
  `UNINOMINALE_TIPO_ELEZIONE = {"maggioritario", "maggioritario suppletiva"}`,
  `ESTERO_COVERAGE_VALUES`, `MIN_LINKED_COLLEGI = 133` (90% of 147 — the
  quality-gate threshold, §11).
- **`build_boundaries.sh`**: `ogr2ogr` reprojection/simplification of the
  local ISTAT shapefile, then hands off to `import_boundaries.py` for the
  schema-v2 property transform (§10).
- **`import_votes.py`**: merges the votes raw cache into
  `Data/votes.json`; key symbols `RAW_VOTE_CHOICE` (raw-vocabulary→enum
  map), `ATTO_LABEL_ARTIFACT_RE` (title-cleaning regex), `MAX_OUTPUT_BYTES
  = 2 * 1024 * 1024`, budget logic reading `maxPositionRecords` from
  `tools/config/votes_scope.json` (§12).
- **`make_manifest.py`**: regenerates `Data/sources.json`; key functions
  `retrieved_at`, `load_fetch_metadata`, `votazioni_scope_note` (computes
  the votes source's descriptive note from the *actual* imported vote
  count, not the config's nominal target — §12), `real_sources`.
- **`validate_data.py`**: structural + referential-integrity checks;
  `EXPECTED_CAMERA_REPRESENTATIVE_COUNT = 400`,
  `EXPECTED_SENATO_REPRESENTATIVE_COUNT = 201`,
  `EXPECTED_DISTRICT_COUNT = 147`, `MAX_DISTRICTS_FILE_BYTES = 3MB`,
  `MAX_VOTES_FILE_BYTES = 2MB`, functions `validate_representatives`,
  `validate_districts`, `validate_linkage`, `validate_votes`,
  `validate_votes_reference_representatives`.

### `tools/raw/` gitignore policy

`.gitignore` (v2.0-prototype) includes `tools/raw/` explicitly (added in
commit `f01dd15`) plus generic `__pycache__/`/`*.pyc` patterns — confirmed
via `git status --porcelain --ignored` showing `tools/raw/` and
`tools/__pycache__/` both as ignored (`!!`), not tracked. This report did
not open or reproduce any file under that path, per the task's hard
constraint.

### Deterministic-output / fail-without-partial-write behavior

Every import script computes its full output in memory, validates it
(size budget, id uniqueness, referential integrity), and only then writes
— on any failure it prints a diagnostic and exits non-zero **without**
writing a partial file. Confirmed by symbol inspection: `import_votes.py`
computes `serialized_bytes` and checks `len(serialized_bytes) >
MAX_OUTPUT_BYTES` *before* the `DATA_DIR.mkdir`/`OUTPUT_PATH.write_bytes`
calls; `import_representatives.py`'s `MIN_LINKED_COLLEGI` gate is checked
before its own write step.

### Refresh command sequence (verified against the current `Makefile`, not inferred from old docs)

`make fetch && make all` — where `make all` = `fetch import validate
manifest boundaries` (so `fetch` effectively runs twice in that
shorthand; the `Makefile`'s own `all` target already includes it). This
matches what `README.md` (`72448dc`) documents, cross-checked here
directly against the `Makefile` rather than trusted from the README
alone.

### Query pinning, User-Agent, timeout, retry/backoff

`tools/sparql_client.py`: every query lives in a versioned `tools/queries/*.rq`
file (`load_query` strips `#`-prefixed header comments, never an inline
Python string). `USER_AGENT = "PoliticaApp-DataPipeline/1.0
(tools/fetch_*.py; civic-tech prototype, non-commercial)"` — a descriptive,
honest identifier, not a spoofed browser UA (the module's own comment
notes this was specifically necessary for `dati.senato.it`, which
rejected the bare default `Python-urllib` UA). `TIMEOUT_SECONDS = 60`,
`MAX_ATTEMPTS = 3`, `INITIAL_BACKOFF_SECONDS = 2` (exponential). 4xx HTTP
errors are never retried (`fetch_sparql`'s own comment: "a client/query
error won't fix itself"); 5xx and network-level errors get up to
`MAX_ATTEMPTS` with exponential backoff.

## 10. Geospatial engine

- **Source shapefile/layer**: `CAMERA_CollegiUNINOMINALI_2020` (Camera
  collegi uninominali layer, D.Lgs. 177/2020) — per
  `docs/v2/03-boundaries-audit.md` and `tools/build_boundaries.sh`.
- **Original CRS**: EPSG:32632 (WGS 84 / UTM zone 32N). **App output
  CRS**: EPSG:4326 (WGS 84 lat/lon), via `ogr2ogr -t_srs EPSG:4326`.
- **Original shapefile field names** (per `docs/v2/03-boundaries-audit.md`'s
  own `ogrinfo` schema dump, cited there as directly verified, not
  assumed): `OBJECTID`, `CU20_COD`, `CU20_DEN`, `CU20_C1`, `Shape_Leng`,
  `Shape_Area`, `POP_2011`.
- **Transformation/simplification**: `ogr2ogr` reprojection +
  `-simplify` at a 1000m Douglas-Peucker tolerance (per
  `tools/build_boundaries.sh`'s own comment, calibrated to preserve every
  genuine multi-part island geometry while staying under the bundle
  budget).
- **Output size/feature count**: 147 features, 1,158,457 bytes
  (~1.10 MB, re-measured this session directly from the git blob), well
  under `import_boundaries.py`'s own `MAX_OUTPUT_BYTES = 3MB` gate. 56 of
  147 (~38%) are `MultiPolygon` (re-counted this session).
- **MultiPolygon and interior-hole support**: `District.polygons:
  [MKPolygon]`; `PointInPolygon.contains(_:in: MKPolygon)` excludes a
  point that falls inside any `interiorPolygons` hole even if inside the
  exterior ring; `contains(_:inAny:)` tests every part of a multi-part
  district.
- **Bounding-box prefilter**: `DistrictService.district(for:)` — `let
  candidates = districts.filter { $0.boundingMapRect.contains(point) }`,
  then exact ray-casting only on `candidates`. The function's own comment
  states the motivation directly: real ISTAT districts (some with dozens
  of MultiPolygon parts) are "far more expensive to ray-cast than the old
  5 sample rectangles."
- **`MKGeoJSONDecoder` behavior and how `MKMultiPolygon` was handled**:
  `GeoJSONLoader.makeDistrict`'s own comment states the finding precisely:
  *"MKGeoJSONDecoder represents a GeoJSON 'Polygon' geometry as a single
  MKPolygon, but a 'MultiPolygon' as one MKMultiPolygon wrapping its
  parts — NOT as multiple MKPolygon entries directly in
  feature.geometry."* The fix (`feature.geometry.flatMap { ... if let
  multiPolygon = shape as? MKMultiPolygon { return multiPolygon.polygons
  } ... }`) is present in the shipped code. **The specific diagnostic
  process that led to this finding** (reportedly: a failing test,
  standalone `swiftc`-compiled probe scripts confirming the decoder's
  actual runtime type, then the fix) **is not itself preserved in the
  repository** — the probe scripts were scratch files, never committed.
  This report treats the *finding* (visible directly in the shipped code
  comment) as category 1/2 evidence, and the *diagnostic method narrative*
  as category 3 (this session's own prior-turn account, not independently
  re-verifiable from the repo).
- **Sample fixture preservation**: `districts.sample.geojson` (5
  features, byte-count-verified this session) — `import_boundaries.py`
  backs up the previous `districts.geojson` to this path only if the
  backup doesn't already exist, so it's a one-time preservation, not a
  repeated overwrite.
- **Corrected properties** — `id` (`CU20_COD`, cast to string), `name`
  (`CU20_DEN`, unmodified), `chamber` (`"Camera"` literal — capitalized to
  match the Swift `Chamber` enum's raw value exactly; the source pipeline
  brief this was built from reportedly specified lowercase `"camera"`,
  which would have failed to decode against the non-tolerant `Chamber`
  enum — category 3 evidence for the brief's original wording, category 1
  for the shipped capitalized value and the reason it matters),
  `collegioType` (`"uninominale"` literal), `circoscrizione` (derived —
  see below), `subCode` (`CU20_C1`), `provenance` (`"official"`),
  `sourceName` (`"ISTAT"`).
- **Why the old `region` property was incorrect**: `docs/v2/03-linkage-report.md`
  states directly that `CU20_DEN`'s tail after `" - "` (e.g. `"U01"`) —
  what an earlier phase had stored under a property literally named
  `region` — is a **within-circoscrizione uninominale sub-collegio
  suffix**, not a geographic region in any sense; the doc further states
  this was verified, not assumed, against all 147 rows with zero
  exceptions, and cross-checked against the official 28-circoscrizione
  list from D.Lgs. 177/2020. The correction: `circoscrizione` = the
  `CU20_DEN` prefix before `" - {subCode}"` (the *true* circoscrizione,
  e.g. `"Piemonte 1"`); `subCode` = the former `region` value, honestly
  renamed to what it actually is.
- **Address-to-collegio resolution flow**: unchanged in outline from v1
  (`GeocodingService`/`AddressAutocompleteService` → coordinate →
  `DistrictService.district(for:)`), but now resolving against 147 real
  `MKPolygon`/`MKMultiPolygon` collegi with bbox prefiltering instead of 5
  fictional rectangles with a linear scan.

## 11. Representative import and linkage

- **Endpoints**: Camera `https://dati.camera.it/sparql`, Senato
  `https://dati.senato.it/sparql`.
- **Queries per source**: Camera 1 (`camera_deputati.rq`); Senato 3
  (`senato_senatori.rq`, `senato_gruppi.rq`, `senato_commissioni.rq`,
  merged locally by senator URI — per `fetch_senato.py`'s responsibilities,
  §9).
- **Cached-response strategy**: `tools/raw/*_sparql.json`, gitignored,
  regenerated only by `make fetch`; `import_representatives.py` never
  touches the network itself and fails loudly if the cache is missing.
- **Source URI / stable ID handling**: each person's SPARQL entity URI's
  bare numeric segment becomes `Representative.stableSourceId` (e.g.
  `.../persona.rdf/p307394` → id-with-prefix `p307394`, `stableSourceId`
  `"307394"`) — this is the same numeric id later reused directly as the
  join key for vote-position linkage (§12), since `ocd:rif_deputato`
  URIs in the votes graph use the identical numeric scheme.
- **Current-mandate filtering / ended-mandate exclusions**: Camera query
  filters via a `MINUS` on ended group memberships; Senato records are
  included only when no `fineMandato` (mandate end date) is bound —
  `docs/v2/02-post-import-audit.md` states this was verified directly
  against the raw SPARQL cache (not assumed), finding 201 active (196
  elected + 5 active life senators appointed under Art. 59) vs. 7 ended
  (4 deceased, 2 resigned, 1 former President — Giorgio Napolitano, a
  life senator by right, correctly excluded because his `fineMandato` is
  bound, dated to his 2023 death).
- **Party/group/committee aggregation**: `party` = Camera sigla (e.g.
  `"FDI"`) or Senato full group name (Senato's `gruppi` query has no
  sigla field at all); `parliamentaryGroup` = the raw group name,
  preserved including a known source truncation-at-`"("` quirk
  (Camera's `nomeGruppo` literal), not reconstructed.
- **Why `districtId` became optional**: the acquisition brief this phase
  worked from reportedly required emitting `districtId: null` for every
  real record at the time (category 3); decoding `null` into a
  non-optional `Swift.String` would throw and discard the *entire* array
  on load, not just the new records — so `String?` was the one required
  model change (category 1, confirmed present in `Representative.swift`).
- **Camera election-type derivation** and **why the original `?collegio`
  value was wrong for uninominale linkage**: the pre-existing SPARQL
  variable `?collegio` (bound via `dc:coverage` on the election resource)
  turned out to identify only the **plurinominale** collegio (e.g.
  `"SICILIA 1 - P01"`) — the same granularity for both majoritarian and
  proportional winners, and a plurinominale collegio can contain 1–11
  uninominale collegi, so `?collegio` alone cannot identify which specific
  one a majoritarian winner represents. `docs/v2/03-linkage-report.md`
  documents this as found via **live SPARQL introspection** (an
  `ocd:tipoElezione`/`dcterms:spatial` predicate discovery), not assumed
  from the query's variable name.
- **The actual `dcterms:spatial`/`tipoElezione` linkage path**:
  `?el ocd:tipoElezione ?tipo` classifies each mandate
  (`"maggioritario"`/`"maggioritario suppletiva"`/`"proporzionale"`);
  `?el dcterms:spatial ?collegioUninominale` is present **only** for
  majoritarian(-suppletiva) mandates and gives the exact uninominale
  collegio as `"{CIRCOSCRIZIONE} - U0N"` — structurally identical to
  `districts.geojson`'s `circoscrizione`+`subCode` pair once normalized.
- **Normalized structural matching**: `normalize_circoscrizione`
  (uppercase, strip accents/punctuation, split on `"/"` to take the
  Italian-only segment before comparing) joins on `(circoscrizione_norm,
  subCode)`.
- **Valle d'Aosta handling**: the linkage report documents one genuine
  normalization wrinkle — `districts.geojson`'s circoscrizione for Valle
  d'Aosta is the ISTAT bilingual official name
  `"Valle d'aosta/Vallée d'Aoste"`, while the SPARQL side gives the
  Italian-only `"VALLE D'AOSTA - U01"`; the `"/"`-split normalization
  resolves this, and the doc notes there was no real ambiguity anyway
  since Valle d'Aosta has exactly one uninominale collegio on both sides.
- **147/147 outcome**: `docs/v2/03-linkage-report.md` states this was a
  **complete, exact bijection**, verified before being written into
  `import_representatives.py` — 147 shapefile keys, 147 SPARQL keys, 147
  matched, 0 unmatched in either direction. Rung (c) (normalized-
  denomination fallback) was implemented but never reached.
- **By-election and vacancy findings**: 145 ordinary `"maggioritario"` +
  2 `"maggioritario suppletiva"` (by-election) = 147, **0 vacancies**. The
  two by-election holders are named directly in the report: Giulio
  Centenaro (collegio `50202`, Veneto 2 - U02) and Alberto Di Rubba
  (collegio `50201`, Veneto 2 - U01).
- **Quality-gate behavior**: `MIN_LINKED_COLLEGI = 133` (90% of 147) is
  enforced in `import_representatives.py` — if a future re-fetch links
  fewer than 133, the script fails loudly and writes nothing, rather than
  silently shipping a partially-linked file.

## 12. Votes import

- **How the Camera vote ontology was explored**: `docs/v2/04-votes-import.md`
  documents live SPARQL introspection of `ocd:votazione` and its
  per-deputy `ocd:voto` entities, discovering the vote-level `dc:title` is
  a **generic procedural template** (e.g. `"Votazione Articolo 6 "`,
  `"Votazione finale "`) — confirmed across every sample checked, never
  the actual bill/motion text — and that the *real* subject lives on the
  associated `atto`'s `rdfs:label` instead (`?el ocd:rif_attoCamera ?atto
  . ?atto rdfs:label ?attoLabel`).
- **Secret-ballot exclusion and why positions are unavailable**: votes
  with `ocd:votazioneSegreta 1` do have per-deputy `ocd:voto` records, but
  every one carries only the generic `dc:type "Ha votato"` ("voted") —
  the doc reports a live sample distribution of `{"Ha votato": 286,
  "Astensione": 5, "Non ha votato": 108}` for one such vote, i.e. **no**
  `Favorevole`/`Contrario` value ever appears for a secret vote. This
  confirms ballot secrecy is enforced at the data-publication level, not
  merely a scope choice — including these votes would misrepresent
  inherent unattributability as "unknown by omission."
- **Generic procedural coverage vs. atto label text**: covered above —
  `dc:title`/`rdfs:label` on the votazione itself never carries the real
  subject; `?attoLabel` does, when an atto exists (not every votazione has
  one — e.g. organizational votes).
- **Title-cleaning behavior**: `clean_atto_label` (in `import_votes.py`)
  strips a literal trailing `^^https?://...` artifact (a source-data
  quirk where an XSD-datatype URI leaked into the label *string value*
  itself, not proper RDF typing) via `ATTO_LABEL_ARTIFACT_RE`, then
  applies `html.unescape` (the source data contains raw HTML entities like
  `&agrave;`). `build_title` combines the procedural `dc:title` with the
  cleaned atto label when present (`"{procedural} — {substantive}"`),
  else falls back to the trimmed procedural text alone.
- **Scope/budget controls**: `tools/config/votes_scope.json` — `"mode":
  "recent"`, `"n": 25`, `"maxVotes": 25`, `"maxPositionRecords": 5000`.
  `import_votes.py` processes candidate votes newest-first and **stops at
  the first vote that would push the cumulative position count over
  `maxPositionRecords`**, rather than skipping ahead to a smaller/older
  vote to fit more in — the doc states this preserves "the most recent K
  that fit" as a simple, explicable, reproducible set rather than a
  bin-packed selection.
- **Why 12 shipped instead of the nominal 25**: at ~399 positions per
  vote, the naive 25-vote scope would produce ~9,975 records
  (~4.6 MB) — over budget. `maxPositionRecords` was first set to 6,000
  (produced 2.20 MB — still over the ~2MB target) then tuned to 5,000
  after measuring real output, landing at 12 votes / 4,788 records /
  1,834 KB (1.79 MB) — the doc reports `import_votes.py`'s own console
  output verbatim: `"OK: 4788 posizioni (12 votazioni) scritte ... (1834
  KB)"` / `"votazioni incluse: 12/25 candidate (maxVotes=25,
  maxPositionRecords=5000)"`.
- **Referential-integrity enforcement**: `import_votes.py` checks every
  `representativeId` resolves against `representatives.json` **before**
  writing; `validate_data.py`'s `validate_votes_reference_representatives`
  independently re-checks the same invariant from the already-written
  files, from scratch — the report states this dual enforcement produced
  "OK: integrità referenziale voti coerente — 4788 posizioni, 399
  rappresentanti coinvolti" (399 of 400 Camera deputies appear in at
  least one imported vote).
- **Empty-state behavior**: the doc identifies the one Camera deputy with
  zero imported positions — Lorenzo Fontana (`p307591`), President of the
  Chamber of Deputies, who by parliamentary custom doesn't participate in
  ordinary roll calls — as a deliberate manual check of the pre-existing
  Phase-6 empty-state copy (`RepresentativeProfileView`/`VoteHistoryView`'s
  "Nessuna votazione disponibile in questa versione del prototipo."), not
  a new string.
- **Manually verified examples recorded in docs**: `docs/v2/04-votes-import.md`
  records a direct comparison of two deputies' recorded positions on one
  imported vote (`sourceUrl` ending `RifVotazione=690_76`) against the
  official Camera page's own text: Tommaso Foti (recorded `Contrario`,
  official page `Contrario`), Davide Bergamini (recorded `Favorevole`,
  official page `Favorevole`) — both matching exactly, per the doc.
  **This specific cross-check against the live external Camera website is
  category 3 evidence** (it required a live web fetch at the time it was
  performed, which this audit's own hard constraints do not permit
  repeating) — the *result* is recorded in committed documentation
  (category 2), but this report cannot independently re-verify the live
  page content itself.

## 13. UI and navigation evolution

Covered in detail across §4–§6; summary of the navigation graph's growth:

| Release | `AppRoute` case count | New screens this release |
|---|---|---|
| v1.0.0 | 5 | `HomeView`, `MapView`, `AddressSearchView`, `DistrictDetailView`, `RepresentativeProfileView`, `VoteHistoryView` |
| v2.0-prototype | 8 (+3) | `FontiEDatiView` (Phase 3), `RepresentativeListView` (Phase 10), `CollegiListView` (Phase 11) |

Home's own surface grew across v2 without a route change: the "Come
funziona l'elezione" `DisclosureGroup` (Phase 10), the "Vedi tutti" link
and tappable "Collegi campione" stat card routing to the two new list
views (Phases 10–11), and the info-circle toolbar button routing to
`.fontiEDati` (Phase 3) are all additions to the existing `HomeView`
rather than new routes.

## 14. Testing and QA evolution

- **v1 verification approach**: no automated coverage (§4). Per
  `docs/v2/00-audit.md` (committed, category 2): "All verification to date
  has been manual: standalone compiled decode/logic harnesses run outside
  the test target, plus `xcodebuild` build checks and simulator
  screenshots."
- **v1 automated tests**: `PoliticiTests.swift`'s single empty `@Test func
  example()` and `PoliticiUITests`' template methods — **not meaningful
  coverage of anything**, confirmed by reading their full bodies (§4).
- **v2 test-target bootstrap**: commit `bdff254` — first tests exercising
  actual app code.
- **Current test inventory** (`PoliticiTests/`, 11 files, counted this
  session by grepping `^\s*func test[A-Za-z0-9_]*\(` plus `@Test` per
  file against `v2.0-prototype`):

| File | Test methods |
|---|---|
| `DateFormattingTests.swift` | 5 |
| `DecodingTests.swift` | 9 |
| `DistrictBoundariesTests.swift` | 8 |
| `GeocodingProvidingTests.swift` | 7 |
| `InitialsTests.swift` | 8 |
| `PartyStyleServiceTests.swift` | 6 |
| `PointInPolygonTests.swift` | 7 |
| `PoliticiTests.swift` | 1 (`@Test`, Swift Testing) |
| `SchemaV2Tests.swift` | 23 |
| `ServiceLookupTests.swift` | 11 |
| `VoteChoiceAccessibilityTests.swift` | 6 |
| **`PoliticiTests` total** | **91 XCTest-style + 1 Swift Testing = 92** |
| `PoliticiUITests.swift` | 2 (template) |
| `PoliticiUITestsLaunchTests.swift` | 1 (template) |

This static count (92 in `PoliticiTests`, 95 across both targets) is
**category 1 — verified from source**, computed directly against the
`v2.0-prototype` tag in this session. It does not exactly match the pass
counts this report's author personally observed from actual `xcodebuild
test` runs earlier in this same session (96–97 passed, 0 failed, across
several runs at or very near this same commit) — that discrepancy of a
handful of tests is **category 4 evidence** (a first-hand but not fully
reconciled observation) and is reported as an open discrepancy rather
than silently resolved in either direction; a plausible but unconfirmed
explanation is XCTest's own reporting counting something the static
`grep` doesn't (e.g. a measure-based performance test emitting more than
one "Test Case" log line) — **Non verificabile dal repository** further
without re-running the suite, which this audit's scope did not call for.

- **Categories present**: geometry (`PointInPolygonTests` — ring/holes/
  MultiPolygon cases; `DistrictBoundariesTests` — real-coordinate
  resolution against the shipping 147-collegio data, hand-built hole/
  disjoint-part cases, and a performance test asserting `district(for:)`
  over 1,000 random Italian coordinates completes under 1 second),
  decoding/provenance (`DecodingTests`, `SchemaV2Tests` — the largest file
  at 23 methods, covering shipping-data invariants, tolerant-decode
  defaults, and referential integrity), service lookups
  (`ServiceLookupTests`, `GeocodingProvidingTests`), party
  styling/contrast (`PartyStyleServiceTests` — including the WCAG
  ≥4.5:1-contrast test added in this report's own prior-session work),
  initials (`InitialsTests`), accessibility symbols
  (`VoteChoiceAccessibilityTests` — asserts every `VoteChoice` case has a
  distinct, non-empty SF Symbol name and accessibility label).
- **Build/test commands**: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  xcodebuild -project Politici.xcodeproj -scheme Politici -destination
  'generic/platform=iOS Simulator' build`, then discover a simulator via
  `xcrun simctl list devices available`, then `... -destination
  'platform=iOS Simulator,name=<SimName>' test` — both documented in
  `README.md` and confirmed as what this session's author actually ran
  (category 4) against an `iPhone 17 Pro` simulator (the task-suggested
  `iPhone 15` is not present in this environment's simulator runtime).
- **Manual simulator checks recorded**: `docs/v2/*.md` files record
  several (e.g. the votes-import Foti/Bergamini cross-check, §12); this
  report's author also personally took simulator screenshots at large
  Dynamic Type sizes during the accessibility phase (category 4,
  described in `docs/v2/a11y-checklist.md`'s own "Manual checks" section
  as what a human should still additionally verify with actual VoiceOver
  — see §15).
- **What remains manual-only**: VoiceOver itself was never actually
  turned on and swept through by an automated agent in this project's
  history — `docs/v2/a11y-checklist.md` states this limitation directly.
  `PoliticiUITests` remains template-only at both releases, so no
  automated UI-interaction coverage exists at all.

### The referential-integrity weaken→vacuous→genuine episode

See §18 for the full commit-cited account — summarized here for the
testing-evolution narrative: a real `testEveryVoteReferencesAKnownRepresentative`
check existed from the v2 test bootstrap (Phase 1) onward. When Phase 5
(`f6867eb`) imported 601 real representatives but left `votes.json`
fictional (still referencing old `REP###` ids), that check was **removed**
and replaced with a weaker self-consistency-only check, with an explicit
code comment promising to "re-add this check once votes.json is
regenerated from real roll-call data." Phase 6 (`8b16be1`) shipped
`votes.json` as a valid, empty array, and reinstated a same-named
check (`testShippingVotesReferenceKnownRepresentatives`) — but its own
comment discloses it was **vacuously true** on the empty set, not a
meaningful test yet. Phase 9 (`6625944`), once `votes.json` held 4,788
real positions, changed nothing about the test's code but updated its
comment to state it was now **genuinely, non-vacuously** exercised — the
same assertion had been sitting there since Phase 6, waiting for real
data to actually test something.

## 15. Accessibility evolution

- **v1**: no accessibility work found anywhere in the codebase at
  `6d3b866` (confirmed by `grep -rn "accessibility" Politici/Views` at
  that commit returning no matches — this exact check was performed for
  this report).
- **v2, before Phase 11**: `git show 8a1aa90:HomeView.swift` (i.e. the
  state right before the accessibility phase) has exactly one
  `.accessibilityLabel` call (the info toolbar button) — everything else
  in the app had none, per `docs/v2/a11y-checklist.md`'s own audit table.
- **The `MapView` finding**: the checklist states plainly this was "the
  single biggest gap in the app" — district selection is a raw
  `SpatialTapGesture` on a `MapReader`/`Map`, and MapKit polygon overlays
  rendered this way are not exposed as individually discoverable/
  selectable VoiceOver elements at all. This is why `CollegiListView`
  exists — not as a generic accessibility nicety, but as the *only* way a
  VoiceOver user can reach a collegio's detail screen.
- **VoteBadge non-color-only fix**: SF Symbol + existing Italian word via
  `Label`, plus a distinct `accessibilityLabel` per case (moved onto
  `VoteChoice` itself — §5) — checkmark/"Voto favorevole",
  xmark/"Voto contrario", minus/"Astenuto", slash.circle/"Assente",
  questionmark/"Esito non disponibile".
  `VoteChoiceAccessibilityTests` asserts every case's symbol and label are
  both non-empty and mutually distinct across all 5 cases.
- **VoiceOver combining strategy**: rows/headers with no nested
  interactive control combined via `.accessibilityElement(children:
  .combine)` (`RepresentativeRow`, `StatCard`, `DistrictDetailView`'s and
  `RepresentativeProfileView`'s headers). `VoteRow` is the one documented
  case where combining was deliberately *not* applied to the whole
  container — its "Fonte" `Link`, when present, is kept outside the
  combined group, because combining a container with a nested
  interactive control would make that control unreachable via VoiceOver
  swipe navigation, not just merge its text into the group's label (this
  reasoning is stated directly in `VoteHistoryView.swift`'s own comment).
- **Dynamic Type**: `grep -rn "lineLimit\|truncationMode\|minimumScaleFactor"
  Politici/Views` at the pre-Phase-11 state found exactly one hit —
  `InitialsAvatar`'s `.minimumScaleFactor(0.7)`. Resolved not by removing
  the scale factor but by marking `InitialsAvatar` `.accessibilityHidden(true)`
  at every call site, since the real name is always available as
  unscaled text elsewhere in the same row/header — no information is lost
  to scaling at any text size. Verified visually (category 4: this
  session's author personally took the screenshots) at
  `UICTContentSizeCategoryAccessibilityM` and `...XXXL` via a simulator
  launch-argument override.
- **Hit targets**: five under-44pt custom controls
  (`PartyFilterChip`, the search-field trailing icon button, the footer
  "Informazioni e fonti" link, the "Fonte"/"Apri la fonte" links, the
  sample-city quick buttons) brought to ≥44pt via `.frame(minHeight:
  44).contentShape(Rectangle())`, per the checklist's own table.
- **What remains manual-only / disclosed limitation**: the checklist
  states directly that VoiceOver itself was never turned on and swept
  through in this environment — every fix above was implemented from
  direct SwiftUI Accessibility API knowledge and verified by reading the
  resulting code, not by an actual VoiceOver walkthrough. It lists 5
  specific manual checks still needed (VoiceOver walkthrough of both main
  flows, an Accessibility Inspector automatic audit per screen, a
  max-Dynamic-Type walkthrough beyond the two screenshots taken, a Reduce
  Motion toggle check, and a rotor-based Links check on
  `VoteHistoryView`/`FontiEDatiView`).

## 16. Attribution, licensing, and provenance

Source: `Politici/Data/sources.json` (5 entries, re-read directly this
session) and `docs/DATA_SOURCES.md`, cross-checked 1:1 against each other
(the doc's own "Cross-check" section records this comparison was already
performed when it was written; this report independently re-confirmed the
same 5 `id`/`name`/`url`/`license`/`retrievedAt` values match by direct
comparison of the raw JSON against the doc's tables).

| id | name | url | license | retrievedAt |
|---|---|---|---|---|
| `camera-dei-deputati-xix-legislatura` | Camera dei Deputati — Open Data (XIX Legislatura) | `https://dati.camera.it/sparql` | CC BY 4.0 | 2026-07-18 |
| `camera-dei-deputati-votazioni-xix-legislatura` | Camera dei Deputati — Votazioni (XIX Legislatura) | `https://dati.camera.it/sparql` | CC BY 4.0 | 2026-07-18 |
| `senato-della-repubblica-xix-legislatura` | Senato della Repubblica — Open Data (XIX Legislatura) | `https://dati.senato.it/sparql` | CC BY 3.0 | 2026-07-18 |
| `istat-collegi-elettorali-camera-uninominali` | ISTAT — Basi geografiche dei collegi elettorali (Camera, uninominali) | `https://www.istat.it/notizia/le-basi-geografiche-dei-nuovi-collegi-elettorali-2` | CC BY 4.0 | 2026-07-18 |
| `prototipo-dati-dimostrativi` | Dati dimostrativi generati per il prototipo | *(empty string)* | n/a | 2026-07-17 |

`docs/DATA_SOURCES.md` additionally states each entry's `notes` text
verbatim and a "Data-refresh procedure" (the 5 `make` steps, §9) — not
reproduced again here to avoid duplicating the file itself; see that file
directly for the exact `notes` strings.

- **Unofficial-status disclaimer** (in-app, `FontiEDatiView.swift`, exact
  string): *"Politica è un prototipo indipendente a scopo informativo e
  dimostrativo. Non è affiliata a, né approvata da, la Camera dei
  Deputati, il Senato della Repubblica o altre istituzioni."*
- **Snapshot/staleness warning** (in-app bullet, exact string): *"I dati
  mostrati sono uno snapshot e potrebbero non essere aggiornati."*
- **No-emblem policy** (in-app bullet, exact string): *"Questa app non
  utilizza loghi o emblemi istituzionali."*
- **Sample vs. official provenance behavior**: every `Representative`/
  `District`/`Vote` record carries `provenance`; the shipping datasets are
  100% `.official` (re-verified this session, §8); the `*.sample.*`
  fixtures are 100% `.sample` by construction (they predate the field and
  decode to the default). `RepresentativeProfileView` renders a
  provenance badge (`"Fonte ufficiale"`/`"Dati dimostrativi"`, per
  `DataProvenance.displayName`).
- **Photo policy**: no representative photos are fetched or bundled —
  `photoName` renders a local SF Symbol / (as of Phase 10) an
  `InitialsAvatar`, never a downloaded image, stated as a deliberate
  local-first-constraint decision in `docs/v2/01-real-data-import.md`
  (the source SPARQL data's real `?foto` URLs are not carried into the
  app).
- **Attendance policy**: `Representative.attendanceRate: Double?` exists
  in the schema but is `nil` for every real record — no source in this
  pipeline publishes a documented, reproducible attendance methodology
  (stated in `docs/v2/01-real-data-import.md`).

**This report provides no new legal conclusions about licensing,
attribution sufficiency, or compliance — it restates what the repository
itself already asserts. None of the above is legal advice.**

## 17. Decision/deviation register

For each item: original assumption → contradicting evidence → resolution
→ architectural consequence → lesson for V3.

| # | Item | Original assumption | Contradicting evidence | Resolution | Architectural consequence | Lesson for V3 |
|---|---|---|---|---|---|---|
| 1 | Local-raw-adapter plan vs. SPARQL pipeline | `README.md` (v1.0.0)'s own roadmap section speaks generically of "Real parliamentary data APIs" without specifying a fetch/cache/import split | The actual v2 pipeline separates one network-touching `fetch` step from everything else, with a gitignored cache | Built as `make fetch` (network) → `tools/raw/*.json` (cache) → `make import` (offline) | Every non-fetch pipeline step is reproducible offline and CI-safe; `make import` never depends on live network | Decide the fetch/cache/import boundary explicitly before writing any pipeline code, not after |
| 2 | No app-runtime networking despite developer-tool networking | `CLAUDE.md` (v1) states "The app is local-first: no networking code, no backend, no analytics" without addressing developer tooling | v2 needed live SPARQL queries to build the data at all | `CLAUDE.md` (v2.0-prototype) explicitly scopes constraint #3 to "the shipping app," carving out `tools/` | None of `Politici/`'s Swift code makes a network call; only `tools/fetch_*.py` do | State scope boundaries for a constraint explicitly (what it does and doesn't cover) rather than leaving it to interpretation |
| 3 | `districtId` non-optional | v1's `Representative.districtId: String` | Real records genuinely have no mapped district for most representatives | Changed to `String?`; call sites use optional-safe filtering | One of the few required breaking model changes in the whole v2 rewrite | A "real data may have absent values" assumption should be built into a schema from the start, not retrofitted |
| 4 | Fictional votes stay fictional | (no stated assumption — inherited from v1) | Real vote data wasn't available until Phase 9 | `votes.json` moved fictional content to `votes.sample.json`, shipped empty in the interim (Phase 6), then real (Phase 9) | Referential-integrity test went through a documented weaken→vacuous→genuine cycle (§18) rather than staying broken or being deleted | An interim "honestly empty" state is preferable to either a broken reference or silently dropped test coverage |
| 5 | Senato count | (unstated) | Raw Senato query returns 208 people, some post-mandate | Verified inclusion rule: no `fineMandato` bound, elected or life-appointed alike → 201 | `docs/v2/02-post-import-audit.md` documents the full breakdown, including why Napolitano is correctly excluded | Don't accept a raw source count at face value — verify what filter it actually needs |
| 6 | Remote portraits | Source data has real `?foto` URLs | Fetching them at runtime would violate local-first | Never carried into the app; initials avatars instead (Phase 10) | Zero image assets/network calls for representative photos | A real field existing in the source doesn't obligate using it if using it breaks a standing constraint |
| 7 | ISTAT MultiPolygon decoding | Assumed `MKGeoJSONDecoder` would flatten MultiPolygon into multiple `MKPolygon`s | It wraps them in one `MKMultiPolygon` instead | `GeoJSONLoader` explicitly unwraps both shapes | Fixed a real, silent data-loss bug (56 multi-part districts would otherwise decode empty) | API assumptions about a framework's output shape need a real runtime check, not just documentation-reading |
| 8 | `region` property | Assumed `CU20_C1` was a geographic region (the field name's own implication) | It's a within-circoscrizione sub-collegio suffix | Renamed to `subCode`; true circoscrizione parsed from `CU20_DEN`'s prefix instead | `District.region` never existed as a final shipped name — it was caught and corrected within the same boundaries phase before shipping | A field's name in source data is a hypothesis, not a fact — verify against sample values |
| 9 | `?collegio` SPARQL variable | Assumed it identified the uninominale collegio (its existing use in `camera_deputati.rq`, from the representative-import phase, implied this) | It identifies the plurinominale collegio — too coarse | `dcterms:spatial` + `tipoElezione` found via live introspection instead | The linkage phase needed net-new SPARQL predicates the original query didn't select at all | A variable already in use elsewhere in the codebase is not proof it's fit for a new purpose |
| 10 | 147/147 linkage achievable | Uncertain going in — the task's own quality gate (`MIN_LINKED_COLLEGI = 133`, 90%) implies less than 100% was the expected worst case | Structural join achieved a complete, verified bijection | Rung (c) fallback logic built but never exercised | The 90% gate remains in the code as a safety net for a *future* re-fetch, even though this run needed none of it | Build the safety net even when the happy path works — future data can regress |
| 11 | Secret-ballot votes | (unstated going in) | Their per-deputy records carry only a generic "voted" flag, never a position | Excluded from the votes scope entirely, by design | Prevents `Sconosciuto`-flooding that would misrepresent legal secrecy as a data gap | Distinguish "we don't know" from "this is inherently unknowable" — they need different handling |
| 12 | 25-vote nominal scope | `votes_scope.json`'s own default `n: 25` | ~399 positions/vote × 25 ≈ 9,975 records, over the ~2MB budget | `maxPositionRecords` budget caps actual import at 12, stopping at the first vote that doesn't fit | The shipped dataset is smaller than the nominal target, disclosed via the manifest's dynamically-computed note (not a hardcoded "25") | A budget cap should reduce scope predictably and explain itself, not silently truncate or fail |
| 13 | Party styling already complete | Phase 10's task brief (per this report's own prior-session account, category 3) framed party-color/short-name mapping as needing to be built in that phase | Phase 6 (`8b16be1`) had already built `Data/parties.json`/`PartyStyleService` with full 19-value coverage and verified contrast | Phase 10 audited and confirmed completeness rather than rebuilding | No redundant party-styling code — Phase 10's actual new work was the list/search/filter UI and initials avatars | Audit before implementing, even (especially) when a task brief assumes something isn't done yet |
| 14 | Full representative browser existed | Reasonable to assume, given 601 representatives were already imported by Phase 6 | Home only ever rendered a 4-item featured preview; no route to browse all 601 existed before Phase 10 | `RepresentativeListView` built in Phase 10 | New `AppRoute.representativeList` case, new searchable/filterable screen | A dataset being imported doesn't mean it's browsable — check the UI layer separately from the data layer |
| 15 | Map interaction was accessible | Not explicitly assumed either way before Phase 11 | `MapView` had zero accessibility support; polygon tap-selection has no VoiceOver equivalent | `CollegiListView` built as the accessible alternative path | New `AppRoute.collegiList` case, entry points from both `MapView` and `HomeView` | A feature's only interaction path being visually/gesture-based is itself a finding worth surfacing explicitly, not just "add labels" |

## 18. Failure, diagnosis, and correction log

This section consolidates the investigation loops with the clearest
before/after evidence in git history (the deviation-register rows above
cover the broader set):

### The `MKGeoJSONDecoder` MultiPolygon gap (Phase 7, `9841fea`)

Evidence: `GeoJSONLoader.swift`'s own code comment, quoted in full in §10.
The fix is visible directly in the shipped `flatMap` unwrapping logic. The
narrative that this was found via a failing `DistrictBoundariesTests` run
and standalone `swiftc` probe scripts is category 3 (this session's own
account) — the probes themselves are not in the repository.

### The `region`→`circoscrizione`/`subCode` correction (Phase 8, `2820bec`)

Evidence: `docs/v2/03-linkage-report.md`'s "Full shapefile schema" section
(§10) — states the finding was made by running the *full* `ogrinfo`
schema dump (not just the three fields the boundaries phase had used),
discovering no dedicated circoscrizione field exists, and that `CU20_DEN`'s
structure had to be parsed instead — verified against all 147 rows and
cross-checked against the official D.Lgs. 177/2020 circoscrizione list
before being adopted.

### The `?collegio` wrong-granularity discovery (Phase 8, `2820bec`)

Evidence: `docs/v2/03-linkage-report.md` §"Step 4" — states directly that
exploring the *cached* raw SPARQL response first (before writing any
matching code) revealed all 55 distinct `?collegio` values used a `P0N`
(plurinominale) suffix, never `U0N`, and that live introspection against
the endpoint (enumerating `?el`'s full predicate set) was needed to find
`ocd:tipoElezione`/`dcterms:spatial` as the actual solution.

### The referential-integrity weaken→vacuous→genuine cycle (Phases 5, 6, 9)

Full commit-level evidence already presented in §6 and §14; the three
states, verified via `git show <commit> -- PoliticiTests/*.swift`:

1. `f6867eb`: `testEveryVoteReferencesAKnownRepresentative` **removed**,
   replaced by `testVotesFileStillUsesItsOwnSelfConsistentIds` (checks
   only that `votes.json`'s own ids are self-consistent, with an explicit
   comment disclosing the check was dropped and why).
2. `8b16be1`: `testShippingVotesReferenceKnownRepresentatives` **added
   back**, with a comment explicitly stating it is *"vacuously — but
   genuinely, not artificially — satisfied"* because `votes.json` now
   ships as a valid empty array rather than referencing stale ids.
3. `6625944`: the same test's **code is unchanged**; only its comment
   changes, to state the check is now *"genuinely (not vacuously)
   exercised"* because `votes.json` holds 4,788 real positions.

### The missing full representative browser (Phase 10) and the inaccessible polygon-only map (Phase 11)

Both are "discovered while auditing, not while implementing" findings —
see deviation-register rows 14–15. Both resulted in a genuinely new
screen + `AppRoute` case rather than a modification of an existing one,
because in both cases no reasonable alternative existed to extend.

## 19. Current known limitations (verified, current state only)

- **Snapshot, not real-time data**: every `Data/sources.json` entry has a
  fixed `retrievedAt`; nothing in the shipping app refreshes
  automatically (§16).
- **Curated Camera vote subset**: 12 of an unknown-but-larger total of
  qualifying XIX-legislature Assemblea votes (§12) — not a complete
  voting record.
- **No Senato vote import**: `votes.json` contains Camera positions only
  — confirmed by this session's own re-count (§8): all 4,788 records'
  `representativeId`s resolve against Camera `stableSourceId`s per
  `import_votes.py`'s own `camera_stable_ids`-only lookup.
  `docs/v2/04-votes-import.md` states Senato votes are out of scope
  entirely.
- **No Senato geography**: `districts.geojson`'s 147 features are 100%
  `chamber: "Camera"` (re-verified §8) — no Senato collegio boundaries
  exist anywhere in the shipped data.
  `Politici/Views/MapView.swift`'s legend still shows a Senato color
  ("Senato della Repubblica", purple), which — given zero Senato features
  ever render — is dead legend content as of the current data; **this is
  a newly-noted finding of this audit, not previously flagged in any
  `docs/v2/*.md` file** (Non verificabile whether this was already known
  and simply not written down — nothing in the repo confirms either way).
- **Plurinominale/estero representatives not mapped to geography**: 245
  plurinominale + 8 estero = 253 of 400 Camera deputies (§8) have
  `districtId: null` by design — stated explicitly in-app via the "Come
  funziona l'elezione" explainer (§5).
- **No portrait photos** (§16).
- **Attendance hidden for official records**: `attendanceRate` is `nil`
  for all 601 real representatives (§16); the field and its rendering
  code (`RepresentativeProfileView`'s `attendanceBadge`) exist but are
  simply never populated for real data.
- **No accounts/backend/analytics/push**: confirmed by `CLAUDE.md`'s own
  constraint #3 and by the absence of any networking import
  (`URLSession`, `Combine`'s network publishers used for anything but
  `MKLocalSearchCompleter`/`CLGeocoder`, which are Apple on-device/
  Apple-service APIs, not custom networking) anywhere under `Politici/`
  at `v2.0-prototype` — not independently re-grepped line-by-line for
  this report beyond the services already inventoried in §5, so stated
  with that caveat.
- **Deployment-target issue still present**: `IPHONEOS_DEPLOYMENT_TARGET
  = 26.5` unchanged from the very first commit through `v2.0-prototype`
  (§4, §10) — never addressed in any v2 phase.
- **Geocoding fallback unchanged since v1**: `GeocodingService`'s
  hardcoded 5-city table is still the only offline fallback — confirmed
  identical file content between `6d3b866` and `v2.0-prototype` (§5). No
  "geocoding deprecation" was found in this audit — `CLGeocoder` is not a
  deprecated API as of the SDK this project targets; **Non verificabile
  dal repository** whether any deprecation warning has been observed in
  an actual Xcode build log, since this audit did not run a build.
- **Manual-only UI and VoiceOver testing**: `PoliticiUITests` remains
  template-only at `v2.0-prototype` (§14); no VoiceOver walkthrough was
  ever automated or recorded as performed by an agent — only by direct
  code/API-level implementation plus screenshot-based Dynamic Type checks
  (§15).
- **`Representative.swift`'s stale doc comment** on `districtId` (§5) —
  a small, genuine documentation/code-comment drift, not a functional
  bug.
- **No `docs/v2/*.md` design note for Phase 10** (§6) — a genuine gap in
  this repository's own self-documentation discipline, which every other
  phase from 5 onward otherwise maintained.
- **No `docs/releases/v2.0-prototype.md` file** (§20) — GitHub release
  notes, if they exist, were assembled from `CHANGELOG.md`/`README.md`
  content outside this repository; this repository contains no dedicated
  release-notes file.

## 20. V3 factual baseline and unanswered questions

This section is a handoff baseline, not a V3 design. No architecture
recommendations are made here.

**Established as fact for V3 to build from**:
- Bundle id/target/scheme (`Politici`) and display name (`Politica`) have
  never changed across either release and are not proposed to change.
- The `tools/` fetch(network)/import(offline)/validate/manifest pipeline
  pattern, and the `*.sample.*` fixture-preservation convention, are the
  established mechanisms for introducing any new real dataset.
- `TolerantStringEnum` is the established mechanism for any new
  enum-shaped field sourced from external data.
- The `MKGeoJSONDecoder`→`MKPolygon`/`MKMultiPolygon` decoding behavior
  (§10) is now a known, documented API quirk — any future geometry work
  should assume it, not rediscover it.
- The 147/147 Camera uninominale linkage is complete and verified; Senato
  linkage has no equivalent work done at all (not partially done, not
  started).
- The votes dataset's budget mechanics (`maxPositionRecords`,
  stop-at-first-vote-that-doesn't-fit) are a working, tested pattern for
  any future scope expansion — but the current 12-vote/4,788-record
  result is a *product* of that mechanism at its current budget, not a
  hard ceiling of the mechanism itself.

**Open questions this report cannot answer from the repository alone**:
1. Is the GitHub repository (`github.com/giuliocrp/politica`) public or
   private? (§3 — needs a GitHub-side check, not a git-side one.)
2. Was a `v1.0.0` tag ever intended and simply never created, or is the
   `CHANGELOG.md`/documentation-only "v1.0.0" label the intended permanent
   scheme? (§2, §3.)
3. What would it take to extend the boundaries/linkage pipeline to
   Senato, given it was never attempted (not even a false start) in this
   history? (§19.)
4. Is the `MapView` legend's Senato color entry (§19) a known, accepted
   piece of forward-looking UI (anticipating future Senato data) or an
   overlooked inconsistency? Nothing in `docs/v2/*.md` addresses it
   either way.
5. What is the actual policy or decision behind the
   `IPHONEOS_DEPLOYMENT_TARGET = 26.5` value being left unchanged across
   12 v2 phases despite being flagged as a quirk in the very first audit
   (`docs/v2/00-audit.md`)? Never revisited, never explicitly deferred in
   writing.
6. The 92-vs-96/97 test-count discrepancy (§14) — resolvable only by
   actually re-running the suite and inspecting `xcodebuild`'s own test
   log line-by-line, which this audit's scope did not include.
7. Whether the original acquisition briefs this report describes as
   "reportedly" specifying certain details (e.g. lowercase `"camera"`,
   `districtId: null` for every real record) are preserved anywhere
   outside this session's own conversational history — **Non
   verificabile dal repository**; if such briefs exist as separate
   artifacts, they are not part of this git history.

## 21. Evidence index

**Tags**: `v2.0-prototype` → `72448dc22c69ef8dfdb5ae33376186e14450bdf7` (annotated). No `v1.0.0` tag exists.

**Key commits** (see §3 for the full table): `3ab4e58`, `5d8e36a`,
`6d3b866` (v1.0.0 boundary), `b0b6c77`, `bdff254`, `d9a922f`, `e6e5ffe`,
`b92ffd8`, `f01dd15`, `f6867eb`, `8b16be1`, `9841fea`, `2820bec`,
`6625944`, `8a1aa90`, `a084f3d`, `72448dc` (v2.0-prototype).

**Key files cited** (all at `v2.0-prototype` unless a specific commit is
named): `CLAUDE.md`, `README.md`, `CHANGELOG.md`, `docs/DATA_SOURCES.md`,
`docs/v2/00-audit.md` through `04-votes-import.md`, `docs/v2/a11y-checklist.md`,
`Makefile`, `Politici.xcodeproj/project.pbxproj`,
`Politici/App/{PoliticiApp,ContentView}.swift`,
`Politici/Models/{District,Representative,Vote,DataProvenance,TolerantDecoding,PartyStyleEntry,SourcesManifest}.swift`,
`Politici/Services/{ServiceContainer,DistrictService,RepresentativeService,VoteService,GeocodingService,GeoJSONLoader,ManifestService,PartyStyleService,AddressAutocompleteService}.swift`,
`Politici/Utilities/{PointInPolygon,DateFormatting,Initials,ColorHex}.swift`,
`Politici/Views/{AppRoute,HomeView,MapView,AddressSearchView,DistrictDetailView,RepresentativeProfileView,VoteHistoryView,RepresentativeListView,CollegiListView,FontiEDatiView}.swift`,
`Politici/Data/{districts,representatives,votes,parties,sources}.json`
and their `*.sample.*` counterparts,
`tools/{sparql_client,fetch_camera,fetch_senato,fetch_camera_votes,import_representatives,import_boundaries,import_votes,validate_data,make_manifest}.py`,
`tools/build_boundaries.sh`, `tools/config/votes_scope.json`,
`tools/queries/*.rq`, `PoliticiTests/*.swift`.

**Key symbols cited**: `ServiceContainer`, `TolerantStringEnum`,
`DataProvenance`, `District.polygons`/`boundingMapRect`,
`GeoJSONLoader.makeDistrict`, `PointInPolygon.contains(_:in:MKPolygon)`/
`contains(_:inAny:)`, `DistrictService.district(for:)`,
`Representative.electionType`/`stableSourceId`,
`normalize_circoscrizione`, `load_uninominale_index`,
`MIN_LINKED_COLLEGI`, `UNINOMINALE_TIPO_ELEZIONE`,
`ESTERO_COVERAGE_VALUES`, `clean_atto_label`, `ATTO_LABEL_ARTIFACT_RE`,
`RAW_VOTE_CHOICE`, `maxPositionRecords`, `VoteChoice.symbolName`/
`.accessibilityLabel`, `InitialsAvatar`, `CollegiListView`,
`AppRoute.collegiList`/`.representativeList`/`.fontiEDati`.

## 22. Confidence table

| Claim area | Category | Basis |
|---|---|---|
| v2.0-prototype tag → commit 72448dc | 1 — verified from git | `git rev-parse` |
| v1.0.0 boundary = commit 6d3b866, no tag exists | 1 — verified from git | `git tag --list`, `git reflog show main`/`v2` |
| main/v2 fast-forward, no merge commits anywhere | 1 — verified from git | `git log --all --merges`, `git reflog` |
| v1.0.0 file tree, model/service/view contents | 1 — verified from git | `git show 6d3b866:...` |
| v2.0-prototype file tree, model/service/view contents | 1 — verified from git | `git show v2.0-prototype:...` (= current working tree, confirmed via `git diff`) |
| Data record counts, both releases | 1 — verified from git | Piped `git show <ref>:Data/*.json` into Python, this session |
| Test method counts (static) | 1 — verified from git | `grep` against `v2.0-prototype`, this session |
| Test pass counts from `xcodebuild test` (96–97) | 4 — this session's direct execution | Observed in this same conversation, prior turns; not independently re-run for this report |
| `Makefile`/pipeline script responsibilities, constants | 1 — verified from git | `git show v2.0-prototype:tools/...` |
| Boundaries/linkage/votes findings (circoscrizione, ?collegio, 147/147, secret ballots, 12-vote budget) | 2 — committed documentation | `docs/v2/03-boundaries-audit.md`, `03-linkage-report.md`, `04-votes-import.md` |
| Referential-integrity weaken→vacuous→genuine episode | 1 — verified from git | `git show <commit> -- PoliticiTests/*.swift`, three commits |
| Accessibility findings (MapView gap, fixes made) | 2 — committed documentation | `docs/v2/a11y-checklist.md` |
| Foti/Bergamini live-page cross-check result | 2 (result) / 3 (the live check itself, not repeatable here) | `docs/v2/04-votes-import.md`; original web fetch not re-performed |
| `MKGeoJSONDecoder` diagnostic *process* (probe scripts) | 3 — historical session narrative | Not preserved in the repository; the *finding* itself is category 1/2 |
| Phase 10 (UI completion) narrative beyond the commit diff | 3 — historical session narrative | No `docs/v2/*.md` exists for this phase |
| GitHub repository public/private status | 6 — Non verificabile dal repository | Would require a GitHub-side check |
| Deployment-target-26.5 rationale/decision history | 6 — Non verificabile dal repository | Never documented anywhere found |
| Whether `MapView`'s dangling Senato legend entry was previously noticed | 6 — Non verificabile dal repository | Not addressed in any committed doc |
| Manual VoiceOver walkthrough having been performed | 6 — Non verificabile dal repository (explicitly disclosed as NOT done) | `docs/v2/a11y-checklist.md`'s own limitations section |

---

## Final verification

- **No files were modified except this new report.** `git status`
  (re-run immediately before finalizing this report) shows the working
  tree clean apart from this one new, untracked file:
  `docs/history/implementation-evidence-v1-v2.md`.
- This report was **not staged or committed**.
