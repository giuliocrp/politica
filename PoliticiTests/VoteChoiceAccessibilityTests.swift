//
//  VoteChoiceAccessibilityTests.swift
//  PoliticiTests
//

import XCTest
@testable import Politici

/// `VoteBadge` must never convey a vote outcome by color alone (see
/// docs/v2/a11y-checklist.md) — every `VoteChoice` case needs its own SF
/// Symbol and a distinct, non-empty Italian VoiceOver label.
final class VoteChoiceAccessibilityTests: XCTestCase {
    func testEveryCaseHasANonEmptySymbolName() {
        for choice in VoteChoice.allCases {
            XCTAssertFalse(choice.symbolName.isEmpty, "\(choice) has no symbolName")
        }
    }

    func testEveryCaseHasANonEmptyAccessibilityLabel() {
        for choice in VoteChoice.allCases {
            XCTAssertFalse(choice.accessibilityLabel.isEmpty, "\(choice) has no accessibilityLabel")
        }
    }

    /// Distinguishable "without color" (the task's own phrasing) requires
    /// distinct symbols, not just distinct colors, per case.
    func testEveryCaseHasADistinctSymbolName() {
        let symbols = VoteChoice.allCases.map(\.symbolName)
        XCTAssertEqual(symbols.count, Set(symbols).count, "two VoteChoice cases share the same SF Symbol")
    }

    func testEveryCaseHasADistinctAccessibilityLabel() {
        let labels = VoteChoice.allCases.map(\.accessibilityLabel)
        XCTAssertEqual(labels.count, Set(labels).count, "two VoteChoice cases share the same accessibility label")
    }

    func testAccessibilityLabelsMatchTheSpecifiedItalianCopy() {
        XCTAssertEqual(VoteChoice.favorevole.accessibilityLabel, "Voto favorevole")
        XCTAssertEqual(VoteChoice.contrario.accessibilityLabel, "Voto contrario")
        XCTAssertEqual(VoteChoice.astenuto.accessibilityLabel, "Astenuto")
        XCTAssertEqual(VoteChoice.assente.accessibilityLabel, "Assente")
        XCTAssertEqual(VoteChoice.sconosciuto.accessibilityLabel, "Esito non disponibile")
    }

    func testSymbolNamesMatchTheSpecifiedSymbols() {
        XCTAssertEqual(VoteChoice.favorevole.symbolName, "checkmark")
        XCTAssertEqual(VoteChoice.contrario.symbolName, "xmark")
        XCTAssertEqual(VoteChoice.astenuto.symbolName, "minus")
        XCTAssertEqual(VoteChoice.assente.symbolName, "slash.circle")
        XCTAssertEqual(VoteChoice.sconosciuto.symbolName, "questionmark")
    }
}
