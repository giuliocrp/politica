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

    /// e.g. "12 marzo 2025"
    static let longDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = italianLocale
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }()

    /// e.g. "12/03/25"
    static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = italianLocale
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
