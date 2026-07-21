//
//  CircoscrizioneTests.swift
//  PoliticiTests
//

import XCTest
@testable import Politici

/// Coverage for the Phase 18 deputy circoscrizione (see
/// docs/v3/18-plurinominale-context.md): field decoding and the pure
/// plurinominale-grouping function DistrictDetailView's section uses,
/// exercised on hand-built fixtures independent of the shipping data.
final class CircoscrizioneTests: XCTestCase {
    private func representative(
        id: String,
        name: String = "Test Persona",
        chamber: String = "Camera",
        electionType: String? = "plurinominale",
        circoscrizione: String? = "Lazio 1"
    ) throws -> Representative {
        let electionTypeLine = electionType.map { "\"electionType\": \"\($0)\"," } ?? ""
        let circoscrizioneLine = circoscrizione.map { "\"circoscrizione\": \"\($0)\"," } ?? ""
        let json = """
        {
          "id": "\(id)",
          "name": "\(name)",
          "chamber": "\(chamber)",
          \(electionTypeLine)
          \(circoscrizioneLine)
          "party": "Test",
          "parliamentaryGroup": "Test",
          "committees": [],
          "photoName": "person.crop.circle.fill"
        }
        """
        return try JSONDecoder().decode(Representative.self, from: Data(json.utf8))
    }

    // MARK: - Decoding

    func testCircoscrizioneDecodesWhenPresent() throws {
        let deputy = try representative(id: "TEST-DEP-001", circoscrizione: "Piemonte 1")
        XCTAssertEqual(deputy.circoscrizione, "Piemonte 1")
    }

    func testAbsentCircoscrizioneDecodesAsNil() throws {
        let senator = try representative(id: "TEST-SEN-001", chamber: "Senato", circoscrizione: nil)
        XCTAssertNil(senator.circoscrizione)
    }

    // MARK: - Plurinominale grouping (pure function)

    func testGroupingReturnsOnlyPlurinominaleDeputiesOfTheCircoscrizione() throws {
        let fixtures = [
            try representative(id: "B", name: "Bruna Bianchi", circoscrizione: "Lazio 1"),
            try representative(id: "A", name: "Anna Alfieri", circoscrizione: "Lazio 1"),
            try representative(id: "C", name: "Carlo Conti", circoscrizione: "Lazio 2"),
            try representative(id: "D", name: "Dario Drago", electionType: "uninominale", circoscrizione: "Lazio 1"),
            try representative(id: "E", name: "Elsa Estero", electionType: "estero", circoscrizione: "Estero"),
            try representative(id: "F", name: "Franca Foschi", chamber: "Senato", electionType: nil, circoscrizione: nil),
        ]

        let grouped = RepresentativeService.plurinominaleRepresentatives(
            inCircoscrizione: "Lazio 1", from: fixtures
        )

        // Only the two Lazio 1 plurinominale deputies, sorted by name: the
        // same-circoscrizione uninominale deputy, the other circoscrizione,
        // the estero deputy, and the senator are all excluded.
        XCTAssertEqual(grouped.map(\.id), ["A", "B"])
    }

    func testGroupingForEsteroNeverReturnsAnyone() throws {
        // Estero deputies are excluded by electionType even when queried by
        // their own "Estero" value — the belt-and-braces guarantee that no
        // geographic page can ever list them ("Estero" is additionally
        // never a district's circoscrizione).
        let fixtures = [
            try representative(id: "E", name: "Elsa Estero", electionType: "estero", circoscrizione: "Estero")
        ]
        XCTAssertTrue(
            RepresentativeService.plurinominaleRepresentatives(inCircoscrizione: "Estero", from: fixtures).isEmpty
        )
    }

    func testGroupingForUnknownCircoscrizioneIsEmpty() throws {
        let fixtures = [try representative(id: "A", name: "Anna Alfieri")]
        XCTAssertTrue(
            RepresentativeService.plurinominaleRepresentatives(
                inCircoscrizione: "NON-ESISTE", from: fixtures
            ).isEmpty
        )
    }
}
