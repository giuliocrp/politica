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
    /// runner; `testInjectedNonRomeZonesShiftTheDayWhileTheShippedFormattersDoNot`
    /// below is the behavioural half.
    ///
    /// Covers **every** formatter `DateFormatting` vends, not only the two the
    /// phase exercised: the long and short display formatters, and the
    /// relative formatter — which nothing renders today but which measures its
    /// interval in its calendar's zone and so carries the same latent bug. The
    /// ISO parser was already Europe/Rome before Phase 31 and is covered
    /// transitively by the round-trip assertions.
    func testDisplayFormattersReadDatesInTheZoneTheParsersProduceThem() throws {
        let rome = try XCTUnwrap(TimeZone(identifier: "Europe/Rome"))
        XCTAssertEqual(DateFormatting.romeTimeZone, rome)
        XCTAssertEqual(DateFormatting.longDateFormatter.timeZone, rome)
        XCTAssertEqual(DateFormatting.shortDateFormatter.timeZone, rome)
        XCTAssertEqual(DateFormatting.makeRelativeFormatter(timeZone: rome).calendar.timeZone, rome)
    }

    /// The user-visible claim: a `retrievedAt` / vote date string survives the
    /// parse-then-render round trip as the same calendar day. Note the fixture
    /// date is **midnight** Rome — the shape the app actually handles — not the
    /// noon `makeDate` above, which was written to dodge this very boundary.
    func testLongStringRoundTripsAMidnightRomeISODate() throws {
        let parsed = try XCTUnwrap(DateFormatting.parseISODate("2026-07-22"))
        XCTAssertEqual(DateFormatting.longString(from: parsed), "22 luglio 2026")
        XCTAssertEqual(DateFormatting.shortString(from: parsed), "22/07/26")
    }

    /// The host-independent half of the guard (Phase 31 closeout). The two
    /// tests above are both satisfiable on a Europe/Rome runner even with the
    /// pin removed — the round trip because the device zone *is* Rome there,
    /// so it proves nothing about the defect on this machine. This one injects
    /// the zone instead of inheriting it, so it exercises the actual mechanism
    /// wherever it runs: the same formatter configuration, built against a
    /// non-Rome zone, renders the previous calendar day.
    func testInjectedNonRomeZonesShiftTheDayWhileTheShippedFormattersDoNot() throws {
        let parsed = try XCTUnwrap(DateFormatting.parseISODate("2026-07-22"))

        // Everything west of Rome: midnight Rome is still the previous day.
        // This is the configuration Phase 31 replaced.
        for identifier in ["UTC", "America/New_York", "America/Los_Angeles"] {
            let zone = try XCTUnwrap(TimeZone(identifier: identifier))
            XCTAssertEqual(
                DateFormatting.makeLongDateFormatter(timeZone: zone).string(from: parsed),
                "21 luglio 2026",
                "\(identifier) dovrebbe rendere il giorno precedente"
            )
            XCTAssertEqual(
                DateFormatting.makeShortDateFormatter(timeZone: zone).string(from: parsed),
                "21/07/26",
                "\(identifier) dovrebbe rendere il giorno precedente"
            )
        }

        // East of it the day is unchanged — the defect is directional, which is
        // why a Rome (or Tokyo) runner could never surface it.
        let tokyo = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        XCTAssertEqual(
            DateFormatting.makeLongDateFormatter(timeZone: tokyo).string(from: parsed),
            "22 luglio 2026"
        )

        // The shipped formatters are pinned, so they are unaffected by any of
        // the above regardless of the host this runs on.
        XCTAssertEqual(DateFormatting.longDateFormatter.string(from: parsed), "22 luglio 2026")
        XCTAssertEqual(DateFormatting.shortDateFormatter.string(from: parsed), "22/07/26")
    }


    func testRelativeStringProducesNonEmptyOutput() {
        let reference = makeDate(year: 2025, month: 3, day: 12)
        let earlier = makeDate(year: 2025, month: 1, day: 12)
        let result = DateFormatting.relativeString(from: earlier, relativeTo: reference)
        XCTAssertFalse(result.isEmpty)
    }
}
