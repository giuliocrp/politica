# V3 Phase 13 — Baseline Audit and Hygiene Closeout

Establishes the empirically verified build/test baseline for the `v3`
branch, audits (without changing) the deployment target, and closes out a
set of pre-identified hygiene items. Zero changes to bundled political
data; zero edits to `docs/v2/*` or the merged `docs/history/*` archive.

## 1. Branch base verification

- `main` was clean and up to date with `origin/main` at the start of this
  phase: `git fetch origin main` returned the same commit as local
  `main` (`f952f2df6f066bbe68dbe71218433f006340603c`), and `git status`
  showed a clean working tree.
- `git merge-base --is-ancestor 72448dc HEAD` succeeded — the
  v2.0-prototype tag commit is an ancestor of current `main`.
- `docs/history/` exists at that HEAD with the audited archive: `README.md`,
  `POLITICA_IMPLEMENTATION_HISTORY_V1_V2.md`,
  `POLITICA_HISTORY_GAPS_AND_CONFLICTS.md`, `implementation-evidence-v1-v2.md`,
  `POLITICA_V3_FACTUAL_BASELINE.md`, `ROUND_2_AUDIT.md`,
  `ROUND_3_ACCEPTANCE_AUDIT.md`, `HISTORY_PACK_COMMISSIONING_BRIEF.md`,
  `CLAUDE_CODE_FACTCHECK_HOME_PARTIES.md`.
- Both preconditions held, so branching was not premature.
- **HEAD hash at branch time:** `f952f2df6f066bbe68dbe71218433f006340603c`
  (merge commit "Merge pull request #1 from giuliocrp/docs/history-archive").
- The `v3` branch already existed locally at this exact commit at the
  start of this session (`git rev-parse v3 main` returned identical
  hashes, `git log main..v3` / `git log v3..main` both empty) — no new
  branch needed to be created; this phase's work continues on it directly.
  It has not been pushed to `origin` (no `origin/v3` ref exists).

## 2–3. Build and test baseline, with reconciliation

### Build

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Politici.xcodeproj -scheme Politici -destination 'generic/platform=iOS Simulator' build
```

`** BUILD SUCCEEDED **` at the unmodified deployment target (26.5).

### Test

Simulator: `iPhone 17 Pro` (iOS 26.5), discovered via `xcrun simctl list
devices available`. Full run with `-resultBundlePath` for `.xcresult`
capture:

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Politici.xcodeproj -scheme Politici -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -resultBundlePath <path>.xcresult test
```

`** TEST SUCCEEDED **`, 0 failures.

### Dual definition — declared test methods vs. runtime test cases

**Declared test methods (static count):** **94** total.

- `PoliticiTests` target: **91** — `grep -rnE "^\s*func test[A-Za-z0-9_]*\("
  PoliticiTests --include="*.swift" | wc -l` → **90** XCTest-style methods
  across 10 `XCTestCase` files (`DateFormattingTests` 5,
  `DecodingTests` 9, `DistrictBoundariesTests` 8, `GeocodingProvidingTests`
  7, `InitialsTests` 8, `PartyStyleServiceTests` 6, `PointInPolygonTests`
  7, `SchemaV2Tests` 23, `ServiceLookupTests` 11,
  `VoteChoiceAccessibilityTests` 6), **+ 1** Swift Testing method
  (`@Test func example()` in `PoliticiTests/PoliticiTests.swift`, the
  unmodified Xcode-template file — it doesn't match the `func test` grep
  pattern because Swift Testing doesn't require the `test` name prefix).
  11 files total in `PoliticiTests/`, matching the file count the
  historical v2 audit cited.
- `PoliticiUITests` target: **3** — `PoliticiUITests.testExample()`,
  `PoliticiUITests.testLaunchPerformance()`,
  `PoliticiUITestsLaunchTests.testLaunch()`.

This is very close to, but not identical to, the number the v2-era audit
is reported to have found (92 methods across 11 files in `PoliticiTests`
alone — see STARTING STATE). The current, reproducible static count for
that same target is 91 (90 XCTest + 1 Swift Testing) across those same 11
files. No commit between the v2 tag and now touched any `PoliticiTests/*`
file (`git log 72448dc..HEAD -- PoliticiTests/` is empty), so the file
contents are unchanged since the v2 audit; the 1-method gap is most
likely a difference in the earlier grep's pattern (e.g. whether it also
matched the Swift Testing `@Test` file, or an off-by-one in a manual
count) rather than a real change in test content. Not investigated
further since it doesn't affect this phase's own dual-definition
baseline, which is independently reproducible from the commands above.

**Runtime test cases (dynamic count, this run):** **97** passed, 0
failed — confirmed two independent ways:

- Log-based: `grep -c "^Test case .* passed" test.log` → 97;
  `grep -oE "Test case '[A-Za-z0-9_./]+\(\)'" test.log | sort -u | wc -l`
  → 94 unique identifiers.
- `.xcresult`-based (authoritative,
  `xcrun xcresulttool get test-results summary --path test.xcresult`):
  top-level `"totalTestCount": 94`, `"result": "Passed"`,
  `"failedTests": 0`; the single `devicesAndConfigurations` entry reports
  `"passedTests": 97` at that level. The tool's own `statistics` block
  names the cause directly: `"1 test ran with dynamic parameters"` /
  `"4 test runs"`.

**Cause, confirmed by source inspection:**
`PoliticiUITests/PoliticiUITestsLaunchTests.swift` overrides
`runsForEachTargetApplicationUIConfiguration` to return `true` (an
unmodified Xcode-template default). This makes `xcodebuild` execute
`testLaunch()` once per target-application UI configuration declared for
the scheme — 4 runs in this environment — each logged as its own `Test
case ... passed` line and counted individually in the per-device
`passedTests` figure, while still being exactly 1 declared method. 97
(runtime) − 94 (declared) = 3, exactly the 3 extra invocations of that one
method (4 runs − 1 declared = 3). This fully accounts for the gap; nothing
is left unresolved.

This also matches the historical range: the previously reported "96–97
passing test cases" brackets the deterministic 97 obtained here — the
range likely reflects environments where fewer target-UI-configurations
were available (e.g. 3 extra runs → 97, 2 → 96), not test flakiness.

## 4. Deployment-target audit

**Current target:** `IPHONEOS_DEPLOYMENT_TARGET = 26.5` in all 4
build-configuration stanzas of `Politici.xcodeproj/project.pbxproj`
(Debug/Release × app target/test target) — confirmed still 26.5 after
this phase's commit (see §11 diff note).

**APIs requiring iOS 17.0+** (grep + direct read of `Politici/`; full
detail delegated to and verified by a targeted source audit):

- The new SwiftUI Map API used throughout `Politici/Views/MapView.swift`:
  `MapCameraPosition` (line 15), `MapReader` (27), `Map(position:)` (28),
  `.mapStyle(.standard)` (33), `.mapControls { MapCompass(); MapScaleView() }`
  (34–36), `@MapContentBuilder` / `MapPolygon(_:)` (80, 85). This whole
  family (replacing the pre-iOS-17 `Map(coordinateRegion:)` API) is
  iOS 17.0+/macOS 14.0+.
- `Politici/Views/AddressSearchView.swift:115` — the two-parameter
  `.onChange(of: query) { _, newValue in … }` closure form is iOS
  17.0+/macOS 14.0+ (the single-value form is iOS 14+).

**APIs requiring iOS 18.0+ or later:** none found. Grepped for `@Entry`,
`.scrollPosition`, `MeshGradient`, `.presentationSizing`, the newer
`TabView`/`Tab(...)` API, `@Animatable`, `symbolEffect`,
`contentTransition`, `sensoryFeedback`, `scrollTargetBehavior` — zero
matches in `Politici/`.

**Other findings relevant to the hypothesis:** the codebase does **not**
use the `@Observable`/`Observation` macro (iOS 17+) anywhere — the one
`ObservableObject`/`@Published` usage
(`Politici/Services/AddressAutocompleteService.swift`) is the older,
iOS-13-compatible pattern. `NavigationStack` (iOS 16+) and
`SpatialTapGesture` (iOS 16+) are both below the iOS 17 floor already set
by the Map API. `#Preview` is a compile-time macro (Xcode 15+
requirement, not a runtime deployment-target constraint). No
`@available(iOS 17, *)` / `@available(iOS 18, *)` annotations exist
anywhere in `Politici/`.

**Build/test result under a temporary iOS 17.0 target:**
`IPHONEOS_DEPLOYMENT_TARGET` was changed to `17.0` in all 4 stanzas of
`project.pbxproj` in the working tree only (never committed — verified
reverted, see §11), then:

- Build: `** BUILD SUCCEEDED **` (`xcodebuild … build`, same command as
  §2, unmodified otherwise).
- Test: `** TEST SUCCEEDED **`, `.xcresult` summary identical in shape to
  the baseline run — `"totalTestCount": 94"`, `"failedTests": 0`,
  `"passedTests": 97` at the device-configuration level, same
  `runsForEachTargetApplicationUIConfiguration`-driven 94→97 pattern.

No compiler errors, warnings, or test regressions at iOS 17.0.

**Recommendation:** the real minimum deployment target this codebase
requires is **iOS 17.0**, driven entirely by `MapView`'s SwiftUI Map API
and one `.onChange` call site — both empirically confirmed to build and
pass all tests at that floor. The current project value of 26.5 is an
unexamined Xcode-template default with no technical justification found;
lowering it to 17.0 would not require any source change (confirmed by
this audit's own build/test run at that target) and would materially
widen the set of devices the app can run on. The only judgment call left
to the user is *how far back* to support (17.0 is the technical floor;
picking something higher, e.g. matching a specific device/OS-share
target, is a product decision this audit doesn't make).

**Deployment-target change requires explicit user approval; see
Phase 13B.**

## 5. Dead Senato legend entry

`Politici/Views/MapView.swift`'s `legend` view unconditionally rendered
two swatches — "Camera dei Deputati" and "Senato della Repubblica" — even
though the map only ever renders `District` overlays, and every shipped
district has `chamber == .camera` (`districts.geojson` contains 147
entries, all `"chamber": "Camera"`; confirmed via
`grep -o '"chamber"[^,}]*' Politici/Data/districts.geojson | sort -u`). No
Senato map layer exists or is planned to be added by this dataset. The
"Senato della Repubblica" `legendItem` line was removed; the legend now
shows the one swatch that corresponds to real data.

**Other Senato UI references found** (grepped across all of `Politici/`,
not just `MapView.swift`) — reviewed and left in place because each is
conditional on the `Chamber` enum's `.senato` case, which is a real,
reachable value for **representatives** (`Representative.chamber` — 201
of 601 shipping representatives are senators) even though no *district*
ever carries it:

- `MapView.swift`'s `selectionCard` text and `fillColor` ternaries
  (`district.chamber == .camera ? … : …`) and `DistrictDetailView.swift`'s
  header ternary — technically always take the Camera branch today since
  no district is ever `.senato`, but they're generic, data-driven display
  logic on the `District` model's `Chamber` field, not a hardcoded
  advertisement of a feature that doesn't exist. Removing them would mean
  hardcoding an assumption ("districts are always Camera") into view code
  that the model doesn't itself assert.
  `RepresentativeProfileView.swift`'s equivalent ternary is on
  `representative.chamber`, which genuinely does take both branches.
- `HomeView.swift`'s explainer copy, which explicitly and correctly
  discloses that senators are listed but Senato collegio boundaries
  aren't part of this dataset — accurate disclosure text, not dead code.
- `FontiEDatiView.swift`'s disclaimer mentioning both chambers by name —
  accurate institutional-attribution text.
- Doc-comment mentions in `RepresentativeListView.swift` — comments, not
  UI.

None of these were confirmed-dead in the sense item (b) describes (a
static UI element with no corresponding data path), so none were removed.

## 6. `Representative.districtId` doc comment

**Before:**

> Nil for representatives imported from real open data whose electoral
> college hasn't been mapped to one of this app's sample districts yet
> (see tools/import_representatives.py). Always non-nil for the fictional
> sample dataset.

This was stale in two ways: it described a "not yet mapped" future state
from before the Phase 8 uninominale linkage landed, and it didn't state
that senators — not just some subset of unlinked deputies — are
categorically excluded from ever having a `districtId` in this dataset
(Senato collegio boundaries were never imported; see `HomeView`'s own
explainer copy, §5).

**After:**

> In the current shipping data, only Camera deputies elected in a
> collegio uninominale carry a districtId (see the Phase 8 uninominale
> linkage in tools/import_representatives.py); it is nil for deputies
> elected via the plurinominale/estero routes and always nil for
> senators, since Senato collegio boundaries aren't part of this dataset.
> Always non-nil for the fictional sample dataset.

Verified against `tools/import_representatives.py`'s own comments (Phase
8 linkage section, `election_type = "uninominale"` gating), which confirm
this is exactly what the pipeline does.

## 7. C5 — `RetrievedAt` date discrepancy

`tools/raw/` exists on this machine (gitignored, present locally). Direct
evidence gathered:

- `tools/raw/.fetch_metadata.json` (written by the fetch step itself):
  `"fetchedAt": "2026-07-18"` for all four sources (camera, camera_votazioni,
  istat, senato).
- Filesystem mtimes (`stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S"`) of the fetch
  outputs: `tools/raw/SOURCES.txt` → `2026-07-18 08:54:44`;
  `tools/raw/camera_collegi_uninominali_wgs84.geojson` (the derived,
  reprojected output written by the pipeline, not the original ISTAT
  publication) → `2026-07-18 10:29:40`. By contrast, the *original* ISTAT
  shapefile parts under `tools/raw/collegi/CAMERA_CollegiUNINOMINALI_2020/`
  carry mtime `2022-07-28` — that's ISTAT's own publication date baked
  into the shapefile, unrelated to when this pipeline downloaded it, and
  not the value the `RetrievedAt` field is meant to record.
- The shipped manifest (`Politici/Data/sources.json`) and
  `docs/DATA_SOURCES.md` both consistently say `2026-07-18` for all
  entries that correspond to this fetch (`docs/DATA_SOURCES.md` even
  states its own cross-check was run "on 2026-07-18").

All of this evidence — the fetch script's own metadata file, the
filesystem timestamps of what the fetch step actually wrote, and the two
independently-maintained shipped/living documents — agrees on
**2026-07-18**. `tools/raw/SOURCES.txt`'s `RetrievedAt: 2025-07-18` (all
three entries) was the wrong side — a typo, off by exactly one year.

**Disposition:** corrected. `tools/raw/SOURCES.txt` (gitignored, local
cache file — not part of this commit) was updated in place to
`RetrievedAt: 2026-07-18` for all three sources. `docs/DATA_SOURCES.md`
required no change — it already had the correct value. The frozen
`docs/v2/03-boundaries-audit.md`, which quotes the old (wrong) value, was
**not** touched, per the frozen-history rule; its quote is now understood
to be a faithful record of a typo that existed in `tools/raw/SOURCES.txt`
at the time it was written, not a discrepancy this phase needs to
reconcile further.

## 8. Backfills

Checked `docs/history/` for existing equivalents before creating
anything, per the frozen-history rule (never duplicate existing content):

- No file under `docs/history/` is itself a standalone v2.0-prototype
  release note or a Phase 10 design-note-shaped document. The archive
  *discusses* both gaps explicitly —
  `docs/history/POLITICA_HISTORY_GAPS_AND_CONFLICTS.md` finding **G3**
  ("No Phase 10 report… a short retrospective note would close the set")
  and its item 11 recommendation to backfill both a Phase 10 retrospective
  and a release note from the changelog; `docs/history/ROUND_2_AUDIT.md`
  independently confirms both as "verified absence." No existing document
  was duplicated by creating these two.
- Created `docs/history/backfills/v2.0-prototype-release-note.md` —
  the `## v2.0-prototype (2026-07-18)` section of `CHANGELOG.md`,
  reproduced verbatim with a source citation, opening with the required
  "Written retrospectively during V3. Not an original v2 artifact."
  banner.
- Created `docs/history/backfills/v2-phase-10-representative-ui.md` —
  a `docs/v2/*.md`-shaped retrospective report for Phase 10
  (`8a1aa90`), built from the commit itself and from the narrative
  already assembled in `docs/history/POLITICA_IMPLEMENTATION_HISTORY_V1_V2.md`
  §7.10 / `docs/history/implementation-evidence-v1-v2.md` (both of which
  grade that narrative **[E3]** — no contemporaneous artifact beyond the
  commit diff). This backfill preserves that same [E3] grading rather
  than silently upgrading it, and states plainly that it is a formatting
  pass, not new research. Same retrospective banner.
- Neither file was placed under `docs/v2/` or `docs/releases/`, per
  instruction.

## 9. Accessibility status

`docs/v2/a11y-checklist.md` (frozen — not edited) lists 5 pending manual
human checks under "Manual checks to perform in Simulator / Accessibility
Inspector" (full VoiceOver walkthroughs of both main flows; an
Accessibility Inspector automatic audit of all 9 screens; a
maximum-Dynamic-Type re-walk; a Reduce Motion toggle-and-confirm; a rotor
Links check on `VoteHistoryView`/`FontiEDatiView`). The user has reported
completing these. This is recorded here as **user-reported, not
independently re-verified** by this phase — no VoiceOver/gesture
automation was available in this environment either, the same limitation
`a11y-checklist.md` itself discloses. The V3 accessibility checklist
(to be created in Phase 22A, per the working plan referenced in this
phase's brief) will re-run all checks over V3's own surfaces rather than
relying on this carried-forward, unverified report.

## 10. V3 commissioning brief archival

Searched for a V3-specific commissioning brief distinct from the existing
`docs/history/HISTORY_PACK_COMMISSIONING_BRIEF.md` (which is the brief
for the *historical documentation pack*, not for V3 itself — confirmed by
reading its own "Status"/"Source" header: "preserves the exact prompt
used to commission the historical documentation pack for Politica v1.0.0
and v2.0-prototype… This is NOT yet a V3 architecture task."). Checked:
`docs/history/` contents (no other commissioning-brief-shaped file),
filename search across the whole repo for `*v3*brief*`/`*commissioning*v3*`
(no matches), untracked/gitignored working-tree files (none matching),
and this session's scratchpad (empty). No V3 commissioning brief was
found or provided in the working environment.

**Disposition: archival pending.** No brief exists to archive in this
phase; nothing was fabricated in its place. If/when the user provides it,
it can be archived verbatim under `docs/history/` labeled user-provided,
per this phase's brief — the one permitted addition to that otherwise-frozen
directory.

## 11. Diff scope for this commit

```
$ git diff --stat
 Politici/Models/Representative.swift | 10 ++++++----
 Politici/Views/MapView.swift         |  1 -
```

Plus new files: `docs/v3/13-baseline-audit.md` (this report),
`docs/history/backfills/v2.0-prototype-release-note.md`,
`docs/history/backfills/v2-phase-10-representative-ui.md`.

`Politici.xcodeproj/project.pbxproj`: not in the diff —
`IPHONEOS_DEPLOYMENT_TARGET` was changed to `17.0` and back to `26.5` in
the working tree only during §4's audit, confirmed via `git diff
Politici.xcodeproj/project.pbxproj` returning empty before this commit
was staged.

No file under `Politici/Data/` (bundled political data) was modified. No
file under `docs/v2/` or the pre-existing `docs/history/` archive was
modified — the only `docs/history/` change is the new `backfills/`
subdirectory, which is additive.
