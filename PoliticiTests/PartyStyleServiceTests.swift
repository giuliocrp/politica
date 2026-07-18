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

    /// `RepresentativeListView`'s party filter chips are built from distinct
    /// `shortName`s (not raw `party` values), so a Camera sigla and its
    /// Senato full-name counterpart (e.g. "FDI" / "Fratelli d'Italia") merge
    /// into a single chip. This locks in that every real party value maps
    /// to a non-empty short name, and that merging actually reduces the
    /// count (i.e. at least one such pair exists in the shipping data).
    func testShortNamesDedupeAcrossChamberSpellingVariants() {
        let realParties = Set(representativeService.allRepresentatives().map(\.party))
        let shortNames = Set(realParties.map { partyStyleService.shortName(for: $0) })

        XCTAssertTrue(shortNames.allSatisfy { !$0.isEmpty })
        XCTAssertLessThan(shortNames.count, realParties.count)
    }

    func testEveryEntryColorHexParsesToAValidColor() throws {
        let entries = try LocalJSONLoader.decode([PartyStyleEntry].self, fromResource: "parties")
        for entry in entries {
            XCTAssertNotNil(Color(hex: entry.colorHex), "invalid colorHex for \(entry.value)")
        }
    }

    /// `PartyStyleEntry.colorHex`'s doc comment promises >= 4.5:1 contrast
    /// against white (the color is used as a white-text/white-icon
    /// background — avatar circles, filled filter chips). Computed directly
    /// from the hex string (WCAG 2.1 relative-luminance formula) rather than
    /// via `Color`, so this doesn't depend on any platform color space
    /// behavior.
    func testEveryEntryColorMeetsMinimumContrastAgainstWhite() throws {
        let entries = try LocalJSONLoader.decode([PartyStyleEntry].self, fromResource: "parties")
        for entry in entries {
            let ratio = try XCTUnwrap(
                contrastRatioAgainstWhite(hex: entry.colorHex),
                "invalid hex for \(entry.value)"
            )
            XCTAssertGreaterThanOrEqual(
                ratio, 4.5,
                "\(entry.value) (\(entry.colorHex)) has contrast \(ratio) < 4.5:1 against white"
            )
        }
    }
}

/// WCAG 2.1 contrast ratio between an `"#RRGGBB"` color and white.
private func contrastRatioAgainstWhite(hex: String) -> Double? {
    var trimmed = hex.trimmingCharacters(in: .whitespaces)
    if trimmed.hasPrefix("#") { trimmed.removeFirst() }
    guard trimmed.count == 6, let value = UInt32(trimmed, radix: 16) else { return nil }

    func channel(_ shift: UInt32) -> Double {
        Double((value >> shift) & 0xFF) / 255.0
    }
    func linearize(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
    func relativeLuminance(_ r: Double, _ g: Double, _ b: Double) -> Double {
        0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)
    }

    let luminance = relativeLuminance(channel(16), channel(8), channel(0))
    let whiteLuminance = 1.0
    let lighter = max(luminance, whiteLuminance)
    let darker = min(luminance, whiteLuminance)
    return (lighter + 0.05) / (darker + 0.05)
}
