//
//  GeocodingTierTests.swift
//  PoliticiTests
//
//  Phase 30 — GeocodingService tier order (docs/v4/30-comuni-geocoding.md),
//  test spec 5: CLGeocoder (tier 1) preferred when present; the comuni table
//  (tier 2) used when tier 1 fails; the five-city fallback (tier 3) intact as
//  the final tier; and a hard failure only when every tier misses. Driven
//  entirely through injected fakes so the order is deterministic and offline.
//

import CoreLocation
import XCTest
@testable import Politici

private struct FakePrimary: AddressResolving {
    let coordinate: CLLocationCoordinate2D?
    func resolve(address: String) async -> CLLocationCoordinate2D? { coordinate }
}

private struct FakeComuni: ComuneLookup {
    var byQuery: [String: [Comune]] = [:]
    func comuni(matching query: String) -> [Comune] { byQuery[query] ?? [] }
}

final class GeocodingTierTests: XCTestCase {
    private let clGeocoderPoint = CLLocationCoordinate2D(latitude: 44.5, longitude: 11.0)
    private let comunePoint = CLLocationCoordinate2D(latitude: 45.79971, longitude: 10.06471)

    func testTier1CLGeocoderWinsWhenAvailable() async throws {
        // Even though the comuni table also has a match, tier 1 must win.
        let comune = Comune(name: "Castro", province: "Bergamo", lat: comunePoint.latitude, lon: comunePoint.longitude)
        let service = GeocodingService(
            primary: FakePrimary(coordinate: clGeocoderPoint),
            comuni: FakeComuni(byQuery: ["Castro": [comune]])
        )
        let result = try await service.geocode(address: "Castro")
        XCTAssertEqual(result.latitude, clGeocoderPoint.latitude, accuracy: 1e-9)
        XCTAssertEqual(result.longitude, clGeocoderPoint.longitude, accuracy: 1e-9)
    }

    func testTier2ComuniTableUsedWhenPrimaryFails() async throws {
        let comune = Comune(name: "Predoi", province: "Bolzano", lat: comunePoint.latitude, lon: comunePoint.longitude)
        let service = GeocodingService(
            primary: FakePrimary(coordinate: nil),
            comuni: FakeComuni(byQuery: ["Predoi": [comune]])
        )
        let result = try await service.geocode(address: "Predoi")
        XCTAssertEqual(result.latitude, comunePoint.latitude, accuracy: 1e-9)
        XCTAssertEqual(result.longitude, comunePoint.longitude, accuracy: 1e-9)
    }

    func testTier3FiveCityFallbackIntactWhenTiers1And2Miss() async throws {
        // Primary fails, comuni table has no match — the retained five-city
        // substring table still resolves "Roma Termini" to Roma.
        let service = GeocodingService(
            primary: FakePrimary(coordinate: nil),
            comuni: FakeComuni(byQuery: [:])
        )
        let result = try await service.geocode(address: "Roma Termini")
        XCTAssertEqual(result.latitude, 41.9028, accuracy: 1e-4)
        XCTAssertEqual(result.longitude, 12.4964, accuracy: 1e-4)
    }

    func testThrowsWhenEveryTierMisses() async {
        let service = GeocodingService(
            primary: FakePrimary(coordinate: nil),
            comuni: FakeComuni(byQuery: [:])
        )
        do {
            _ = try await service.geocode(address: "Luogo Inesistente 12345")
            XCTFail("expected geocode to throw noResults")
        } catch {
            XCTAssertTrue(error is GeocodingError)
        }
    }
}
