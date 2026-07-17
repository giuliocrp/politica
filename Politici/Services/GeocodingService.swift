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

/// Resolves a free-text address to a coordinate using `CLGeocoder`, falling back to a
/// hardcoded lookup table for the app's sample cities when geocoding fails or is
/// unavailable (e.g. offline in the Simulator).
///
/// `CLGeocoder` is slated for deprecation on newer Apple SDKs in favor of
/// MapKit's `MKGeocodingRequest`. This class deliberately stays on `CLGeocoder`
/// so the app keeps its current iOS 17 minimum deployment target, but callers
/// depend on `GeocodingProviding` rather than this concrete type — that's the
/// migration seam: swapping the implementation later (or branching by OS
/// version) won't require touching call sites.
final class GeocodingService: GeocodingProviding {
    static let shared = GeocodingService()

    private let geocoder: CLGeocoder

    /// Hardcoded coordinates for the sample cities, keyed by lowercase, accent-stripped name.
    private static let fallbackCoordinates: [String: CLLocationCoordinate2D] = [
        "roma": CLLocationCoordinate2D(latitude: 41.9028, longitude: 12.4964),
        "milano": CLLocationCoordinate2D(latitude: 45.4642, longitude: 9.1900),
        "napoli": CLLocationCoordinate2D(latitude: 40.8518, longitude: 14.2681),
        "torino": CLLocationCoordinate2D(latitude: 45.0703, longitude: 7.6869),
        "firenze": CLLocationCoordinate2D(latitude: 43.7696, longitude: 11.2558)
    ]

    init(geocoder: CLGeocoder = CLGeocoder()) {
        self.geocoder = geocoder
    }

    /// Resolves `address` to a coordinate, trying `CLGeocoder` first and falling back
    /// to the hardcoded sample-city table if that fails or finds nothing.
    func geocode(address: String) async throws -> CLLocationCoordinate2D {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GeocodingError.noResults(address)
        }

        if let placemarks = try? await geocoder.geocodeAddressString(trimmed),
           let coordinate = placemarks.first?.location?.coordinate {
            return coordinate
        }

        if let fallback = Self.fallbackCoordinate(for: trimmed) {
            return fallback
        }

        throw GeocodingError.noResults(address)
    }

    /// Case- and accent-insensitive substring lookup against the hardcoded sample cities,
    /// so "Roma Termini" or "milano centro" still resolve to their city coordinate.
    static func fallbackCoordinate(for address: String) -> CLLocationCoordinate2D? {
        let normalized = address.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "it_IT")
        )
        return fallbackCoordinates.first { key, _ in normalized.contains(key) }?.value
    }
}
