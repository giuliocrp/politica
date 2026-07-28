//
//  DateFormatting.swift
//  Politici
//

import Foundation

enum DateFormatting {
    static let italianLocale = Locale(identifier: "it_IT")

    private static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Rome")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Parses a `yyyy-MM-dd` ISO-8601 date string, e.g. as found in Data/sources.json.
    static func parseISODate(_ string: String) -> Date? {
        isoDateFormatter.date(from: string)
    }

    /// The zone every date in this project is *produced* in: both ISO parsers
    /// (`parseISODate` above and `Vote.dateFormatter`) turn a bare `yyyy-MM-dd`
    /// into **midnight Europe/Rome**. The display formatters below must read
    /// them back in that same zone, or the rendered calendar day is wrong.
    ///
    /// This bit them before it was pinned (fixed in Phase 31 —
    /// `docs/v4/31-live-refresh-adr.md` §8): left on the device's timezone,
    /// midnight in Rome is the *previous* day anywhere west of it, so
    /// `2026-07-22` rendered as "21 luglio 2026" under UTC and every US zone —
    /// silently shifting each vote's date and each source's retrieval date by
    /// one day for those users. Do not relax this to the device zone: these
    /// are Rome calendar days (sitting dates, retrieval dates), not instants
    /// to be localized.
    private static let romeTimeZone = TimeZone(identifier: "Europe/Rome")

    /// e.g. "12 marzo 2025"
    static let longDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = italianLocale
        formatter.timeZone = romeTimeZone
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }()

    /// e.g. "12/03/25"
    static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = italianLocale
        formatter.timeZone = romeTimeZone
        formatter.dateStyle = .short
        return formatter
    }()

    static func longString(from date: Date) -> String {
        longDateFormatter.string(from: date)
    }

    static func shortString(from date: Date) -> String {
        shortDateFormatter.string(from: date)
    }

    /// e.g. "2 mesi fa", "tra 3 giorni"
    static func relativeString(from date: Date, relativeTo reference: Date = Date()) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = italianLocale
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: reference)
    }
}
