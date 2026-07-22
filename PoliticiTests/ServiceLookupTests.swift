//
//  ServiceLookupTests.swift
//  PoliticiTests
//

import CoreLocation
import XCTest
@testable import Politici

final class ServiceLookupTests: XCTestCase {
    // Data/districts.geojson ships real ISTAT geometry now; this suite's
    // known-coordinate-to-known-id tests exercise the *.sample.* rectangles
    // instead, since their ids/bounds are hand-picked and known exactly.
    private let districtService = DistrictService(resources: ["districts.sample"])
    private let representativeService = RepresentativeService()
    // Data/votes.json ships empty (see DecodingTests/SchemaV2Tests); this
    // suite's votes(for:) coverage exercises the *.sample.* fixture instead.
    private let voteService = VoteService(resource: "votes.sample")

    // MARK: - district(for:) — one known in-polygon coordinate per sample city

    func testDistrictForCoordinateResolvesRomaCentro() {
        let coordinate = CLLocationCoordinate2D(latitude: 41.905, longitude: 12.49)
        XCTAssertEqual(districtService.district(for: coordinate, chamber: .camera)?.id, "IT-RM-C01")
    }

    func testDistrictForCoordinateResolvesMilanoCentro() {
        let coordinate = CLLocationCoordinate2D(latitude: 45.465, longitude: 9.19)
        XCTAssertEqual(districtService.district(for: coordinate, chamber: .camera)?.id, "IT-MI-C01")
    }

    func testDistrictForCoordinateResolvesTorinoSud() {
        let coordinate = CLLocationCoordinate2D(latitude: 45.045, longitude: 7.69)
        XCTAssertEqual(districtService.district(for: coordinate, chamber: .senato)?.id, "IT-TO-S01")
    }

    func testDistrictForCoordinateResolvesNapoliNord() {
        let coordinate = CLLocationCoordinate2D(latitude: 40.885, longitude: 14.265)
        XCTAssertEqual(districtService.district(for: coordinate, chamber: .camera)?.id, "IT-NA-C01")
    }

    func testDistrictForCoordinateResolvesFirenzeUrban() {
        let coordinate = CLLocationCoordinate2D(latitude: 43.775, longitude: 11.255)
        XCTAssertEqual(districtService.district(for: coordinate, chamber: .senato)?.id, "IT-FI-S01")
    }

    func testDistrictForCoordinateOutsideAllDistrictsReturnsNil() {
        let coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        XCTAssertNil(districtService.district(for: coordinate, chamber: .camera))
        XCTAssertNil(districtService.district(for: coordinate, chamber: .senato))
    }

    func testAllDistrictsFilterByChamberAndCollegioTypeOnSampleFixture() {
        // districts.sample.geojson mixes chambers AND collegio types in ONE
        // file (Phase 25): 3 Camera + 2 Senato uninominali, plus 1 Camera + 1
        // Senato plurinominale — so this exercises DistrictService bucketing
        // by each feature's own (chamber, collegioType), not by file.
        let cameraUni = districtService.allDistricts(chamber: .camera, collegioType: .uninominale)
        XCTAssertEqual(Set(cameraUni.map(\.id)), ["IT-RM-C01", "IT-MI-C01", "IT-NA-C01"])
        let cameraPluri = districtService.allDistricts(chamber: .camera, collegioType: .plurinominale)
        XCTAssertEqual(cameraPluri.map(\.id), ["IT-RM-CP01"])
        let senatoUni = districtService.allDistricts(chamber: .senato, collegioType: .uninominale)
        XCTAssertEqual(Set(senatoUni.map(\.id)), ["IT-TO-S01", "IT-FI-S01"])
        let senatoPluri = districtService.allDistricts(chamber: .senato, collegioType: .plurinominale)
        XCTAssertEqual(senatoPluri.map(\.id), ["IT-TO-SP01"])
        // The uninominale-only count across chambers (5) and the all-types
        // total (7) come from the same loaded set, bucketed differently.
        XCTAssertEqual(districtService.allDistricts(collegioType: .uninominale).count, 5)
        XCTAssertEqual(districtService.allDistricts().count, 7)
    }

    func testSampleFixtureNestedUninominaleAndPlurinominaleForOneCoordinate() {
        // The Camera plurinominale sample rectangle (IT-RM-CP01) contains the
        // Roma Centro uninominale rectangle (IT-RM-C01); one coordinate inside
        // both resolves to each within its own overlay set — the sample-fixture
        // twin of the real-data nested test in DistrictBoundariesTests.
        let roma = CLLocationCoordinate2D(latitude: 41.905, longitude: 12.49)
        XCTAssertEqual(districtService.district(for: roma, chamber: .camera, collegioType: .uninominale)?.id, "IT-RM-C01")
        XCTAssertEqual(districtService.district(for: roma, chamber: .camera, collegioType: .plurinominale)?.id, "IT-RM-CP01")
    }

    func testDistrictsContainingBucketsByChamberOnMixedSampleFixture() {
        // districts.sample.geojson deliberately mixes chambers (and, since
        // Phase 25, collegio types) in ONE file — this exercises
        // DistrictService's chamber bucketing being driven by each feature's
        // own `chamber` property, not by which file/resource it loaded from.
        // districts(containing:) is uninominale-scoped, so it returns the
        // uninominale collegio even where a plurinominale one also contains
        // the point.
        let torinoSud = CLLocationCoordinate2D(latitude: 45.045, longitude: 7.69)
        let matches = districtService.districts(containing: torinoSud)
        XCTAssertNil(matches[.camera], "Torino Sud is a Senato-only sample district")
        XCTAssertEqual(matches[.senato]?.id, "IT-TO-S01")

        let romaCentro = CLLocationCoordinate2D(latitude: 41.905, longitude: 12.49)
        let romaMatches = districtService.districts(containing: romaCentro)
        XCTAssertEqual(romaMatches[.camera]?.id, "IT-RM-C01")
        XCTAssertNil(romaMatches[.senato], "Roma Centro is a Camera-only sample district")
    }

    // MARK: - representatives(for:)

    func testRepresentativesForDistrictOnlyReturnsMatchingIds() {
        // "IT-RM-C01" is a fictional sample id, so against the shipping
        // data this correctly returns empty — the assertion exercises the
        // actual filter predicate rather than a hardcoded expectation
        // about today's data shape.
        let representatives = representativeService.representatives(for: "IT-RM-C01")
        XCTAssertTrue(representatives.allSatisfy { $0.districtId == "IT-RM-C01" })
    }

    func testRepresentativesForDistrictInSampleFixtureIsNonEmpty() {
        // The *.sample.* pair still has districtId assigned, so this
        // exercises the actual non-empty, correctly-filtered positive case
        // that the shipping-data version above currently can't (see above).
        let sampleService = RepresentativeService(resource: "representatives.sample")
        let representatives = sampleService.representatives(for: "IT-RM-C01")
        XCTAssertFalse(representatives.isEmpty)
        XCTAssertTrue(representatives.allSatisfy { $0.districtId == "IT-RM-C01" })
    }

    func testRepresentativesForSenatoDistrictInSampleFixtureIsNonEmpty() {
        // Phase 17's Senato linkage surfaces senators through the very same
        // representatives(for:) path DistrictDetailView already uses for
        // deputies — exercised here on the fixture's fictional Senato
        // district, whose membership is hand-known.
        let sampleService = RepresentativeService(resource: "representatives.sample")
        let representatives = sampleService.representatives(for: "IT-TO-S01")
        XCTAssertFalse(representatives.isEmpty)
        XCTAssertTrue(representatives.allSatisfy { $0.districtId == "IT-TO-S01" && $0.chamber == .senato })
    }

    func testRepresentativesForUnknownDistrictIsEmpty() {
        XCTAssertTrue(representativeService.representatives(for: "NOT-A-REAL-DISTRICT").isEmpty)
    }

    // MARK: - votes(for:)

    func testVotesForRepresentativeAreSortedNewestFirst() {
        let votes = voteService.votes(for: "REP001")
        XCTAssertFalse(votes.isEmpty)
        let dates = votes.map(\.date)
        XCTAssertEqual(dates, dates.sorted(by: >))
    }

    func testVotesForRepresentativeAreAllAttributedToThatRepresentative() {
        let votes = voteService.votes(for: "REP001")
        XCTAssertTrue(votes.allSatisfy { $0.representativeId == "REP001" })
    }
}
