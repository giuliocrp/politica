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

    func testShippingSenatoDistrictsAreOfficialProvenance() throws {
        // Same ISTAT release as Camera's (Phase 16 — see
        // docs/v3/16-senato-boundaries.md), same provenance/collegioType/
        // sourceName shape.
        let districts = try GeoJSONLoader.loadDistricts(resource: "districts_senato")
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
    // Data/votes.json now ships real, non-empty positions imported from
    // dati.camera.it (see docs/v2/04-votes-import.md) — this is a genuine,
    // non-vacuous check of every vote.representativeId against the real
    // representatives.json.

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

    // MARK: - Votes import (Phase 9 — see docs/v2/04-votes-import.md)

    func testShippingVotesAreAllOfficialProvenance() throws {
        let votes = try LocalJSONLoader.decode([Vote].self, fromResource: "votes")
        XCTAssertFalse(votes.isEmpty)
        XCTAssertTrue(votes.allSatisfy { $0.provenance == .official })
    }

    func testShippingVotesHaveNoUnmappedVoteOrResultVocabulary() throws {
        // The observed raw dc:type / ocd:approvato vocabulary (see
        // docs/v2/04-votes-import.md) is fully mapped in
        // tools/import_votes.py's RAW_VOTE_CHOICE/RAW_VOTE_RESULT tables —
        // a .sconosciuto in shipping data would mean a new, unmapped raw
        // value slipped through unnoticed on some future re-fetch.
        let votes = try LocalJSONLoader.decode([Vote].self, fromResource: "votes")
        XCTAssertTrue(votes.allSatisfy { $0.vote != .sconosciuto })
        XCTAssertTrue(votes.allSatisfy { $0.result != .sconosciuto })
    }

    func testVoteServiceSortsRealVotesNewestFirst() throws {
        let voteService = VoteService()
        let representativeId = try XCTUnwrap(voteService.votes.first?.representativeId)
        let votes = voteService.votes(for: representativeId)
        XCTAssertFalse(votes.isEmpty)
        XCTAssertEqual(votes.map(\.date), votes.map(\.date).sorted(by: >))
    }

    func testEveryNonNilShippingRepresentativeDistrictIsKnown() throws {
        // Both chambers' boundary files since Phase 17: deputies reference
        // districts.geojson ids, linked senators districts_senato.geojson's
        // "S"-prefixed ids.
        let cameraDistricts = try GeoJSONLoader.loadDistricts()
        let senatoDistricts = try GeoJSONLoader.loadDistricts(resource: "districts_senato")
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        let districtIdSet = Set((cameraDistricts + senatoDistricts).map(\.id))

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

    func testSenatoLinkageMatchesPhase17Import() throws {
        // Phase 17 (docs/v3/17-senato-mandates.md) superseded the v2-era
        // "senators are untouched by linkage" invariant: the 73
        // uninominale-elected serving senators now carry their real
        // "S"-prefixed Senato collegio id, leaving exactly one of the 74
        // collegi without a serving senator (no XIX binding claims it in
        // the source). The other 128 senators (proporzionale/estero/life)
        // stay nil, mirroring Camera's plurinominale/estero pattern, and
        // electionType stays .sconosciuto for every senator — tipoElezione
        // is consumed at import time for linkage eligibility only.
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        let senatoDistricts = try GeoJSONLoader.loadDistricts(resource: "districts_senato")
        let senators = representatives.filter { $0.chamber == .senato }
        XCTAssertEqual(senators.count, 201)

        let linkedIds = Set(senators.compactMap(\.districtId))
        XCTAssertEqual(linkedIds.count, 73)
        XCTAssertTrue(linkedIds.allSatisfy { $0.hasPrefix("S") })
        XCTAssertTrue(linkedIds.isSubset(of: Set(senatoDistricts.map(\.id))))
        XCTAssertEqual(Set(senatoDistricts.map(\.id)).subtracting(linkedIds).count, 1)

        XCTAssertTrue(senators.allSatisfy { $0.electionType == .sconosciuto })
        XCTAssertTrue(
            senators.filter { $0.mandate == .nominaAVita }.allSatisfy { $0.districtId == nil },
            "life senators have no collegio and must never be linked to one"
        )
    }

    // MARK: - Senato mandates (Phase 17 — see docs/v3/17-senato-mandates.md)

    func testShippingSenatorsCarryVerbatimMandates() throws {
        // Snapshot invariants of the current import: 201 serving senators =
        // 196 elettivo + 5 a-vita, zero Presidente-emerito (its one known
        // bearer's mandate is ended and is excluded by the fineMandato rule),
        // zero .sconosciuto (the importer fails loudly on unknown vocabulary
        // instead of ever writing it). Deputies carry no mandate at all.
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")

        let senators = representatives.filter { $0.chamber == .senato }
        XCTAssertEqual(senators.filter { $0.mandate == .elettivo }.count, 196)
        XCTAssertEqual(senators.filter { $0.mandate == .nominaAVita }.count, 5)
        XCTAssertEqual(senators.filter { $0.mandate == .diDirittoEAVita }.count, 0)
        XCTAssertTrue(senators.allSatisfy { $0.mandate != nil && $0.mandate != .sconosciuto })

        let deputies = representatives.filter { $0.chamber == .camera }
        XCTAssertTrue(deputies.allSatisfy { $0.mandate == nil })
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
