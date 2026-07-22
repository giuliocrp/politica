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
        // 7 fictional rectangles since Phase 25 extended the fixture with two
        // plurinominale collegi (IT-RM-CP01 / IT-TO-SP01) alongside the five
        // uninominale ones — see docs/v4/25-plurinominale-geography.md.
        let districts = try GeoJSONLoader.loadDistricts(resource: "districts.sample")
        XCTAssertEqual(districts.count, 7)
    }

    func testSenatoDistrictsDecodeWithExpectedCount() throws {
        // 74 real Senato collegi uninominali (ISTAT) — Phase 16, see
        // docs/v3/16-senato-boundaries.md. Verified via ogrinfo in
        // docs/v3/15-senato-exploration.md's source exploration.
        let districts = try GeoJSONLoader.loadDistricts(resource: "districts_senato")
        XCTAssertEqual(districts.count, 74)
    }

    func testCameraPlurinominaleDistrictsDecodeWithExpectedCount() throws {
        // 49 real Camera collegi plurinominali (ISTAT) — Phase 25; the raw
        // ISTAT layer's 50th feature is a null-attribute Valle d'Aosta
        // placeholder dropped at import (see docs/v4/25-plurinominale-geography.md).
        let districts = try GeoJSONLoader.loadDistricts(resource: "districts_plurinominali_camera")
        XCTAssertEqual(districts.count, 49)
        XCTAssertTrue(districts.allSatisfy { $0.chamber == .camera })
        XCTAssertTrue(districts.allSatisfy { $0.collegioType == .plurinominale })
        XCTAssertTrue(districts.allSatisfy { $0.id.hasPrefix("CP") })
        XCTAssertTrue(districts.allSatisfy { ($0.circoscrizione?.isEmpty == false) })
        XCTAssertTrue(districts.allSatisfy { $0.regione == nil })
    }

    func testSenatoPlurinominaleDistrictsDecodeWithExpectedCount() throws {
        // 26 real Senato collegi plurinominali (ISTAT) — Phase 25; the 27th
        // raw feature is a Valle d'Aosta + Trentino-Alto Adige placeholder,
        // dropped at import.
        let districts = try GeoJSONLoader.loadDistricts(resource: "districts_plurinominali_senato")
        XCTAssertEqual(districts.count, 26)
        XCTAssertTrue(districts.allSatisfy { $0.chamber == .senato })
        XCTAssertTrue(districts.allSatisfy { $0.collegioType == .plurinominale })
        XCTAssertTrue(districts.allSatisfy { $0.id.hasPrefix("SP") })
        XCTAssertTrue(districts.allSatisfy { ($0.regione?.isEmpty == false) })
        XCTAssertTrue(districts.allSatisfy { $0.circoscrizione == nil })
    }

    func testRepresentativesDecodeWithExpectedCount() throws {
        // 400 Camera deputies + 201 Senato senators with an active mandate,
        // imported from real open data (tools/import_representatives.py).
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        XCTAssertEqual(representatives.count, 601)
    }

    func testShippingVotesAreNonEmptyAndWithinBudget() throws {
        // Real votazioni positions imported from dati.camera.it (see
        // docs/v2/04-votes-import.md; normalized schema since Phase 20 —
        // docs/v3/20-vote-browsing.md). Exact count depends on the Phase 27
        // stratified selection (docs/v4/27-votes-stratified.md) and how many
        // fit under tools/config/votes_scope.json's maxPositionRecords budget
        // (raised to 13000 for the 30-event sample), so it isn't asserted
        // exactly here — just that it's non-empty and within that budget, the
        // real gate being the 2 MiB file size import_votes.py/validate enforce.
        let votesFile = try LocalJSONLoader.decode(VotesFile.self, fromResource: "votes")
        XCTAssertFalse(votesFile.positions.isEmpty)
        XCTAssertLessThanOrEqual(votesFile.positions.count, 13000)
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

    /// districts.geojson (the default "districts" resource) is Camera's own
    /// dedicated boundary file — Senato boundaries were explicitly out of
    /// scope when this file was built (docs/v2/03-boundaries-audit.md) and
    /// still ship in a SEPARATE file (districts_senato.geojson, Phase 16 —
    /// see testSenatoDistrictsAreSenatoOnly below) rather than being merged
    /// in here, so this file should stay Camera-only indefinitely.
    func testShippingDistrictsAreCameraOnly() throws {
        let districts = try GeoJSONLoader.loadDistricts()
        XCTAssertTrue(districts.allSatisfy { $0.chamber == .camera })
    }

    func testSenatoDistrictsAreSenatoOnly() throws {
        let districts = try GeoJSONLoader.loadDistricts(resource: "districts_senato")
        XCTAssertTrue(districts.allSatisfy { $0.chamber == .senato })
    }

    func testSenatoDistrictIdsAreSPrefixedWithRegioneAndNoCircoscrizione() throws {
        // "S" prefix applied unconditionally at import time (32/74 ids
        // would otherwise collide with real Camera ids — see
        // docs/v3/15-senato-exploration.md's collision check); regione
        // (not circoscrizione) is Senato's grouping property — see
        // District.swift and docs/v3/16-senato-boundaries.md.
        let districts = try GeoJSONLoader.loadDistricts(resource: "districts_senato")
        XCTAssertTrue(districts.allSatisfy { $0.id.hasPrefix("S") })
        XCTAssertTrue(districts.allSatisfy { ($0.regione?.isEmpty == false) })
        XCTAssertTrue(districts.allSatisfy { ($0.subCode?.isEmpty == false) })
        XCTAssertTrue(districts.allSatisfy { $0.circoscrizione == nil })
    }

    func testCameraDistrictsHaveNoRegione() throws {
        let districts = try GeoJSONLoader.loadDistricts()
        XCTAssertTrue(districts.allSatisfy { $0.regione == nil })
    }

    func testCameraAndSenatoDistrictIdsAreAllUnique() throws {
        // 147 + 74 = 221 unique ids across the two boundary files — the
        // Swift-side twin of tools/validate_data.py's cross-file id
        // uniqueness check (Phase 16).
        let camera = try GeoJSONLoader.loadDistricts()
        let senato = try GeoJSONLoader.loadDistricts(resource: "districts_senato")
        let allIds = camera.map(\.id) + senato.map(\.id)
        XCTAssertEqual(allIds.count, 221)
        XCTAssertEqual(Set(allIds).count, 221, "no id should be shared between districts.geojson and districts_senato.geojson")
    }

    func testAllFourBoundaryFilesHaveGloballyUniqueIds() throws {
        // 147 + 74 + 49 + 26 = 296 unique ids across all four boundary files
        // (Phase 25) — the Swift-side twin of validate_data.py's four-file
        // cross-uniqueness check. The unconditional prefixes (bare numeric /
        // "S" / "CP" / "SP") guarantee no id aliases two distinct collegi.
        let allIds = try ["districts", "districts_senato",
                          "districts_plurinominali_camera", "districts_plurinominali_senato"]
            .flatMap { try GeoJSONLoader.loadDistricts(resource: $0).map(\.id) }
        XCTAssertEqual(allIds.count, 296)
        XCTAssertEqual(Set(allIds).count, 296, "no id may be shared across the four boundary files")
    }

    func testEveryNonNilRepresentativeDistrictReferencesAKnownDistrict() throws {
        // Non-nil districtIds now span both chambers: uninominale deputies
        // reference districts.geojson (Phase 8) and the 73 linked senators
        // districts_senato.geojson (Phase 17); nil stays legitimate for
        // plurinominale/estero deputies and unlinked senators.
        let cameraDistricts = try GeoJSONLoader.loadDistricts()
        let senatoDistricts = try GeoJSONLoader.loadDistricts(resource: "districts_senato")
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        let districtIds = Set((cameraDistricts + senatoDistricts).map(\.id))
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
