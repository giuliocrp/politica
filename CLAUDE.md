# CLAUDE.md

## Project Purpose

Politica (display name "Politica"; Xcode project/target/scheme name "Politici")
is a local-first iOS prototype for exploring Italian parliamentary civic
information — sample electoral districts, their representatives, and voting
history, rendered on a native MapKit map entirely offline. It is a prototype
built on fictional sample data to demonstrate the app's architecture and UX,
not a source of real political information.

## Standing Constraints

These apply to this and all future phases of work on this repository:

1. Never rename the Xcode project, target, scheme, or bundle identifier.
2. All user-facing strings must be in Italian.
3. The app is local-first: no networking code, no backend, no analytics.
4. Never present fictional/sample data as real. Never fabricate "real-looking"
   political data.

## Build Command

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Politici.xcodeproj -scheme Politici -destination 'generic/platform=iOS Simulator' build
```

## Data Files

`Politici/Data/districts.geojson`, `Politici/Data/representatives.json`, and
`Politici/Data/votes.json` are treated as **generated artifacts in v2**. Do
not hand-edit them directly once a `tools/` generation pipeline exists —
regenerate them through that pipeline instead. (As of this audit, no such
pipeline exists yet; see `docs/v2/00-audit.md`.)

## File Layout Conventions

```
Politici/
├── App/          — @main entry point and root NavigationStack/view
├── Models/        — Codable domain types (District, Representative, Vote)
├── Services/      — data loading, lookups, geocoding; injected via ServiceContainer
├── Utilities/     — pure helpers (PointInPolygon, DateFormatting) with no service state
├── Views/         — SwiftUI screens, one file per screen; typed navigation via AppRoute
└── Data/          — bundled JSON/GeoJSON fixtures (see "Data Files" above)
```

- Services are accessed through the SwiftUI environment (`@Environment(\.services)`),
  not via ad hoc singletons reached for directly from views.
- Small view components shared by exactly two related screens live alongside
  their primary consumer (e.g. `RepresentativeRow` in `DistrictDetailView.swift`,
  `VoteRow`/`VoteBadge` in `VoteHistoryView.swift`) rather than in a separate
  "shared components" file.
- Design/process notes for v2 work live under `docs/v2/`.
