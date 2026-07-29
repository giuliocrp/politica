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
        XCTAssertEqual(districtService.district(for: coordinate, chamber: .camera)?.id, "120101")
    }

    func testDistrictForMilanoCoordinateResolvesToRealCollegio() {
        let coordinate = CLLocationCoordinate2D(latitude: 45.4642, longitude: 9.1900)
        XCTAssertEqual(districtService.district(for: coordinate, chamber: .camera)?.id, "30109")
    }

    func testDistrictForNapoliCoordinateResolvesToRealCollegio() {
        let coordinate = CLLocationCoordinate2D(latitude: 40.8518, longitude: 14.2681)
        XCTAssertEqual(districtService.district(for: coordinate, chamber: .camera)?.id, "150102")
    }

    func testDistrictForOpenSeaCoordinateReturnsNilInRealData() {
        let coordinate = CLLocationCoordinate2D(latitude: 40.0, longitude: 10.0)
        XCTAssertNil(districtService.district(for: coordinate, chamber: .camera))
        XCTAssertNil(districtService.district(for: coordinate, chamber: .senato))
    }

    // MARK: - Senato coordinates (Phase 16 — see docs/v3/16-senato-boundaries.md)
    //
    // Expected ids independently verified the same way as the Camera ones
    // above: an even-odd ray-casting rule run directly against
    // Data/districts_senato.geojson in a standalone Python script, not
    // derived from the Swift implementation under test.

    func testDistrictForRomaCoordinateResolvesToRealSenatoCollegio() {
        let coordinate = CLLocationCoordinate2D(latitude: 41.9028, longitude: 12.4964)
        XCTAssertEqual(districtService.district(for: coordinate, chamber: .senato)?.id, "S120002")
    }

    func testDistrictForMilanoCoordinateResolvesToRealSenatoCollegio() {
        let coordinate = CLLocationCoordinate2D(latitude: 45.4642, longitude: 9.1900)
        XCTAssertEqual(districtService.district(for: coordinate, chamber: .senato)?.id, "S30003")
    }

    func testDistrictForNapoliCoordinateResolvesToRealSenatoCollegio() {
        let coordinate = CLLocationCoordinate2D(latitude: 40.8518, longitude: 14.2681)
        XCTAssertEqual(districtService.district(for: coordinate, chamber: .senato)?.id, "S150004")
    }

    // MARK: - MultiPolygon presence (not hypothetical — see docs/v2/03-boundaries-audit.md
    // for Camera, docs/v3/16-senato-boundaries.md for Senato)

    func testShippingDataContainsMultiPolygonDistricts() {
        let multiPartDistricts = districtService.districts.filter { $0.polygons.count > 1 }
        XCTAssertFalse(multiPartDistricts.isEmpty, "expected at least one MultiPolygon collegio (e.g. Sicilia/Sardegna islands)")
    }

    func testBothChambersContainMultiPolygonDistricts() {
        let cameraMultiPart = districtService.allDistricts(chamber: .camera).filter { $0.polygons.count > 1 }
        let senatoMultiPart = districtService.allDistricts(chamber: .senato).filter { $0.polygons.count > 1 }
        XCTAssertFalse(cameraMultiPart.isEmpty, "expected at least one Camera MultiPolygon collegio")
        XCTAssertFalse(senatoMultiPart.isEmpty, "expected at least one Senato MultiPolygon collegio (e.g. Sardegna)")
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

    /// Roughly Italy's bounding box (verified extent — see
    /// docs/v2/03-boundaries-audit.md), including plenty of misses (sea,
    /// foreign territory at the edges) as well as hits. Shared by both
    /// chambers' performance tests below so they exercise the same
    /// coordinate distribution.
    private func italianCoordinates(seed: UInt64) -> [CLLocationCoordinate2D] {
        var generator = SeededGenerator(seed: seed)
        return (0..<1000).map { _ in
            CLLocationCoordinate2D(
                latitude: Double.random(in: 35.0...47.5, using: &generator),
                longitude: Double.random(in: 6.0...19.0, using: &generator)
            )
        }
    }

    func testDistrictForCoordinatePerformanceOverOneThousandItalianCoordinatesCamera() {
        let coordinates = italianCoordinates(seed: 42)

        let start = Date()
        for coordinate in coordinates {
            _ = districtService.district(for: coordinate, chamber: .camera)
        }
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(elapsed, 1.0, "district(for:chamber: .camera) over 1000 coordinates took \(elapsed)s, expected < 1s")
    }

    func testDistrictForCoordinatePerformanceOverOneThousandItalianCoordinatesSenato() {
        let coordinates = italianCoordinates(seed: 42)

        let start = Date()
        for coordinate in coordinates {
            _ = districtService.district(for: coordinate, chamber: .senato)
        }
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(elapsed, 1.0, "district(for:chamber: .senato) over 1000 coordinates took \(elapsed)s, expected < 1s")
    }

    // MARK: - Dual-chamber lookup (Phase 16 — powers AddressSearchView's
    // "Collegio Camera" / "Collegio Senato" pair)

    func testDistrictsContainingResolvesBothChambersForRealCoordinate() {
        let coordinate = CLLocationCoordinate2D(latitude: 41.9028, longitude: 12.4964)
        let matches = districtService.districts(containing: coordinate)
        XCTAssertEqual(matches[.camera]?.id, "120101")
        XCTAssertEqual(matches[.senato]?.id, "S120002")
    }

    func testDistrictsContainingReturnsEmptyForOpenSeaCoordinate() {
        let coordinate = CLLocationCoordinate2D(latitude: 40.0, longitude: 10.0)
        XCTAssertTrue(districtService.districts(containing: coordinate).isEmpty)
    }

    // MARK: - Nested uninominale + containing plurinominale (Phase 25)
    //
    // The same real coordinate resolves to one collegio per (chamber, type)
    // overlay set: a uninominale collegio and the plurinominale collegio that
    // contains it are distinct features in distinct files. All four expected
    // ids were independently verified with a standalone even-odd ray-casting
    // script (matching PointInPolygon) run directly against the four shipping
    // GeoJSON files — see docs/v4/25-plurinominale-geography.md — not derived
    // from the implementation under test.

    func testRomaCoordinateResolvesUninominaleAndItsContainingPlurinominale() {
        let coordinate = CLLocationCoordinate2D(latitude: 41.9028, longitude: 12.4964)
        XCTAssertEqual(districtService.district(for: coordinate, chamber: .camera, collegioType: .uninominale)?.id, "120101")
        XCTAssertEqual(districtService.district(for: coordinate, chamber: .camera, collegioType: .plurinominale)?.id, "CP120101")
        XCTAssertEqual(districtService.district(for: coordinate, chamber: .senato, collegioType: .uninominale)?.id, "S120002")
        XCTAssertEqual(districtService.district(for: coordinate, chamber: .senato, collegioType: .plurinominale)?.id, "SP120001")
    }

    func testResolvedUninominaleAndPlurinominaleShareTheSameCircoscrizione() {
        // Not a tautology: the uninominale collegio and its containing
        // plurinominale collegio come from different files, yet both must
        // report the same Camera circoscrizione for the coordinate.
        let coordinate = CLLocationCoordinate2D(latitude: 41.9028, longitude: 12.4964)
        let uninominale = districtService.district(for: coordinate, chamber: .camera, collegioType: .uninominale)
        let plurinominale = districtService.district(for: coordinate, chamber: .camera, collegioType: .plurinominale)
        XCTAssertEqual(uninominale?.circoscrizione, "Lazio 1")
        XCTAssertEqual(plurinominale?.circoscrizione, "Lazio 1")
    }

    // MARK: - Cold decode measurement (Phase 16 — informs the eager-vs-lazy
    // decision for the Senato bucket; see docs/v3/16-senato-boundaries.md
    // for the recorded numbers and decision). Prints its own measurements
    // (visible in the xcodebuild test log) rather than only asserting a
    // pass/fail bound, since the actual numbers are what the decision is
    // based on, not just whether they clear an arbitrary gate.

    func testColdDecodePerformanceCameraOnlyVsBothChambersEager() {
        let repetitions = 5
        var cameraOnlyTimes: [TimeInterval] = []
        var bothChambersTimes: [TimeInterval] = []

        for _ in 0..<repetitions {
            let cameraStart = Date()
            _ = try? GeoJSONLoader.loadDistricts(resource: "districts")
            cameraOnlyTimes.append(Date().timeIntervalSince(cameraStart))

            let bothStart = Date()
            _ = DistrictService()
            bothChambersTimes.append(Date().timeIntervalSince(bothStart))
        }

        let cameraOnlyMin = cameraOnlyTimes.min() ?? 0
        let bothChambersMin = bothChambersTimes.min() ?? 0
        let ratio = cameraOnlyMin > 0 ? bothChambersMin / cameraOnlyMin : 0

        print("Cold decode (\(repetitions) reps, min of each) — Camera only: \(cameraOnlyMin)s; Camera+Senato eager: \(bothChambersMin)s; ratio: \(ratio)x")
        print("Cold decode all Camera-only samples: \(cameraOnlyTimes)")
        print("Cold decode all Camera+Senato samples: \(bothChambersTimes)")

        // Measured (see docs/v3/16-senato-boundaries.md): ~7.5ms Camera-only
        // vs. ~13.1ms Camera+Senato eager, min of 5 reps — a 1.76x ratio,
        // which technically exceeds the 1.5x decision-rule trigger, but
        // both absolute numbers are imperceptible (well under one 60fps
        // frame) and nowhere near the ~300ms trigger. Decision: stay eager
        // — the ratio is a poor proxy at sub-15ms magnitudes, and lazy
        // loading's added complexity (async load state, loading UI, more
        // tests) isn't justified by a ~6ms difference. This bound catches a
        // genuine regression (e.g. an accidental O(n²) reload), not the
        // actual decision threshold.
        XCTAssertLessThan(bothChambersMin, 0.1, "cold decode of both chambers took \(bothChambersMin)s, expected well under 100ms")
    }
}
