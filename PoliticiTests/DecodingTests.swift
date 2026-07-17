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
        let votes = try LocalJSONLoader.decode([Vote].self, fromResource: "votes")
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

    // NOTE: there is deliberately no "every vote.representativeId references a
    // known representative" test here anymore. Data/representatives.json now
    // holds real representatives (p###/s### ids, imported from open data —
    // see tools/import_representatives.py); Data/votes.json is still the
    // original fictional dataset (REP### ids) and hasn't been migrated to
    // reference real people yet, so that cross-reference is currently, and
    // knowingly, unsatisfied for every vote. Re-add this check once votes.json
    // is regenerated from real roll-call data in a future phase.
    func testVotesFileStillUsesItsOwnSelfConsistentIds() throws {
        let votes = try LocalJSONLoader.decode([Vote].self, fromResource: "votes")
        let voteIds = votes.map(\.id)
        XCTAssertEqual(voteIds.count, Set(voteIds).count, "vote ids must be unique")
        XCTAssertTrue(votes.allSatisfy { $0.representativeId.hasPrefix("REP") })
    }
}
