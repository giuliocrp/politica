//
//  DecodingTests.swift
//  PoliticiTests
//

import XCTest
@testable import Politici

/// Decodes the real bundled fixtures (via the host app's `Bundle.main`, since
/// this is a hosted unit test target) and checks the counts against the
/// current numbers recorded in docs/v2/01-real-data-import.md (districts and
/// votes are still tracked in docs/v2/00-audit.md, a frozen snapshot). If
/// these fail after a Data/ change, the relevant doc's counts are stale and
/// should be regenerated.
final class DecodingTests: XCTestCase {
    func testDistrictsDecodeWithExpectedCount() throws {
        let districts = try GeoJSONLoader.loadDistricts()
        XCTAssertEqual(districts.count, 5)
    }

    func testRepresentativesDecodeWithExpectedCount() throws {
        // 400 Camera deputies + 201 Senato senators with an active mandate,
        // imported from real open data (tools/import_representatives.py).
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        XCTAssertEqual(representatives.count, 601)
    }

    func testVotesDecodeWithExpectedCount() throws {
        // Data/votes.json ships as an empty, valid schema-v2 collection — the
        // fictional votes live in Data/votes.sample.json now (see
        // testSampleVotesDecodeWithExpectedCount), since they reference the
        // old REP### ids and no real roll-call vote data exists yet.
        let votes = try LocalJSONLoader.decode([Vote].self, fromResource: "votes")
        XCTAssertEqual(votes.count, 0)
    }

    func testSampleVotesDecodeWithExpectedCount() throws {
        let votes = try LocalJSONLoader.decode([Vote].self, fromResource: "votes.sample")
        XCTAssertEqual(votes.count, 37)
    }

    func testDistrictsSpanBothChambers() throws {
        let districts = try GeoJSONLoader.loadDistricts()
        let chambers = Set(districts.map(\.chamber))
        XCTAssertEqual(chambers, [.camera, .senato])
    }

    func testEveryNonNilRepresentativeDistrictReferencesAKnownDistrict() throws {
        // districtId is nil for every representative imported from real open
        // data (not yet mapped to a sample district) and non-nil for the
        // fictional sample dataset. Only the non-nil case should be checked
        // against districts.geojson.
        let districts = try GeoJSONLoader.loadDistricts()
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        let districtIds = Set(districts.map(\.id))
        XCTAssertTrue(representatives.allSatisfy { representative in
            guard let districtId = representative.districtId else { return true }
            return districtIds.contains(districtId)
        })
    }

    // The shipping vote<->representative referential-integrity check is back
    // at full strength in SchemaV2Tests.testShippingVotesReferenceKnownRepresentatives
    // now that Data/votes.json ships empty (vacuously true) instead of
    // referencing stale REP### ids. This test covers the *.sample.* pair,
    // which is still self-contained fictional data with its own REP### ids.
    func testSampleVotesFileUsesConsistentRepresentativeIds() throws {
        let votes = try LocalJSONLoader.decode([Vote].self, fromResource: "votes.sample")
        let voteIds = votes.map(\.id)
        XCTAssertEqual(voteIds.count, Set(voteIds).count, "vote ids must be unique")
        XCTAssertTrue(votes.allSatisfy { $0.representativeId.hasPrefix("REP") })
    }
}
