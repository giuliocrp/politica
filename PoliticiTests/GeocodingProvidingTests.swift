//
//  GeocodingProvidingTests.swift
//  PoliticiTests
//

import CoreLocation
import XCTest
@testable import Politici

private struct FakeGeocodingProvider: GeocodingProviding {
    let result: Result<CLLocationCoordinate2D, Error>

    func geocode(address: String) async throws -> CLLocationCoordinate2D {
        try result.get()
    }
}

final class GeocodingProvidingTests: XCTestCase {
    // Data/districts.geojson ships real ISTAT geometry now; these tests
    // exercise the *.sample.* rectangles instead, since "IT-RM-C01" only
    // exists there (real ids are ISTAT numeric codes).
    private let districtService = DistrictService(resource: "districts.sample")

    // MARK: - Five-city offline fallback table (unchanged behavior behind the seam)

    func testFallbackCoordinateResolvesKnownSampleCity() {
        XCTAssertNotNil(GeocodingService.fallbackCoordinate(for: "Roma Termini"))
    }

    func testFallbackCoordinateIsCaseAndAccentInsensitive() {
        XCTAssertNotNil(GeocodingService.fallbackCoordinate(for: "MILANO"))
    }

    func testFallbackCoordinateReturnsNilForUnknownCity() {
        XCTAssertNil(GeocodingService.fallbackCoordinate(for: "Nowhereville"))
    }

    func testGeocodingServiceConformsToGeocodingProviding() {
        let provider: GeocodingProviding = GeocodingService()
        XCTAssertNotNil(provider)
    }

    // MARK: - District resolution driven purely through the GeocodingProviding seam

    func testFakeProviderResolvingRomaCoordinateFindsRomaCentro() async throws {
        let provider: GeocodingProviding = FakeGeocodingProvider(
            result: .success(CLLocationCoordinate2D(latitude: 41.905, longitude: 12.49))
        )
        let coordinate = try await provider.geocode(address: "qualsiasi indirizzo di Roma")
        XCTAssertEqual(districtService.district(for: coordinate)?.id, "IT-RM-C01")
    }

    func testFakeProviderResolvingOpenSeaCoordinateFindsNoDistrict() async throws {
        // Tyrrhenian Sea, well outside every sample district's tiny bounding box.
        let provider: GeocodingProviding = FakeGeocodingProvider(
            result: .success(CLLocationCoordinate2D(latitude: 40.0, longitude: 10.0))
        )
        let coordinate = try await provider.geocode(address: "in mezzo al mare")
        XCTAssertNil(districtService.district(for: coordinate))
    }

    func testFakeProviderPropagatesThrownErrors() async {
        let provider: GeocodingProviding = FakeGeocodingProvider(
            result: .failure(GeocodingError.noResults("indirizzo inventato"))
        )
        do {
            _ = try await provider.geocode(address: "indirizzo inventato")
            XCTFail("expected geocode(address:) to throw")
        } catch {
            XCTAssertTrue(error is GeocodingError)
        }
    }
}
