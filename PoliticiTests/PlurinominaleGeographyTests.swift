//
//  PlurinominaleGeographyTests.swift
//  PoliticiTests
//

import XCTest
@testable import Politici

/// Coverage for the Phase 25 plurinominale geography (see
/// docs/v4/25-plurinominale-geography.md): the `collegioPlurinominale` field
/// decode, and the pure `deputies(inPlurinominaleCollegio:)` grouping the
/// plurinominale-collegio detail page uses — exercised on hand-built
/// fixtures independent of the shipping data.
final class PlurinominaleGeographyTests: XCTestCase {
    private func representative(
        id: String,
        name: String = "Test Persona",
        chamber: String = "Camera",
        electionType: String? = "plurinominale",
        circoscrizione: String? = "Lazio 1",
        collegioPlurinominale: String? = "CP120101"
    ) throws -> Representative {
        let electionTypeLine = electionType.map { "\"electionType\": \"\($0)\"," } ?? ""
        let circoscrizioneLine = circoscrizione.map { "\"circoscrizione\": \"\($0)\"," } ?? ""
        let collegioPluriLine = collegioPlurinominale.map { "\"collegioPlurinominale\": \"\($0)\"," } ?? ""
        let json = """
        {
          "id": "\(id)",
          "name": "\(name)",
          "chamber": "\(chamber)",
          \(electionTypeLine)
          \(circoscrizioneLine)
          \(collegioPluriLine)
          "party": "Test",
          "parliamentaryGroup": "Test",
          "committees": [],
          "photoName": "person.crop.circle.fill"
        }
        """
        return try JSONDecoder().decode(Representative.self, from: Data(json.utf8))
    }

    // MARK: - Decoding

    func testCollegioPlurinominaleDecodesWhenPresent() throws {
        let deputy = try representative(id: "TEST-DEP-001", collegioPlurinominale: "CP30101")
        XCTAssertEqual(deputy.collegioPlurinominale, "CP30101")
    }

    func testAbsentCollegioPlurinominaleDecodesAsNil() throws {
        // The Estero / bare / senator shape: key omitted entirely.
        let estero = try representative(
            id: "TEST-DEP-002", electionType: "estero",
            circoscrizione: "Estero", collegioPlurinominale: nil
        )
        XCTAssertNil(estero.collegioPlurinominale)
    }

    // MARK: - deputies(inPlurinominaleCollegio:) — pure function

    func testGroupingReturnsOnlyPlurinominaleDeputiesOfThatCollegio() throws {
        let fixtures = [
            try representative(id: "B", name: "Bruna Bianchi", collegioPlurinominale: "CP120101"),
            try representative(id: "A", name: "Anna Alfieri", collegioPlurinominale: "CP120101"),
            // other plurinominale collegio
            try representative(id: "C", name: "Carlo Conti", collegioPlurinominale: "CP120102"),
            // a uninominale deputy who ALSO carries the same collegioPlurinominale
            // (geographically inside it) — excluded: they belong on their
            // uninominale collegio page, not here.
            try representative(id: "D", name: "Dario Drago", electionType: "uninominale", collegioPlurinominale: "CP120101"),
            // estero deputy (no collegioPlurinominale)
            try representative(id: "E", name: "Elsa Estero", electionType: "estero", circoscrizione: "Estero", collegioPlurinominale: nil),
            // a senator (no collegioPlurinominale)
            try representative(id: "F", name: "Franca Foschi", chamber: "Senato", electionType: nil, circoscrizione: nil, collegioPlurinominale: nil),
        ]

        let grouped = RepresentativeService.deputies(inPlurinominaleCollegio: "CP120101", from: fixtures)

        // Only the two plurinominale-elected deputies of CP120101, name-sorted.
        XCTAssertEqual(grouped.map(\.id), ["A", "B"])
    }

    func testGroupingExcludesUninominaleDeputyEvenWithMatchingCollegio() throws {
        // Belt-and-braces: a uninominale deputy carrying the collegio id is
        // never listed on the plurinominale collegio page.
        let fixtures = [
            try representative(id: "U", name: "Ugo Uni", electionType: "uninominale", collegioPlurinominale: "CP120101")
        ]
        XCTAssertTrue(
            RepresentativeService.deputies(inPlurinominaleCollegio: "CP120101", from: fixtures).isEmpty
        )
    }

    func testGroupingForUnknownCollegioIsEmpty() throws {
        let fixtures = [try representative(id: "A", name: "Anna Alfieri", collegioPlurinominale: "CP120101")]
        XCTAssertTrue(
            RepresentativeService.deputies(inPlurinominaleCollegio: "CP999999", from: fixtures).isEmpty
        )
    }
}
