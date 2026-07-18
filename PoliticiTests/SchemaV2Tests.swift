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
        // Data/districts.geojson ships real ISTAT geometry now (provenance
        // .official — see testShippingDistrictsAreOfficialProvenance
        // below); the fictional rectangles with .sample provenance-default
        // live at districts.sample.geojson.
        let districts = try GeoJSONLoader.loadDistricts(resource: "districts.sample")
        XCTAssertFalse(districts.isEmpty)
        XCTAssertTrue(districts.allSatisfy { $0.provenance == .sample })
    }

    func testShippingDistrictsAreOfficialProvenance() throws {
        let districts = try GeoJSONLoader.loadDistricts()
        XCTAssertFalse(districts.isEmpty)
        XCTAssertTrue(districts.allSatisfy { $0.provenance == .official })
        XCTAssertTrue(districts.allSatisfy { $0.collegioType == .uninominale })
        XCTAssertTrue(districts.allSatisfy { $0.sourceName == "ISTAT" })
    }

    /// Data/representatives.json now ships real, officially-sourced records
    /// (see tools/import_representatives.py), so it always has explicit
    /// `"provenance": "official"` and no longer exercises the decode-default
    /// path. That default is tested directly here via a minimal fixture that
    /// omits the key entirely, independent of whatever the shipping data
    /// currently contains.
    func testRepresentativeProvenanceDefaultsToSampleWhenAbsent() throws {
        let json = """
        {
          "id": "TEST-REP-001",
          "name": "Test Persona",
          "chamber": "Camera",
          "party": "Test",
          "parliamentaryGroup": "Test",
          "committees": [],
          "photoName": "person.crop.circle.fill"
        }
        """
        let representative = try JSONDecoder().decode(Representative.self, from: Data(json.utf8))
        XCTAssertEqual(representative.provenance, .sample)
        XCTAssertEqual(representative.electionType, .sconosciuto)
        XCTAssertNil(representative.districtId)
    }

    func testShippingRepresentativesAreAllOfficialProvenance() throws {
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        XCTAssertFalse(representatives.isEmpty)
        XCTAssertTrue(representatives.allSatisfy { $0.provenance == .official })
    }

    func testSampleVotesDecodeWithSampleProvenance() throws {
        // Data/votes.json ships empty now (see DecodingTests); the fictional,
        // .sample-provenance votes live in Data/votes.sample.json.
        let votes = try LocalJSONLoader.decode([Vote].self, fromResource: "votes.sample")
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
    //
    // Reinstated at full strength: Data/votes.json now ships as a valid,
    // empty schema-v2 collection (see docs/v2/02-post-import-audit.md)
    // instead of referencing stale fictional REP### ids, so this check is
    // vacuously — but genuinely, not artificially — satisfied, and will
    // catch any future vote entry that doesn't reference a real
    // representative id.

    func testShippingDataIdsAreUnique() throws {
        let districts = try GeoJSONLoader.loadDistricts()
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        let votes = try LocalJSONLoader.decode([Vote].self, fromResource: "votes")

        let districtIds = districts.map(\.id)
        let representativeIds = representatives.map(\.id)
        let voteIds = votes.map(\.id)

        XCTAssertEqual(districtIds.count, Set(districtIds).count, "district ids must be unique")
        XCTAssertEqual(representativeIds.count, Set(representativeIds).count, "representative ids must be unique")
        XCTAssertEqual(voteIds.count, Set(voteIds).count, "vote ids must be unique")
    }

    func testShippingVotesReferenceKnownRepresentatives() throws {
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        let votes = try LocalJSONLoader.decode([Vote].self, fromResource: "votes")
        let representativeIds = Set(representatives.map(\.id))

        XCTAssertTrue(
            votes.allSatisfy { representativeIds.contains($0.representativeId) },
            "every shipping vote.representativeId must reference a real representative"
        )
    }

    func testEveryNonNilShippingRepresentativeDistrictIsKnown() throws {
        let districts = try GeoJSONLoader.loadDistricts()
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        let districtIdSet = Set(districts.map(\.id))

        XCTAssertTrue(
            representatives.allSatisfy { representative in
                guard let districtId = representative.districtId else { return true }
                return districtIdSet.contains(districtId)
            },
            "every non-nil representative.districtId must reference an existing district"
        )
    }

    // MARK: - Shipping-data invariants (post-import reconciliation phase)
    //
    // Counts are documented and justified in docs/v2/02-post-import-audit.md
    // (400 = Camera's exact constitutional size; 201 = Senato's currently-
    // serving count, elected + 5 active life senators, verified directly
    // against the raw SPARQL cache).

    func testShippingRepresentativesChamberCounts() throws {
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        XCTAssertEqual(representatives.filter { $0.chamber == .camera }.count, 400)
        XCTAssertEqual(representatives.filter { $0.chamber == .senato }.count, 201)
    }

    func testShippingRepresentativeIdsAndStableSourceIdsAreUniqueAndNonEmpty() throws {
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")

        let ids = representatives.map(\.id)
        XCTAssertTrue(ids.allSatisfy { !$0.isEmpty })
        XCTAssertEqual(ids.count, Set(ids).count, "representative ids must be unique")

        let stableSourceIds = representatives.compactMap(\.stableSourceId)
        XCTAssertEqual(stableSourceIds.count, representatives.count, "every shipping representative must have a stableSourceId")
        XCTAssertTrue(stableSourceIds.allSatisfy { !$0.isEmpty })
        XCTAssertEqual(stableSourceIds.count, Set(stableSourceIds).count, "stableSourceId must be unique")
    }

    func testShippingRepresentativesHaveNonEmptyParliamentaryGroup() throws {
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        XCTAssertTrue(representatives.allSatisfy { !$0.parliamentaryGroup.isEmpty })
    }

    // MARK: - Collegio uninominale linkage (Phase 8 — see docs/v2/03-linkage-report.md)

    func testShippingDistrictsHaveNonEmptyCircoscrizione() throws {
        let districts = try GeoJSONLoader.loadDistricts()
        XCTAssertTrue(districts.allSatisfy { ($0.circoscrizione?.isEmpty == false) })
        XCTAssertTrue(districts.allSatisfy { ($0.subCode?.isEmpty == false) })
    }

    func testAtMostOneCurrentUninominaleRepresentativePerDistrict() throws {
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        let districtIds = representatives.compactMap(\.districtId)
        XCTAssertEqual(
            districtIds.count,
            Set(districtIds).count,
            "at most one current representative may claim a given districtId"
        )
    }

    func testUninominaleElectionTypeCountMatchesLinkedDistrictCount() throws {
        // See docs/v2/03-linkage-report.md: 147/147 uninominale collegi
        // linked, 0 vacant, 0 by-election-caused duplicates — so the count
        // of electionType == .uninominale representatives should exactly
        // equal the count of shipping (Camera) uninominale districts, with
        // no undocumented deviation.
        let districts = try GeoJSONLoader.loadDistricts()
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        let uninominaleRepresentatives = representatives.filter { $0.electionType == .uninominale }
        XCTAssertEqual(uninominaleRepresentatives.count, districts.count)
        XCTAssertTrue(uninominaleRepresentatives.allSatisfy { $0.districtId != nil })
    }

    func testNonUninominaleCamereRepresentativesHaveNilDistrictId() throws {
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        let cameraNonUninominale = representatives.filter {
            $0.chamber == .camera && $0.electionType != .uninominale
        }
        XCTAssertFalse(cameraNonUninominale.isEmpty)
        XCTAssertTrue(cameraNonUninominale.allSatisfy { $0.districtId == nil })
    }

    func testSenatoRepresentativesAreUntouchedByLinkage() throws {
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        let senators = representatives.filter { $0.chamber == .senato }
        XCTAssertEqual(senators.count, 201)
        XCTAssertTrue(senators.allSatisfy { $0.districtId == nil && $0.electionType == .sconosciuto })
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
