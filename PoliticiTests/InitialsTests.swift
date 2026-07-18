//
//  InitialsTests.swift
//  PoliticiTests
//

import XCTest
@testable import Politici

final class InitialsTests: XCTestCase {
    func testTwoWordName() {
        XCTAssertEqual(Initials.from("Riccardo De Corato"), "RC")
    }

    func testMultiWordNameUsesFirstAndLastToken() {
        XCTAssertEqual(Initials.from("Andrea Giorgio Felice Maria Orsini"), "AO")
    }

    func testSingleWordNameUsesOneLetter() {
        XCTAssertEqual(Initials.from("Prodi"), "P")
    }

    func testEmptyNameFallsBackToPlaceholder() {
        XCTAssertEqual(Initials.from(""), "?")
    }

    func testWhitespaceOnlyNameFallsBackToPlaceholder() {
        XCTAssertEqual(Initials.from("   "), "?")
    }

    func testExtraWhitespaceIsIgnored() {
        XCTAssertEqual(Initials.from("  Mario   Rossi  "), "MR")
    }

    func testLowercaseNameIsUppercased() {
        XCTAssertEqual(Initials.from("mario rossi"), "MR")
    }

    /// Every real shipping representative name should produce a valid
    /// two-letter (or one-letter) initials string, never the "?" fallback —
    /// a regression guard against Data/representatives.json ever shipping a
    /// blank/whitespace-only name.
    func testEveryShippingRepresentativeNameProducesRealInitials() throws {
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        XCTAssertFalse(representatives.isEmpty)
        for representative in representatives {
            XCTAssertNotEqual(
                Initials.from(representative.name), "?",
                "representative \(representative.id) has a name that produces no initials: \(representative.name)"
            )
        }
    }
}
