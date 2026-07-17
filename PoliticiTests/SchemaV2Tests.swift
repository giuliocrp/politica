//
//  SchemaV2Tests.swift
//  PoliticiTests
//

import XCTest
@testable import Politici

/// Coverage for the v2 schema hardening: provenance defaults, tolerant enum
/// decoding, referential integrity of the shipping bundle data, and the new
/// sources manifest.
final class SchemaV2Tests: XCTestCase {
    // MARK: - Decoding defaults: current sample files decode as .sample

    func testSampleDistrictsDecodeWithSampleProvenance() throws {
        let districts = try GeoJSONLoader.loadDistricts()
        XCTAssertFalse(districts.isEmpty)
        XCTAssertTrue(districts.allSatisfy { $0.provenance == .sample })
    }

    func testSampleRepresentativesDecodeWithSampleProvenance() throws {
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        XCTAssertFalse(representatives.isEmpty)
        XCTAssertTrue(representatives.allSatisfy { $0.provenance == .sample })
    }

    func testSampleVotesDecodeWithSampleProvenance() throws {
        let votes = try LocalJSONLoader.decode([Vote].self, fromResource: "votes")
        XCTAssertFalse(votes.isEmpty)
        XCTAssertTrue(votes.allSatisfy { $0.provenance == .sample })
    }

    // MARK: - Tolerant decoding: unknown raw values never throw

    func testUnknownVoteChoiceDecodesAsSconosciuto() throws {
        let json = """
        {
          "id": "TEST-VOTE-001",
          "representativeId": "REP001",
          "title": "Voto di prova",
          "date": "2025-01-01",
          "vote": "QualcosaDiInventato",
          "result": "Approvato",
          "sourceUrl": null
        }
        """
        let vote = try JSONDecoder().decode(Vote.self, from: Data(json.utf8))
        XCTAssertEqual(vote.vote, .sconosciuto)
    }

    func testUnknownVoteResultDecodesAsSconosciuto() throws {
        let json = """
        {
          "id": "TEST-VOTE-002",
          "representativeId": "REP001",
          "title": "Voto di prova",
          "date": "2025-01-01",
          "vote": "Favorevole",
          "result": "EsitoInventato",
          "sourceUrl": null
        }
        """
        let vote = try JSONDecoder().decode(Vote.self, from: Data(json.utf8))
        XCTAssertEqual(vote.result, .sconosciuto)
    }

    // MARK: - Referential integrity on the shipping bundle data

    func testShippingDataReferentialIntegrityAndUniqueIds() throws {
        let districts = try GeoJSONLoader.loadDistricts()
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        let votes = try LocalJSONLoader.decode([Vote].self, fromResource: "votes")

        let districtIds = districts.map(\.id)
        let representativeIds = representatives.map(\.id)
        let voteIds = votes.map(\.id)

        XCTAssertEqual(districtIds.count, Set(districtIds).count, "district ids must be unique")
        XCTAssertEqual(representativeIds.count, Set(representativeIds).count, "representative ids must be unique")
        XCTAssertEqual(voteIds.count, Set(voteIds).count, "vote ids must be unique")

        let districtIdSet = Set(districtIds)
        XCTAssertTrue(
            representatives.allSatisfy { districtIdSet.contains($0.districtId) },
            "every representative.districtId must reference an existing district"
        )

        let representativeIdSet = Set(representativeIds)
        XCTAssertTrue(
            votes.allSatisfy { representativeIdSet.contains($0.representativeId) },
            "every vote.representativeId must reference an existing representative"
        )
    }

    // MARK: - Sources manifest

    func testSourcesManifestDecodesWithSchemaVersion2() throws {
        let manifest = try LocalJSONLoader.decode(SourcesManifest.self, fromResource: "sources")
        XCTAssertEqual(manifest.schemaVersion, 2)
        XCTAssertFalse(manifest.sources.isEmpty)
    }

    func testManifestServiceLoadsSourcesWithoutError() {
        let service = ManifestService()
        XCTAssertNil(service.loadError)
        XCTAssertEqual(service.manifest?.schemaVersion, 2)
    }
}
