//
//  PartyStyleServiceTests.swift
//  PoliticiTests
//

import SwiftUI
import XCTest
@testable import Politici

final class PartyStyleServiceTests: XCTestCase {
    private let partyStyleService = PartyStyleService()
    private let representativeService = RepresentativeService()

    func testPartiesJSONLoadsWithoutError() {
        XCTAssertNil(partyStyleService.loadError)
        XCTAssertFalse(partyStyleService.entries.isEmpty)
    }

    /// Every `party` value actually present in the shipping data must
    /// resolve to an explicit `Data/parties.json` entry — i.e. no real
    /// representative should be silently falling through to the gray
    /// default because a value was missed when generating parties.json.
    func testEveryShippingPartyValueHasAnExplicitEntry() {
        let parties = Set(representativeService.allRepresentatives().map(\.party))
        XCTAssertFalse(parties.isEmpty)
        for party in parties {
            XCTAssertNotNil(
                partyStyleService.entries[party],
                "party value \"\(party)\" has no Data/parties.json entry"
            )
        }
    }

    /// An unmapped value must still resolve gracefully (the documented
    /// default path), never crash or return nil.
    func testUnknownPartyFallsBackToGray() {
        let color = partyStyleService.color(for: "Un Partito Che Non Esiste")
        XCTAssertEqual(color, .gray)
    }

    func testEveryEntryColorHexParsesToAValidColor() throws {
        let entries = try LocalJSONLoader.decode([PartyStyleEntry].self, fromResource: "parties")
        for entry in entries {
            XCTAssertNotNil(Color(hex: entry.colorHex), "invalid colorHex for \(entry.value)")
        }
    }
}
