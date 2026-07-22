//
//  RegioneTests.swift
//  PoliticiTests
//

import XCTest
@testable import Politici

/// Coverage for the Phase 26 senator regione (see
/// docs/v4/26-senato-regione.md): field decoding and the pure
/// proporzionale-grouping function DistrictDetailView's Senato section uses,
/// exercised on hand-built fixtures independent of the shipping data. The
/// Senato mirror of CircoscrizioneTests.
final class RegioneTests: XCTestCase {
    private func representative(
        id: String,
        name: String = "Test Senatore",
        chamber: String = "Senato",
        electionType: String? = "plurinominale",
        regione: String? = "Lazio",
        districtId: String? = nil
    ) throws -> Representative {
        let electionTypeLine = electionType.map { "\"electionType\": \"\($0)\"," } ?? ""
        let regioneLine = regione.map { "\"regione\": \"\($0)\"," } ?? ""
        let districtIdLine = districtId.map { "\"districtId\": \"\($0)\"," } ?? ""
        let json = """
        {
          "id": "\(id)",
          "name": "\(name)",
          "chamber": "\(chamber)",
          \(electionTypeLine)
          \(regioneLine)
          \(districtIdLine)
          "party": "Test",
          "parliamentaryGroup": "Test",
          "committees": [],
          "photoName": "person.crop.circle.fill"
        }
        """
        return try JSONDecoder().decode(Representative.self, from: Data(json.utf8))
    }

    // MARK: - Decoding

    func testRegioneDecodesWhenPresent() throws {
        let senator = try representative(id: "TEST-SEN-001", regione: "Emilia-Romagna")
        XCTAssertEqual(senator.regione, "Emilia-Romagna")
    }

    func testAbsentRegioneDecodesAsNil() throws {
        // The a-vita / Camera-record shape: no regione key -> nil.
        let deputy = try representative(id: "TEST-DEP-001", chamber: "Camera", electionType: "uninominale", regione: nil)
        XCTAssertNil(deputy.regione)
    }

    // MARK: - Proporzionale grouping (pure function)

    func testGroupingReturnsOnlyProporzionaleSenatorsOfTheRegione() throws {
        let fixtures = [
            try representative(id: "B", name: "Bruna Bianchi", regione: "Lazio"),
            try representative(id: "A", name: "Anna Alfieri", regione: "Lazio"),
            try representative(id: "C", name: "Carlo Conti", regione: "Campania"),
            // Uninominale senator of the same regione (carries a districtId).
            try representative(id: "D", name: "Dario Drago", electionType: "uninominale", regione: "Lazio", districtId: "S120001"),
            // Estero senator (regione pinned to "Estero").
            try representative(id: "E", name: "Elsa Estero", electionType: "estero", regione: "Estero"),
            // A-vita senator: no electionType, no regione.
            try representative(id: "F", name: "Franca Foschi", electionType: nil, regione: nil),
            // A Camera plurinominale deputy that (only in this synthetic
            // fixture) carries a "Lazio" regione — must be excluded by chamber,
            // since deputies now also carry electionType .plurinominale.
            try representative(id: "G", name: "Aldo Gamba", chamber: "Camera", regione: "Lazio"),
        ]

        let grouped = RepresentativeService.proporzionaleSenators(inRegione: "Lazio", from: fixtures)

        // Only the two Lazio proporzionale senators, sorted by name: the
        // same-regione uninominale senator, the other regione, the estero and
        // a-vita senators, and the Camera deputy are all excluded.
        XCTAssertEqual(grouped.map(\.id), ["A", "B"])
    }

    func testGroupingForEsteroRegioneNeverReturnsAnyone() throws {
        // Estero senators are excluded by electionType even when queried by
        // their own "Estero" value — the belt-and-braces guarantee that no
        // geographic page can list them ("Estero" is additionally never a
        // district's regione).
        let fixtures = [
            try representative(id: "E", name: "Elsa Estero", electionType: "estero", regione: "Estero")
        ]
        XCTAssertTrue(
            RepresentativeService.proporzionaleSenators(inRegione: "Estero", from: fixtures).isEmpty
        )
    }

    func testGroupingForUnknownRegioneIsEmpty() throws {
        let fixtures = [try representative(id: "A", name: "Anna Alfieri")]
        XCTAssertTrue(
            RepresentativeService.proporzionaleSenators(inRegione: "NON-ESISTE", from: fixtures).isEmpty
        )
    }
}
