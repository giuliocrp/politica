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
        // 147 real Camera collegi uninominali (ISTAT) — see
        // docs/v2/03-boundaries-audit.md. The old 5 fictional rectangles
        // are preserved at districts.sample.geojson (see below).
        let districts = try GeoJSONLoader.loadDistricts()
        XCTAssertEqual(districts.count, 147)
    }

    func testSampleDistrictsDecodeWithExpectedCount() throws {
        let districts = try GeoJSONLoader.loadDistricts(resource: "districts.sample")
        XCTAssertEqual(districts.count, 5)
    }

    func testRepresentativesDecodeWithExpectedCount() throws {
        // 400 Camera deputies + 201 Senato senators with an active mandate,
        // imported from real open data (tools/import_representatives.py).
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        XCTAssertEqual(representatives.count, 601)
    }

    func testShippingVotesAreNonEmptyAndWithinBudget() throws {
        // Real votazioni positions imported from dati.camera.it (see
        // docs/v2/04-votes-import.md). Exact count depends on which votes
        // were most recent when 'make fetch' last ran and how many fit
        // under tools/config/votes_scope.json's maxPositionRecords budget,
        // so it isn't asserted exactly here — just that it's non-empty and
        // stays within the budget tools/import_votes.py enforces.
        let votes = try LocalJSONLoader.decode([Vote].self, fromResource: "votes")
        XCTAssertFalse(votes.isEmpty)
        XCTAssertLessThanOrEqual(votes.count, 5000)
    }

    func testSampleVotesDecodeWithExpectedCount() throws {
        let votes = try LocalJSONLoader.decode([Vote].self, fromResource: "votes.sample")
        XCTAssertEqual(votes.count, 37)
    }

    func testSampleDistrictsSpanBothChambers() throws {
        let districts = try GeoJSONLoader.loadDistricts(resource: "districts.sample")
        let chambers = Set(districts.map(\.chamber))
        XCTAssertEqual(chambers, [.camera, .senato])
    }

    /// Senato boundaries are explicitly out of scope for this phase — see
    /// docs/v2/03-boundaries-audit.md. The shipping file should only ever
    /// contain Camera collegi until a future phase adds Senato geometry.
    func testShippingDistrictsAreCameraOnly() throws {
        let districts = try GeoJSONLoader.loadDistricts()
        XCTAssertTrue(districts.allSatisfy { $0.chamber == .camera })
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

    // The shipping vote<->representative referential-integrity check is
    // genuinely (not vacuously) exercised in
    // SchemaV2Tests.testShippingVotesReferenceKnownRepresentatives now that
    // Data/votes.json ships real positions (see docs/v2/04-votes-import.md).
    // This test covers the *.sample.* pair, which is still self-contained
    // fictional data with its own REP### ids.
    func testSampleVotesFileUsesConsistentRepresentativeIds() throws {
        let votes = try LocalJSONLoader.decode([Vote].self, fromResource: "votes.sample")
        let voteIds = votes.map(\.id)
        XCTAssertEqual(voteIds.count, Set(voteIds).count, "vote ids must be unique")
        XCTAssertTrue(votes.allSatisfy { $0.representativeId.hasPrefix("REP") })
    }
}
