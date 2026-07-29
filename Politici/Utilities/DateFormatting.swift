//
//  DateFormatting.swift
//  Politici
//

import Foundation

enum DateFormatting {
    static let italianLocale = Locale(identifier: "it_IT")

    /// The zone every date in this project is *produced* in: both ISO parsers
    /// (`parseISODate` below and `Vote.dateFormatter`) turn a bare
    /// `yyyy-MM-dd` into **midnight Europe/Rome**. Every formatter here must
    /// read them back in that same zone, or the rendered calendar day is
    /// wrong.
    ///
    /// This bit the display formatters before it was pinned (fixed in Phase 31
    /// — `docs/v4/31-live-refresh-adr.md` §8): left on the device's timezone,
    /// midnight in Rome is the *previous* day anywhere west of it, so
    /// `2026-07-22` rendered as "21 luglio 2026" under UTC and every US zone —
    /// silently shifting each vote's date and each source's retrieval date by
    /// one day for those users. Do not relax any formatter here to the device
    /// zone: these are Rome calendar days (sitting dates, retrieval dates),
    /// not instants to be localized.
    ///
    /// Internal rather than private so `DateFormattingTests` can inject other
    /// zones into the `make…` factories below and prove, on any host, that the
    /// zone is what decides the rendered day.
    static let romeTimeZone = TimeZone(identifier: "Europe/Rome")

    // MARK: - Parsing

    private static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = romeTimeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Parses a `yyyy-MM-dd` ISO-8601 date string, e.g. as found in Data/sources.json.
    static func parseISODate(_ string: String) -> Date? {
        isoDateFormatter.date(from: string)
    }

    // MARK: - Display formatters
    //
    // Each is built by a `make…(timeZone:)` factory that is the single source
    // of its configuration, so a test can build the identical formatter
    // against an injected zone. Without that seam the timezone guard would
    // only bite on a runner that is itself outside Europe/Rome.

    /// e.g. "12 marzo 2025"
    static func makeLongDateFormatter(timeZone: TimeZone?) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = italianLocale
        formatter.timeZone = timeZone
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }

    /// e.g. "12/03/25"
    static func makeShortDateFormatter(timeZone: TimeZone?) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = italianLocale
        formatter.timeZone = timeZone
        formatter.dateStyle = .short
        return formatter
    }

    /// e.g. "2 mesi fa", "tra 3 giorni".
    ///
    /// `RelativeDateTimeFormatter` measures the gap between two instants in
    /// *its calendar's* timezone, so it is the same class of bug as the two
    /// above — near a day boundary an unpinned zone can move "1 giorno fa" to
    /// "2 giorni fa". Pinned for the same reason, even though nothing in the
    /// app renders a relative date today.
    static func makeRelativeFormatter(timeZone: TimeZone?) -> RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = italianLocale
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = italianLocale
        if let timeZone { calendar.timeZone = timeZone }
        formatter.calendar = calendar
        formatter.unitsStyle = .full
        return formatter
    }

    static let longDateFormatter: DateFormatter = makeLongDateFormatter(timeZone: romeTimeZone)

    static let shortDateFormatter: DateFormatter = makeShortDateFormatter(timeZone: romeTimeZone)

    static func longString(from date: Date) -> String {
        longDateFormatter.string(from: date)
    }

    static func shortString(from date: Date) -> String {
        shortDateFormatter.string(from: date)
    }

    static func relativeString(from date: Date, relativeTo reference: Date = Date()) -> String {
        makeRelativeFormatter(timeZone: romeTimeZone).localizedString(for: date, relativeTo: reference)
    }
}
