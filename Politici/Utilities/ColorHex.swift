//
//  ColorHex.swift
//  Politici
//

import SwiftUI

extension Color {
    /// Parses a `"#RRGGBB"` (or `"RRGGBB"`) string into an opaque `Color`.
    /// Returns `nil` for anything else, rather than silently falling back to
    /// a default color that could mask a data-entry mistake in Data/parties.json.
    init?(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.hasPrefix("#") {
            sanitized.removeFirst()
        }
        guard sanitized.count == 6, let rgb = UInt32(sanitized, radix: 16) else {
            return nil
        }
        let red = Double((rgb >> 16) & 0xFF) / 255
        let green = Double((rgb >> 8) & 0xFF) / 255
        let blue = Double(rgb & 0xFF) / 255
        self = Color(red: red, green: green, blue: blue)
    }
}
