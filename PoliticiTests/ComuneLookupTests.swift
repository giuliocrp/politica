//
//  ComuneLookupTests.swift
//  PoliticiTests
//
//  Phase 30 — comuni-table lookup (docs/v4/30-comuni-geocoding.md), test
//  spec 3: exact match, accent-insensitive, bilingual query, homonym returns
//  all candidates, unknown returns empty. Exercised against the REAL bundled
//  comuni.json (7,904 comuni), so the facts asserted (Castro is a Bergamo/Lecce
//  homonym, Châtillon is in Aosta, …) are the shipped data, verified against
//  the ISTAT source in the report before being hardcoded here.
//

import XCTest
@testable import Politici

final class ComuneLookupTests: XCTestCase {
    private let service = ComuneService()

    func testTableLoadsFromBundle() {
        XCTAssertNil(service.loadError)
        XCTAssertEqual(service.comuni.count, 7904)
    }

    // MARK: - Exact match

    func testExactNameMatchResolves() {
        let matches = service.comuni(matching: "Firenze")
        XCTAssertEqual(matches.map(\.province), ["Firenze"])
    }

    func testExactMatchIsWholeNameNotSubstring() {
        // "Roma" must not also drag in "Romano di Lombardia" etc.
        let matches = service.comuni(matching: "Roma")
        XCTAssertTrue(matches.allSatisfy { $0.name == "Roma" })
        XCTAssertEqual(matches.count, 1)
    }

    // MARK: - Accent / case insensitive

    func testAccentAndCaseInsensitiveMatch() {
        // Real comune "Châtillon" (Aosta). All three spellings resolve to it.
        for spelling in ["Châtillon", "chatillon", "CHATILLON"] {
            let matches = service.comuni(matching: spelling)
            XCTAssertEqual(matches.map(\.name), ["Châtillon"], "spelling: \(spelling)")
            XCTAssertEqual(matches.first?.province, "Aosta")
        }
    }

    // MARK: - Bilingual query (either side of the slash)

    func testBilingualQueryResolvesViaItalianSide() {
        // The table carries Italian-only names ("Bolzano", not "Bolzano/Bozen"),
        // so a bilingual query resolves via its Italian side.
        let matches = service.comuni(matching: "Bolzano/Bozen")
        XCTAssertEqual(matches.map(\.name), ["Bolzano"])
    }

    func testGermanOnlyExonymDoesNotResolve() {
        // Honest limitation, documented: the source has no German exonyms, and
        // none are fabricated — so "Bozen" alone finds nothing.
        XCTAssertTrue(service.comuni(matching: "Bozen").isEmpty)
    }

    // MARK: - Homonyms (disambiguated by province)

    func testHomonymReturnsAllCandidates() {
        let castro = service.comuni(matching: "Castro")
        XCTAssertEqual(castro.map(\.province), ["Bergamo", "Lecce"])

        let livo = service.comuni(matching: "Livo")
        XCTAssertEqual(livo.map(\.province), ["Como", "Trento"])
    }

    func testHomonymCandidatesAreDistinctCoordinates() {
        let castro = service.comuni(matching: "Castro")
        XCTAssertEqual(castro.count, 2)
        XCTAssertNotEqual(castro[0].lat, castro[1].lat)
    }

    // MARK: - Unknown

    func testUnknownNameReturnsEmpty() {
        XCTAssertTrue(service.comuni(matching: "Nowhereville").isEmpty)
        XCTAssertTrue(service.comuni(matching: "").isEmpty)
    }
}
