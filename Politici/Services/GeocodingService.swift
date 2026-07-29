//
//  GeocodingService.swift
//  Politici
//

import CoreLocation
import Foundation

enum GeocodingError: LocalizedError {
    case noResults(String)

    var errorDescription: String? {
        switch self {
        case .noResults(let address):
            return "Nessun risultato per l'indirizzo \"\(address)\"."
        }
    }
}

/// Seam between address-resolution callers (views) and the concrete geocoding
/// implementation, so tests can inject a fake provider instead of exercising
/// `CLGeocoder`/on-device search services.
protocol GeocodingProviding {
    func geocode(address: String) async throws -> CLLocationCoordinate2D
}

/// The first (address-level) geocoding tier, factored behind a protocol so the
/// tier order can be tested deterministically without a live `CLGeocoder`.
protocol AddressResolving {
    /// A coordinate for `address`, or `nil` when the tier can't resolve it
    /// (offline, no match). Never throws — a failure just falls through to the
    /// next tier.
    func resolve(address: String) async -> CLLocationCoordinate2D?
}

/// Production first tier: `CLGeocoder`. `CLGeocoder` is slated for deprecation
/// on newer Apple SDKs in favor of MapKit's `MKGeocodingRequest`; keeping it
/// behind `AddressResolving` is the migration seam — swapping the
/// implementation later (or branching by OS version) won't touch
/// `GeocodingService` or its call sites, which keeps the app's iOS 17 minimum
/// deployment target.
struct CLGeocoderResolver: AddressResolving {
    private let geocoder: CLGeocoder

    init(geocoder: CLGeocoder = CLGeocoder()) {
        self.geocoder = geocoder
    }

    func resolve(address: String) async -> CLLocationCoordinate2D? {
        if let placemarks = try? await geocoder.geocodeAddressString(address),
           let coordinate = placemarks.first?.location?.coordinate {
            return coordinate
        }
        return nil
    }
}

/// Resolves a free-text address to a coordinate through three tiers, in order:
///
///   1. **`CLGeocoder`** (the injected `AddressResolving`) — full address-level
///      geocoding; wins whenever it's available (i.e. online), so an actual
///      street address never regresses to a coarser tier.
///   2. **the bundled comuni table** (`ComuneLookup`, v4 Phase 30) — ~7,900
///      Italian comuni resolved offline by exact name; replaces the old
///      five-city ceiling for whole-comune queries.
///   3. **the five-city fallback table** — retained as the final tier, and
///      still the only tier that does *substring* matching, so "Roma Termini"
///      resolves to Roma's city coordinate even when tiers 1–2 both miss.
///
/// `geocode(address:)` returns a single coordinate (for homonym comuni it
/// returns the first candidate deterministically). The UI disambiguates
/// homonyms up front via `ComuneService.comuni(matching:)` before ever calling
/// this — see `AddressSearchView`.
final class GeocodingService: GeocodingProviding {
    static let shared = GeocodingService()

    /// The service the app actually runs with (see `ServiceContainer.live`).
    /// In release builds this is always `shared`, i.e. `CLGeocoder`-backed.
    /// In DEBUG it additionally honors the Phase 30B UI-test launch argument
    /// — see `uiTestPrimaryResolver()`.
    static var live: GeocodingService {
        #if DEBUG
        if let stub = uiTestPrimaryResolver() {
            return GeocodingService(primary: stub)
        }
        #endif
        return shared
    }

    #if DEBUG
    /// UI-test seam (Phase 30B): launching the app with
    /// `-stubAddressResolver 1` replaces the `CLGeocoder` tier with one that
    /// resolves nothing, immediately.
    ///
    /// This is what finally bounds UI flow 7's wait, open since Phase 24
    /// (docs/v4/24-ui-tests.md §6.3): `GeocodingService` always *tries*
    /// `CLGeocoder` first, and on a simulator with no route out that attempt
    /// was measured taking anywhere from ~1 s to over 120 s to fail, forcing
    /// the test to carry a 300 s ceiling. Stubbing the tier removes the wait
    /// from the test instead of putting a timeout into the product — the
    /// production `CLGeocoder` behaviour is deliberately left alone here and
    /// stays with Phase 32A.
    ///
    /// Reuses the `AddressResolving` injection seam Phase 30 added rather
    /// than adding a second one, and mirrors
    /// `UserDefaultsFavoritesStore.uiTestSuite()`: read through `.standard`
    /// because `-key value` launch arguments land in `UserDefaults`' argument
    /// domain, compiled out of release builds entirely, and inert in DEBUG
    /// unless the argument is passed.
    static func uiTestPrimaryResolver() -> AddressResolving? {
        guard UserDefaults.standard.bool(forKey: "stubAddressResolver") else { return nil }
        return StubAddressResolver()
    }

    /// Resolves nothing, instantly — so tiers 2/3 decide the outcome and no
    /// UI test ever waits on a network geocode.
    private struct StubAddressResolver: AddressResolving {
        func resolve(address: String) async -> CLLocationCoordinate2D? { nil }
    }
    #endif

    private let primary: AddressResolving
    private let comuni: ComuneLookup?

    /// Hardcoded coordinates for the five sample cities, keyed by folded name.
    /// Deliberately curated points (each verified to resolve against the
    /// shipped collegi), independent of the comuni table.
    private static let fallbackCoordinates: [String: CLLocationCoordinate2D] = [
        "roma": CLLocationCoordinate2D(latitude: 41.9028, longitude: 12.4964),
        "milano": CLLocationCoordinate2D(latitude: 45.4642, longitude: 9.1900),
        "napoli": CLLocationCoordinate2D(latitude: 40.8518, longitude: 14.2681),
        "torino": CLLocationCoordinate2D(latitude: 45.0703, longitude: 7.6869),
        "firenze": CLLocationCoordinate2D(latitude: 43.7696, longitude: 11.2558)
    ]

    init(
        primary: AddressResolving = CLGeocoderResolver(),
        comuni: ComuneLookup? = ComuneService.shared
    ) {
        self.primary = primary
        self.comuni = comuni
    }

    /// Resolves `address` through the three tiers above, throwing
    /// `GeocodingError.noResults` only when every tier misses.
    func geocode(address: String) async throws -> CLLocationCoordinate2D {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GeocodingError.noResults(address)
        }

        // Tier 1 — CLGeocoder (address-level) wins when available.
        if let coordinate = await primary.resolve(address: trimmed) {
            return coordinate
        }

        // Tier 2 — bundled comuni table (offline, exact comune name).
        if let coordinate = comuneCoordinate(for: trimmed) {
            return coordinate
        }

        // Tier 3 — five-city substring fallback (retained).
        if let fallback = Self.fallbackCoordinate(for: trimmed) {
            return fallback
        }

        throw GeocodingError.noResults(address)
    }

    /// Tier 2 adapter: the comuni table matches on an exact comune name, so try
    /// the whole query and its first comma-separated component ("Bolzano, Via
    /// del Corso" → "Bolzano"). Homonyms resolve to the first candidate here;
    /// the UI's up-front disambiguation is what surfaces the alternatives.
    private func comuneCoordinate(for address: String) -> CLLocationCoordinate2D? {
        guard let comuni else { return nil }
        let firstComponent = address.split(separator: ",", maxSplits: 1).first.map(String.init) ?? address
        for candidate in [address, firstComponent] {
            if let comune = comuni.comuni(matching: candidate).first {
                return comune.coordinate
            }
        }
        return nil
    }

    /// Case- and accent-insensitive **substring** lookup against the five
    /// sample cities, so "Roma Termini" or "milano centro" still resolve to
    /// their city coordinate.
    static func fallbackCoordinate(for address: String) -> CLLocationCoordinate2D? {
        let normalized = NameFolding.fold(address)
        return fallbackCoordinates.first { key, _ in normalized.contains(key) }?.value
    }
}
