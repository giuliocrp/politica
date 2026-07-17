//
//  DecodingTests.swift
//  PoliticiTests
//

import XCTest
@testable import Politici

/// Decodes the real bundled fixtures (via the host app's `Bundle.main`, since
/// this is a hosted unit test target) and checks the counts against the
/// current audit numbers recorded in docs/v2/00-audit.md. If these fail after
/// a Data/ change, the audit doc's counts are stale and should be regenerated.
final class DecodingTests: XCTestCase {
    func testDistrictsDecodeWithExpectedCount() throws {
        let districts = try GeoJSONLoader.loadDistricts()
        XCTAssertEqual(districts.count, 5)
    }

    func testRepresentativesDecodeWithExpectedCount() throws {
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        XCTAssertEqual(representatives.count, 14)
    }

    func testVotesDecodeWithExpectedCount() throws {
        let votes = try LocalJSONLoader.decode([Vote].self, fromResource: "votes")
        XCTAssertEqual(votes.count, 37)
    }

    func testDistrictsSpanBothChambers() throws {
        let districts = try GeoJSONLoader.loadDistricts()
        let chambers = Set(districts.map(\.chamber))
        XCTAssertEqual(chambers, [.camera, .senato])
    }

    func testEveryRepresentativeReferencesAKnownDistrict() throws {
        let districts = try GeoJSONLoader.loadDistricts()
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        let districtIds = Set(districts.map(\.id))
        XCTAssertTrue(representatives.allSatisfy { districtIds.contains($0.districtId) })
    }

    func testEveryVoteReferencesAKnownRepresentative() throws {
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        let votes = try LocalJSONLoader.decode([Vote].self, fromResource: "votes")
        let representativeIds = Set(representatives.map(\.id))
        XCTAssertTrue(votes.allSatisfy { representativeIds.contains($0.representativeId) })
    }
}
