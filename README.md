# Politica Italia

A local-first iOS prototype for exploring Italian parliamentary politics: sample electoral districts, their representatives, and voting history — rendered on a native MapKit map, entirely offline.

This is a **prototype**. All data (districts, representatives, votes) is fictional sample data generated for demonstration purposes and does not represent real Italian officials or actual parliamentary records. See [Mocked vs. Geocoded Address Flow](#mocked-vs-geocoded-address-flow) below for how location resolution works.

## Tech Stack

- **UI:** SwiftUI, targeting iOS 17+
- **Maps:** Native MapKit for SwiftUI (`Map`, `MapPolygon`, `MapReader`)
- **Architecture:** Local-first, MVVM/Service pattern with dependency injection via the SwiftUI environment
- **Data:** Bundled local JSON/GeoJSON — no backend, no network calls required, no accounts
- **Geocoding:** `CLGeocoder` with a hardcoded fallback table for sample cities
- **Language:** All user-facing strings are in Italian

## Project Structure

```
Politici/
├── App/
│   ├── PoliticiApp.swift          — @main entry point; builds the ServiceContainer and injects it
│   └── ContentView.swift          — Root NavigationStack, hosts HomeView + navigationDestination routing
├── Models/
│   ├── District.swift             — Chamber, Coordinate, District (decodes directly from GeoJSON Features)
│   ├── Representative.swift       — Representative
│   └── Vote.swift                 — VoteChoice, VoteResult, Vote (self-contained yyyy-MM-dd date coding)
├── Services/
│   ├── ServiceContainer.swift     — Bundles all services; SwiftUI EnvironmentKey for injection
│   ├── GeoJSONLoader.swift        — Shared DataLoadingError + LocalJSONLoader helper, GeoJSON parsing, map bounds
│   ├── DistrictService.swift      — Loads districts.geojson; district(for:) resolves a coordinate via ray-casting
│   ├── RepresentativeService.swift — Loads representatives.json; representatives(for districtId:)
│   ├── VoteService.swift          — Loads votes.json; votes(for representativeId:)
│   └── GeocodingService.swift     — CLGeocoder wrapper with hardcoded sample-city fallback
├── Utilities/
│   ├── PointInPolygon.swift       — Ray-casting (even-odd rule) point-in-polygon test
│   └── DateFormatting.swift       — Italian-locale date formatters
├── Views/
│   ├── AppRoute.swift             — Typed NavigationStack destinations
│   ├── HomeView.swift             — Landing screen: search, map CTA, stats, featured representatives
│   ├── MapView.swift              — Interactive map with tappable district polygons
│   ├── AddressSearchView.swift    — Address → coordinate → district resolution flow
│   ├── DistrictDetailView.swift   — District info + representative list (also hosts RepresentativeRow, PartyStyle)
│   ├── RepresentativeProfileView.swift — Representative bio, committees, attendance, recent votes
│   └── VoteHistoryView.swift      — Full vote history (also hosts VoteRow, VoteBadge)
└── Data/
    ├── districts.geojson          — 5 sample electoral districts
    ├── representatives.json       — 14 sample representatives
    └── votes.json                 — 37 sample vote records
```

### Dependency injection

`PoliticiApp` constructs a single `ServiceContainer` (bundling `DistrictService`, `RepresentativeService`, `VoteService`, `GeocodingService`) and injects it into the view hierarchy via `.environment(\.services, services)`. Every view reads it back with `@Environment(\.services) private var services` instead of reaching for a `.shared` singleton directly, so the composition root stays in one place.

## Supported Sample Cities

The prototype ships with **5 sample electoral districts**, each tied to one chamber of Parliament:

| District | Chamber | City |
|---|---|---|
| Roma Centro | Camera dei Deputati | Roma |
| Milano Centro | Camera dei Deputati | Milano |
| Napoli Nord | Camera dei Deputati | Napoli |
| Torino Sud | Senato della Repubblica | Torino |
| Firenze Urban | Senato della Repubblica | Firenze |

Address search and the map are only meaningful within these 5 districts — everywhere else in Italy (and the world) will correctly report as not covered by the prototype.

## Mocked vs. Geocoded Address Flow

`AddressSearchView` resolves free-text input to a district in two steps:

1. **Geocoding** — `GeocodingService.geocode(address:)` first tries `CLGeocoder` (Apple's real, network-backed geocoder). This works normally on a device or simulator with network access.
2. **Hardcoded fallback** — if `CLGeocoder` throws or returns nothing (common in the iOS Simulator when offline, or in sandboxed/CI environments without network access), the service falls back to a **hardcoded coordinate table** for the 5 sample cities (Roma, Milano, Napoli, Torino, Firenze), matched case- and accent-insensitively as a substring (e.g. "Roma Termini" or "milano centro" both resolve).

Once a coordinate is obtained (by either path), it's tested against each district's polygon using the `PointInPolygon` ray-casting algorithm (`Utilities/PointInPolygon.swift`) via `DistrictService.district(for:)`. If no polygon contains the point, the UI shows:

> "Indirizzo non coperto dal prototipo. Prova con una città campione come Roma, Milano o Torino."

`AddressSearchView` also surfaces quick-pick chips for all 5 sample cities so you can test the flow without typing, and without depending on network geocoding at all.

## Running in the Xcode Simulator

1. Open `Politici.xcodeproj` in Xcode 16+ (iOS 17+ SDK required for native `Map`/`MapPolygon`).
2. Select the **Politici** scheme.
3. Choose any iOS 17+ simulator as the run destination (e.g. iPhone 17, iPhone 17 Pro — or any device your installed Xcode ships with).
4. Build & run (`⌘R`).
5. From the Home screen: type or tap a sample city to search, or tap **"Esplora la Mappa Interattiva"** to browse the map and tap a district polygon directly.

### Command-line build check

```bash
xcodebuild -scheme Politici -destination 'platform=iOS Simulator,name=<Simulator Name>' build
```

Replace `<Simulator Name>` with a simulator installed on your machine (check available names with `xcrun simctl list devices available`). The originally-suggested `iPhone 15` is not part of every Xcode installation's device set — substitute whatever simulator ships with your local Xcode/iOS SDK version.

## Roadmap — Prototype v2

This prototype uses fabricated sample data and simplified rectangular district boundaries to demonstrate the app's architecture and UX. A v2 would replace the mocked layers with real data sources:

- **Real parliamentary data APIs** — replace `representatives.json` / `votes.json` with live data from the Camera dei Deputati and Senato della Repubblica open data portals (dati.camera.it, dati.senato.it), including real-time roll-call votes.
- **National Open Data integration** — pull actual attendance, committee membership, and bill status from official sources instead of static bundled JSON.
- **Full national shapefiles** — replace the 5 sample rectangular polygons with real electoral college boundaries (collegi uninominali/plurinominali) sourced from ISTAT or Ministero dell'Interno shapefiles, covering all of Italy rather than 5 sample cities.
- **Persistent caching layer** — introduce SwiftData or a lightweight on-disk cache for API responses, keeping the app usable offline after first sync.
- **Improved geocoding coverage** — remove the hardcoded 5-city fallback once real shapefile coverage makes every Italian address resolvable via `CLGeocoder` + real polygon data.
- **Push notifications for new votes** — notify users when a followed representative casts a new vote, once a live data feed exists.
- **Accessibility & localization pass** — VoiceOver audit, Dynamic Type verification, and potential additional language support beyond Italian.
