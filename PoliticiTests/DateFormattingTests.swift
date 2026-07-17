//
//  DateFormattingTests.swift
//  PoliticiTests
//

import XCTest
@testable import Politici

/// `DateFormatting` always formats using a hardcoded `it_IT` locale internally,
/// so these assertions hold regardless of the host machine/CI runner's locale.
final class DateFormattingTests: XCTestCase {
    /// Builds a fixed Europe/Rome date at noon, to avoid any timezone-boundary
    /// flakiness when the formatter renders using the system default timezone.
    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Rome")!
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        return calendar.date(from: components)!
    }

    func testLongStringUsesItalianMonthName() {
        let date = makeDate(year: 2025, month: 3, day: 12)
        XCTAssertEqual(DateFormatting.longString(from: date), "12 marzo 2025")
    }

    func testLongStringUsesItalianMonthNameForDecember() {
        let date = makeDate(year: 2025, month: 12, day: 1)
        XCTAssertEqual(DateFormatting.longString(from: date), "1 dicembre 2025")
    }

    func testLongDateFormatterIsPinnedToItalianLocale() {
        XCTAssertEqual(DateFormatting.longDateFormatter.locale?.identifier, "it_IT")
    }

    func testShortDateFormatterIsPinnedToItalianLocale() {
        XCTAssertEqual(DateFormatting.shortDateFormatter.locale?.identifier, "it_IT")
    }

    func testRelativeStringProducesNonEmptyOutput() {
        let reference = makeDate(year: 2025, month: 3, day: 12)
        let earlier = makeDate(year: 2025, month: 1, day: 12)
        let result = DateFormatting.relativeString(from: earlier, relativeTo: reference)
        XCTAssertFalse(result.isEmpty)
    }
}
