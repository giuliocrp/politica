//
//  Initials.swift
//  Politici
//

import Foundation

enum Initials {
    /// e.g. "Andrea Giorgio Felice Maria Orsini" -> "AO" (first letter of the
    /// first and last name token, uppercased). Falls back to a single letter
    /// for a one-word name, and "?" for an empty/whitespace-only one.
    static func from(_ name: String) -> String {
        let tokens = name.split(separator: " ").filter { !$0.isEmpty }
        guard let first = tokens.first?.first else { return "?" }
        guard tokens.count > 1, let last = tokens.last?.first else {
            return String(first).uppercased()
        }
        return String([first, last]).uppercased()
    }
}
