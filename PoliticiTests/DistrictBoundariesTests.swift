//
//  DistrictBoundariesTests.swift
//  PoliticiTests
//

import CoreLocation
import MapKit
import XCTest
@testable import Politici

/// Coverage for the real ISTAT boundaries phase: resolving known real
/// coordinates against the shipping 147-collegio data, the new
/// MultiPolygon/interior-hole point-in-polygon logic, and the
/// district(for:) performance budget.
final class DistrictBoundariesTests: XCTestCase {
    private let districtService = DistrictService()

    // MARK: - Real coordinates resolving against the real shipping data
    //
    // Expected ids independently verified by running the same even-odd
    // ray-casting rule in a standalone Python script directly against
    // Data/districts.geojson (not derived from the Swift implementation
    // under test) — see docs/v2/03-boundaries-audit.md.

    func testDistrictForRomaCoordinateResolvesToRealCollegio() {
        let coordinate = CLLocationCoordinate2D(latitude: 41.9028, longitude: 12.4964)
        XCTAssertEqual(districtService.district(for: coordinate)?.id, "120101")
    }

    func testDistrictForMilanoCoordinateResolvesToRealCollegio() {
        let coordinate = CLLocationCoordinate2D(latitude: 45.4642, longitude: 9.1900)
        XCTAssertEqual(districtService.district(for: coordinate)?.id, "30109")
    }

    func testDistrictForNapoliCoordinateResolvesToRealCollegio() {
        let coordinate = CLLocationCoordinate2D(latitude: 40.8518, longitude: 14.2681)
        XCTAssertEqual(districtService.district(for: coordinate)?.id, "150102")
    }

    func testDistrictForOpenSeaCoordinateReturnsNilInRealData() {
        let coordinate = CLLocationCoordinate2D(latitude: 40.0, longitude: 10.0)
        XCTAssertNil(districtService.district(for: coordinate))
    }

    // MARK: - MultiPolygon presence (not hypothetical — see docs/v2/03-boundaries-audit.md)

    func testShippingDataContainsMultiPolygonDistricts() {
        let multiPartDistricts = districtService.districts.filter { $0.polygons.count > 1 }
        XCTAssertFalse(multiPartDistricts.isEmpty, "expected at least one MultiPolygon collegio (e.g. Sicilia/Sardegna islands)")
    }

    // MARK: - PointInPolygon: interior holes are excluded

    func testPointInsideExteriorButInsideHoleIsNotContained() {
        let exterior = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0, longitude: 10),
            CLLocationCoordinate2D(latitude: 10, longitude: 10),
            CLLocationCoordinate2D(latitude: 10, longitude: 0)
        ]
        let hole = [
            CLLocationCoordinate2D(latitude: 4, longitude: 4),
            CLLocationCoordinate2D(latitude: 4, longitude: 6),
            CLLocationCoordinate2D(latitude: 6, longitude: 6),
            CLLocationCoordinate2D(latitude: 6, longitude: 4)
        ]
        let holePolygon = MKPolygon(coordinates: hole, count: hole.count)
        let polygonWithHole = MKPolygon(coordinates: exterior, count: exterior.count, interiorPolygons: [holePolygon])

        let pointInsideHole = CLLocationCoordinate2D(latitude: 5, longitude: 5)
        XCTAssertFalse(PointInPolygon.contains(pointInsideHole, in: polygonWithHole))

        let pointInsideExteriorOnly = CLLocationCoordinate2D(latitude: 1, longitude: 1)
        XCTAssertTrue(PointInPolygon.contains(pointInsideExteriorOnly, in: polygonWithHole))

        let pointOutsideEverything = CLLocationCoordinate2D(latitude: 20, longitude: 20)
        XCTAssertFalse(PointInPolygon.contains(pointOutsideEverything, in: polygonWithHole))
    }

    func testContainsInAnyMatchesEitherDisjointPart() {
        let partA = MKPolygon(
            coordinates: [
                CLLocationCoordinate2D(latitude: 0, longitude: 0),
                CLLocationCoordinate2D(latitude: 0, longitude: 1),
                CLLocationCoordinate2D(latitude: 1, longitude: 1),
                CLLocationCoordinate2D(latitude: 1, longitude: 0)
            ],
            count: 4
        )
        let partB = MKPolygon(
            coordinates: [
                CLLocationCoordinate2D(latitude: 50, longitude: 50),
                CLLocationCoordinate2D(latitude: 50, longitude: 51),
                CLLocationCoordinate2D(latitude: 51, longitude: 51),
                CLLocationCoordinate2D(latitude: 51, longitude: 50)
            ],
            count: 4
        )

        XCTAssertTrue(PointInPolygon.contains(CLLocationCoordinate2D(latitude: 0.5, longitude: 0.5), inAny: [partA, partB]))
        XCTAssertTrue(PointInPolygon.contains(CLLocationCoordinate2D(latitude: 50.5, longitude: 50.5), inAny: [partA, partB]))
        XCTAssertFalse(PointInPolygon.contains(CLLocationCoordinate2D(latitude: 25, longitude: 25), inAny: [partA, partB]))
    }

    // MARK: - Performance budget

    /// A small deterministic PRNG so this test is reproducible rather than
    /// depending on real randomness (which would make a rare failure
    /// unreproducible).
    private struct SeededGenerator: RandomNumberGenerator {
        private var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }

    func testDistrictForCoordinatePerformanceOverOneThousandItalianCoordinates() {
        var generator = SeededGenerator(seed: 42)
        // Roughly Italy's bounding box (verified extent — see
        // docs/v2/03-boundaries-audit.md), including plenty of misses
        // (sea, foreign territory at the edges) as well as hits.
        let coordinates: [CLLocationCoordinate2D] = (0..<1000).map { _ in
            CLLocationCoordinate2D(
                latitude: Double.random(in: 35.0...47.5, using: &generator),
                longitude: Double.random(in: 6.0...19.0, using: &generator)
            )
        }

        let start = Date()
        for coordinate in coordinates {
            _ = districtService.district(for: coordinate)
        }
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(elapsed, 1.0, "district(for:) over 1000 coordinates took \(elapsed)s, expected < 1s")
    }
}
