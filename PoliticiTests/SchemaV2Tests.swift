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
        // votes.json is the normalized Phase 20 schema now — both the
        // event ids and the position ids must be unique.
        let districts = try GeoJSONLoader.loadDistricts()
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        let votesFile = try LocalJSONLoader.decode(VotesFile.self, fromResource: "votes")

        let districtIds = districts.map(\.id)
        let representativeIds = representatives.map(\.id)
        let voteEventIds = votesFile.events.map(\.id)
        let positionIds = votesFile.positions.map(\.id)

        XCTAssertEqual(districtIds.count, Set(districtIds).count, "district ids must be unique")
        XCTAssertEqual(representativeIds.count, Set(representativeIds).count, "representative ids must be unique")
        XCTAssertEqual(voteEventIds.count, Set(voteEventIds).count, "vote event ids must be unique")
        XCTAssertEqual(positionIds.count, Set(positionIds).count, "vote position ids must be unique")
    }

    func testShippingVotesReferenceKnownRepresentatives() throws {
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        let votesFile = try LocalJSONLoader.decode(VotesFile.self, fromResource: "votes")
        let representativeIds = Set(representatives.map(\.id))

        XCTAssertTrue(
            votesFile.positions.allSatisfy { representativeIds.contains($0.representativeId) },
            "every shipping position.representativeId must reference a real representative"
        )
    }

    // MARK: - Votes import (Phase 9 — see docs/v2/04-votes-import.md)

    func testShippingVotesAreAllOfficialProvenance() throws {
        let votesFile = try LocalJSONLoader.decode(VotesFile.self, fromResource: "votes")
        XCTAssertFalse(votesFile.events.isEmpty)
        XCTAssertFalse(votesFile.positions.isEmpty)
        XCTAssertTrue(votesFile.events.allSatisfy { $0.provenance == .official })
    }

    func testShippingVotesHaveNoUnmappedVoteOrResultVocabulary() throws {
        // The observed raw dc:type / ocd:approvato vocabulary (see
        // docs/v2/04-votes-import.md) is fully mapped in
        // tools/import_votes.py's RAW_VOTE_CHOICE/RAW_VOTE_RESULT tables —
        // a .sconosciuto in shipping data would mean a new, unmapped raw
        // value slipped through unnoticed on some future re-fetch.
        let votesFile = try LocalJSONLoader.decode(VotesFile.self, fromResource: "votes")
        XCTAssertTrue(votesFile.positions.allSatisfy { $0.vote != .sconosciuto })
        XCTAssertTrue(votesFile.events.allSatisfy { $0.result != .sconosciuto })
    }

    @MainActor
    func testVoteServiceSortsRealVotesNewestFirst() async throws {
        let voteService = VoteService()
        await voteService.loadIfNeeded()  // lazy load since Phase 27
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
        // of Camera electionType == .uninominale representatives should
        // exactly equal the count of shipping (Camera) uninominale districts,
        // with no undocumented deviation. Scoped to Camera since Phase 26
        // (docs/v4/26-senato-regione.md) gave the 73 uninominale senators an
        // electionType of .uninominale too — an unscoped filter would now
        // count 147 + 73.
        let districts = try GeoJSONLoader.loadDistricts()
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        let uninominaleDeputies = representatives.filter { $0.chamber == .camera && $0.electionType == .uninominale }
        XCTAssertEqual(uninominaleDeputies.count, districts.count)
        XCTAssertTrue(uninominaleDeputies.allSatisfy { $0.districtId != nil })
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
        // stay nil, mirroring Camera's plurinominale/estero pattern.
        //
        // Phase 26 (docs/v4/26-senato-regione.md) took the deferred
        // electionType decision with explicit user approval: senators'
        // electionType is now the cross-chamber mapping of osr:tipoElezione,
        // so the old "electionType stays .sconosciuto for every senator"
        // assertion is deliberately replaced by the approved distribution
        // (73 uninominale / 121 plurinominale / 2 estero / 5 a-vita .sconosciuto).
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        let senatoDistricts = try GeoJSONLoader.loadDistricts(resource: "districts_senato")
        let senators = representatives.filter { $0.chamber == .senato }
        XCTAssertEqual(senators.count, 201)

        let linkedIds = Set(senators.compactMap(\.districtId))
        XCTAssertEqual(linkedIds.count, 73)
        XCTAssertTrue(linkedIds.allSatisfy { $0.hasPrefix("S") })
        XCTAssertTrue(linkedIds.isSubset(of: Set(senatoDistricts.map(\.id))))
        XCTAssertEqual(Set(senatoDistricts.map(\.id)).subtracting(linkedIds).count, 1)

        XCTAssertEqual(senators.filter { $0.electionType == .uninominale }.count, 73)
        XCTAssertEqual(senators.filter { $0.electionType == .plurinominale }.count, 121)
        XCTAssertEqual(senators.filter { $0.electionType == .estero }.count, 2)
        XCTAssertEqual(senators.filter { $0.electionType == .sconosciuto }.count, 5)
        // Every uninominale senator is linked; every linked senator is uninominale.
        XCTAssertTrue(senators.filter { $0.electionType == .uninominale }.allSatisfy { $0.districtId != nil })
        XCTAssertTrue(senators.filter { $0.districtId != nil }.allSatisfy { $0.electionType == .uninominale })
        XCTAssertTrue(
            senators.filter { $0.mandate == .nominaAVita }.allSatisfy { $0.districtId == nil },
            "life senators have no collegio and must never be linked to one"
        )
    }

    // MARK: - Deputy circoscrizioni (Phase 18 — see docs/v3/18-plurinominale-context.md)

    func testShippingDeputiesCarryCanonicalCircoscrizioni() throws {
        // The GO-CIRC gate's conditions, re-asserted on the shipped bundle:
        // complete deputy coverage, values within districts.geojson's own
        // 28 circoscrizioni ∪ {"Estero"}, exact equality with the linked
        // collegio's property for every uninominale deputy, estero <->
        // "Estero" correspondence (8 deputies), senators key-free, and the
        // measured 147/245/8 electionType distribution.
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        let districts = try GeoJSONLoader.loadDistricts()

        let deputies = representatives.filter { $0.chamber == .camera }
        XCTAssertTrue(deputies.allSatisfy { $0.circoscrizione?.isEmpty == false })

        let validValues = Set(districts.compactMap(\.circoscrizione)).union(["Estero"])
        XCTAssertTrue(Set(deputies.compactMap(\.circoscrizione)).isSubset(of: validValues))

        let circoscrizioneByDistrict = Dictionary(
            uniqueKeysWithValues: districts.map { ($0.id, $0.circoscrizione) }
        )
        let linked = deputies.filter { $0.districtId != nil }
        XCTAssertTrue(linked.allSatisfy { $0.circoscrizione == circoscrizioneByDistrict[$0.districtId!] })

        XCTAssertEqual(deputies.filter { $0.electionType == .uninominale }.count, 147)
        XCTAssertEqual(deputies.filter { $0.electionType == .plurinominale }.count, 245)
        let esteroDeputies = deputies.filter { $0.electionType == .estero }
        XCTAssertEqual(esteroDeputies.count, 8)
        XCTAssertEqual(
            Set(esteroDeputies.map(\.id)),
            Set(deputies.filter { $0.circoscrizione == "Estero" }.map(\.id))
        )

        let senators = representatives.filter { $0.chamber == .senato }
        XCTAssertTrue(senators.allSatisfy { $0.circoscrizione == nil })
    }

    // MARK: - Senator regioni (Phase 26 — see docs/v4/26-senato-regione.md)

    func testShippingSenatorsCarryCanonicalRegioni() throws {
        // The GO-REG gate's conditions, re-asserted on the shipped bundle:
        // every elective senator (196) carries a non-empty regione within
        // districts_senato.geojson's own 20 regioni ∪ {"Estero"}; exact
        // equality with the linked collegio's regione for every uninominale
        // senator (condition (c)); the a-vita senators and all deputies carry
        // none; estero <-> "Estero" correspondence (2); and the approved
        // electionType distribution (73/121/2 + 5 a-vita .sconosciuto).
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        let senatoDistricts = try GeoJSONLoader.loadDistricts(resource: "districts_senato")

        let senators = representatives.filter { $0.chamber == .senato }
        let withRegione = senators.filter { $0.regione != nil }
        XCTAssertEqual(withRegione.count, 196)
        XCTAssertTrue(withRegione.allSatisfy { $0.regione?.isEmpty == false })

        let validValues = Set(senatoDistricts.compactMap(\.regione)).union(["Estero"])
        XCTAssertTrue(Set(withRegione.compactMap(\.regione)).isSubset(of: validValues))

        let regioneByDistrict = Dictionary(
            uniqueKeysWithValues: senatoDistricts.map { ($0.id, $0.regione) }
        )
        let linked = senators.filter { $0.districtId != nil }
        XCTAssertTrue(linked.allSatisfy { $0.regione == regioneByDistrict[$0.districtId!] })

        // Distribution + estero <-> "Estero" correspondence.
        XCTAssertEqual(senators.filter { $0.electionType == .uninominale }.count, 73)
        XCTAssertEqual(senators.filter { $0.electionType == .plurinominale }.count, 121)
        let esteroSenators = senators.filter { $0.electionType == .estero }
        XCTAssertEqual(esteroSenators.count, 2)
        XCTAssertEqual(
            Set(esteroSenators.map(\.id)),
            Set(senators.filter { $0.regione == "Estero" }.map(\.id))
        )

        // A-vita senators (and all deputies) carry no regione.
        XCTAssertTrue(senators.filter { $0.mandate == .nominaAVita }.allSatisfy { $0.regione == nil })
        let deputies = representatives.filter { $0.chamber == .camera }
        XCTAssertTrue(deputies.allSatisfy { $0.regione == nil })
    }

    // MARK: - Plurinominale geography (Phase 25 — see docs/v4/25-plurinominale-geography.md)

    func testShippingPlurinominaleDistrictsAreOfficialProvenance() throws {
        // Same ISTAT release as the uninominale layers, same
        // provenance/collegioType/sourceName shape (Phase 25).
        for resource in ["districts_plurinominali_camera", "districts_plurinominali_senato"] {
            let districts = try GeoJSONLoader.loadDistricts(resource: resource)
            XCTAssertFalse(districts.isEmpty)
            XCTAssertTrue(districts.allSatisfy { $0.provenance == .official }, "\(resource)")
            XCTAssertTrue(districts.allSatisfy { $0.collegioType == .plurinominale }, "\(resource)")
            XCTAssertTrue(districts.allSatisfy { $0.sourceName == "ISTAT" }, "\(resource)")
        }
    }

    func testShippingDeputiesCarryConsistentCollegioPlurinominale() throws {
        // The GO-PLURI gate's linkage conditions, re-asserted on the shipped
        // bundle: every plurinominale deputy carries a collegioPlurinominale
        // that resolves to a real Camera plurinominale district AND agrees
        // with the deputy's circoscrizione; exactly 389 deputies carry it
        // (144 uninominale + 245 plurinominale); the 8 Estero deputies and all
        // senators carry none.
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        let pluriDistricts = try GeoJSONLoader.loadDistricts(resource: "districts_plurinominali_camera")
        let circoscrizioneById = Dictionary(uniqueKeysWithValues: pluriDistricts.map { ($0.id, $0.circoscrizione) })

        let deputies = representatives.filter { $0.chamber == .camera }
        let withPluri = deputies.filter { $0.collegioPlurinominale != nil }
        XCTAssertEqual(withPluri.count, 389)

        // Every plurinominale deputy carries it; every value resolves and is
        // consistent with the deputy's circoscrizione.
        XCTAssertTrue(deputies.filter { $0.electionType == .plurinominale }.allSatisfy { $0.collegioPlurinominale != nil })
        XCTAssertTrue(withPluri.allSatisfy { circoscrizioneById[$0.collegioPlurinominale!] != nil },
                      "every collegioPlurinominale must reference a shipped plurinominale district")
        XCTAssertTrue(withPluri.allSatisfy { circoscrizioneById[$0.collegioPlurinominale!] == $0.circoscrizione },
                      "collegioPlurinominale's circoscrizione must equal the deputy's")

        // Estero deputies (and all senators) carry none.
        XCTAssertTrue(deputies.filter { $0.circoscrizione == "Estero" }.allSatisfy { $0.collegioPlurinominale == nil })
        let senators = representatives.filter { $0.chamber == .senato }
        XCTAssertTrue(senators.allSatisfy { $0.collegioPlurinominale == nil })

        // Every one of the 49 plurinominale collegi is named by at least one
        // deputy (the drift detector; the probe found full 49/49 coverage).
        XCTAssertEqual(Set(withPluri.compactMap(\.collegioPlurinominale)).count, 49)
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

    /// The manifest lists no fictional source, and `FontiEDatiView` renders
    /// `ForEach(sources)` unfiltered — so this is exactly what that screen
    /// shows. It replaces the UI-test assertion that the fictional card
    /// declared itself, which lost its subject when the row was retired
    /// (`tools/make_manifest.py`'s `RETIRED_SOURCE_IDS`).
    ///
    /// Asserted here rather than in the UI test on purpose: `FontiEDatiView`
    /// is a lazy `List`, where a card below the fold is absent from the
    /// accessibility tree whether or not it exists — so a UI-level
    /// `XCTAssertFalse(…exists)` would pass for the wrong reason. Absence is
    /// only a sound assertion where the tree is the whole truth.
    ///
    /// The v1 fixtures themselves are still committed and still ship inside
    /// the .app (the `Politici/` group is FileSystemSynchronized), but no
    /// shipping code path loads them and every shipped record carries
    /// `.official`, so a "Dati dimostrativi" card would describe nothing a
    /// user can reach.
    func testShippingManifestListsNoFictionalSource() throws {
        let manifest = try LocalJSONLoader.decode(SourcesManifest.self, fromResource: "sources")
        XCTAssertFalse(
            manifest.sources.contains { $0.id == "prototipo-dati-dimostrativi" },
            "La fonte fittizia è ricomparsa nel manifest"
        )
        // Not keyed to that one id: any row without a real URL or licence is
        // the same defect wearing a different name.
        for source in manifest.sources {
            XCTAssertFalse(source.url.isEmpty, "Fonte senza URL: \(source.id)")
            XCTAssertNotEqual(source.license, "n/a", "Fonte senza licenza reale: \(source.id)")
        }
    }
}
