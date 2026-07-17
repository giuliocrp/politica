# v2 Audit — Baseline Repository State

Audit performed at the start of the v2 branch, before any source changes. This
document is a snapshot; it is not updated as v2 work proceeds (see later
`docs/v2/NN-*.md` files for that).

## Directory Tree

```
Politici/                              (repo root)
├── .gitignore
├── README.md
├── icon.png                           — source icon supplied for AppIcon
├── Politici.xcodeproj/
├── Politici/                          (app target source root)
│   ├── App/
│   │   ├── PoliticiApp.swift          — @main entry point, builds ServiceContainer
│   │   └── ContentView.swift          — root NavigationStack + route dispatch
│   ├── Models/
│   │   ├── District.swift
│   │   ├── Representative.swift
│   │   └── Vote.swift
│   ├── Services/
│   │   ├── ServiceContainer.swift
│   │   ├── GeoJSONLoader.swift
│   │   ├── DistrictService.swift
│   │   ├── RepresentativeService.swift
│   │   ├── VoteService.swift
│   │   └── GeocodingService.swift
│   ├── Utilities/
│   │   ├── PointInPolygon.swift
│   │   └── DateFormatting.swift
│   ├── Views/
│   │   ├── AppRoute.swift
│   │   ├── HomeView.swift
│   │   ├── MapView.swift
│   │   ├── AddressSearchView.swift
│   │   ├── DistrictDetailView.swift
│   │   ├── RepresentativeProfileView.swift
│   │   └── VoteHistoryView.swift
│   ├── Data/
│   │   ├── districts.geojson
│   │   ├── representatives.json
│   │   └── votes.json
│   └── Assets.xcassets/
│       ├── AppIcon.appiconset/ (icon.png + Contents.json)
│       ├── AccentColor.colorset/
│       └── Contents.json
├── PoliticiTests/
│   └── PoliticiTests.swift            — Swift Testing template, no real tests
├── PoliticiUITests/
│   ├── PoliticiUITests.swift          — XCTest UI template, no real tests
│   └── PoliticiUITestsLaunchTests.swift
└── .claude/
    └── settings.local.json            — local Claude Code permission allowlist (untracked)
```

## Targets & Schemes

`xcodebuild -list -project Politici.xcodeproj`:

- **Targets:** `Politici` (app), `PoliticiTests`, `PoliticiUITests`
- **Build configurations:** `Debug`, `Release`
- **Schemes:** `Politici` (only one scheme; default build configuration if unspecified is `Release`)

## Deployment Target

- `IPHONEOS_DEPLOYMENT_TARGET = 26.5` at the project level, inherited by all three targets (no target overrides this).
- **Surprising:** the original spec called for "iOS 17+" as the minimum, and the codebase uses no APIs newer than iOS 17 (`Map`/`MapPolygon`/`MapReader`, `NavigationStack`, `ContentUnavailableView`). The deployment target of 26.5 is simply whatever this machine's Xcode/SDK defaulted to when the project was created via the standard template — it is not an intentional floor of "iOS 26.5 required." This should be lowered to iOS 17.0 if the app is meant to run on real-world current devices rather than only the newest simulators.

## Test Target Status

Both `PoliticiTests` and `PoliticiUITests` exist as build targets and compile, but contain **only unmodified Xcode template boilerplate**:

- `PoliticiTests.swift` — one empty `@Test func example()` (Swift Testing framework), no assertions.
- `PoliticiUITests.swift` — template `testExample()` (empty) and `testLaunchPerformance()` (measures launch only).
- `PoliticiUITestsLaunchTests.swift` — template launch-screenshot test.

**No real test coverage exists for any app code** (Models, Services, Utilities, or Views). All verification to date has been manual: standalone compiled decode/logic harnesses run outside the test target, plus `xcodebuild` build checks and simulator screenshots.

## Data Record Counts

Counted via `python3 -c "import json; ..."` against the live files in `Politici/Data/`:

| File | Records | Notes |
|---|---|---|
| `districts.geojson` | **5** features | 3× `Camera` (Roma Centro, Milano Centro, Napoli Nord), 2× `Senato` (Torino Sud, Firenze Urban) |
| `representatives.json` | **14** | spans 7 fictional party labels: Fratelli d'Italia, Partito Democratico, Movimento 5 Stelle, Lega, Forza Italia, Alleanza Verdi e Sinistra, Azione - Italia Viva |
| `votes.json` | **37** | linked to representatives via `representativeId` |

All three files are hand-authored fixtures, not derived from any external source or pipeline.

## Anything Else Surprising

- **No `.pbxproj` test-target wiring issues found** — both test targets build cleanly against the `Politici` app target (`@testable import Politici` resolves).
- **`.claude/settings.local.json`** exists at the repo root (a local Claude Code tool-permission allowlist) and is correctly **untracked** by git — no action needed, but noting its presence since it's not part of the app itself.
- **Single scheme, single app target** — there is no separate "v2" scheme/target/configuration yet; v2 work will happen in-place on this same `Politici` target unless a future phase decides otherwise.
- **`Data/` files are hand-written JSON/GeoJSON with no generating pipeline** — there is currently no `tools/` directory or script that produces them; per this phase's instructions, v2 treats them as generated artifacts to be edited only via a future pipeline, but that pipeline does not exist yet.
- **README.md's "Roadmap — Prototype v2" section already sketches** the real-data/shapefile/caching direction this audit is the starting point for — worth keeping in sync as v2 progresses.
