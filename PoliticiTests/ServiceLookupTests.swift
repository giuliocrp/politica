//
//  ServiceLookupTests.swift
//  PoliticiTests
//

import CoreLocation
import XCTest
@testable import Politici

final class ServiceLookupTests: XCTestCase {
    private let districtService = DistrictService()
    private let representativeService = RepresentativeService()
    private let voteService = VoteService()

    // MARK: - district(for:) — one known in-polygon coordinate per sample city

    func testDistrictForCoordinateResolvesRomaCentro() {
        let coordinate = CLLocationCoordinate2D(latitude: 41.905, longitude: 12.49)
        XCTAssertEqual(districtService.district(for: coordinate)?.id, "IT-RM-C01")
    }

    func testDistrictForCoordinateResolvesMilanoCentro() {
        let coordinate = CLLocationCoordinate2D(latitude: 45.465, longitude: 9.19)
        XCTAssertEqual(districtService.district(for: coordinate)?.id, "IT-MI-C01")
    }

    func testDistrictForCoordinateResolvesTorinoSud() {
        let coordinate = CLLocationCoordinate2D(latitude: 45.045, longitude: 7.69)
        XCTAssertEqual(districtService.district(for: coordinate)?.id, "IT-TO-S01")
    }

    func testDistrictForCoordinateResolvesNapoliNord() {
        let coordinate = CLLocationCoordinate2D(latitude: 40.885, longitude: 14.265)
        XCTAssertEqual(districtService.district(for: coordinate)?.id, "IT-NA-C01")
    }

    func testDistrictForCoordinateResolvesFirenzeUrban() {
        let coordinate = CLLocationCoordinate2D(latitude: 43.775, longitude: 11.255)
        XCTAssertEqual(districtService.district(for: coordinate)?.id, "IT-FI-S01")
    }

    func testDistrictForCoordinateOutsideAllDistrictsReturnsNil() {
        let coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        XCTAssertNil(districtService.district(for: coordinate))
    }

    // MARK: - representatives(for:)

    func testRepresentativesForKnownDistrictIsNonEmpty() {
        let representatives = representativeService.representatives(for: "IT-RM-C01")
        XCTAssertFalse(representatives.isEmpty)
        XCTAssertTrue(representatives.allSatisfy { $0.districtId == "IT-RM-C01" })
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
