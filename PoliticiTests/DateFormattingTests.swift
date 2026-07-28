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

    /// Phase 31 regression guard. Every `Date` this project renders was parsed
    /// from a bare `yyyy-MM-dd` at **midnight Europe/Rome** (`parseISODate`,
    /// `Vote.dateFormatter`), so a display formatter left on the device's
    /// timezone renders the previous calendar day anywhere west of Rome —
    /// measured: `2026-07-22` came out "21 luglio 2026" under UTC,
    /// America/New_York and America/Los_Angeles. This asserts parse and format
    /// agree on the zone, which is the invariant and is meaningful on **any**
    /// runner; `testLongStringRoundTripsAMidnightRomeISODate` below is the
    /// behavioural half, and only bites on a non-Rome one.
    func testDisplayFormattersReadDatesInTheZoneTheParsersProduceThem() {
        let rome = TimeZone(identifier: "Europe/Rome")
        XCTAssertEqual(DateFormatting.longDateFormatter.timeZone, rome)
        XCTAssertEqual(DateFormatting.shortDateFormatter.timeZone, rome)
    }

    /// The user-visible claim: a `retrievedAt` / vote date string survives the
    /// parse-then-render round trip as the same calendar day. Note the fixture
    /// date is **midnight** Rome — the shape the app actually handles — not the
    /// noon `makeDate` above, which was written to dodge this very boundary.
    func testLongStringRoundTripsAMidnightRomeISODate() throws {
        let parsed = try XCTUnwrap(DateFormatting.parseISODate("2026-07-22"))
        XCTAssertEqual(DateFormatting.longString(from: parsed), "22 luglio 2026")
    }

    func testRelativeStringProducesNonEmptyOutput() {
        let reference = makeDate(year: 2025, month: 3, day: 12)
        let earlier = makeDate(year: 2025, month: 1, day: 12)
        let result = DateFormatting.relativeString(from: earlier, relativeTo: reference)
        XCTAssertFalse(result.isEmpty)
    }
}
