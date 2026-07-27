//
//  NameFolding.swift
//  Politici
//

import Foundation

/// The project's established place-name normalization: fold away diacritics
/// and case, using an Italian locale, then trim surrounding whitespace. Used
/// to match a free-text query against bundled comune names
/// (`ComuneService`) and the offline sample-city table
/// (`GeocodingService.fallbackCoordinate`) the same way, so "CHÂTILLON",
/// "châtillon" and "Chatillon" all resolve to the same comune.
///
/// This only removes accents and case — it does **not** invent bilingual
/// exonyms. The bundled comuni table (ISTAT `UT_Collegi2020`) carries
/// Italian-only comune names (`Bolzano`, not `Bolzano/Bozen`; verified in
/// docs/v4/30-comuni-geocoding.md), so a German-only query does not resolve;
/// a bilingual `"X/Y"` query is handled on the query side by matching either
/// side (see `ComuneService.comuni(matching:)`).
enum NameFolding {
    static func fold(_ text: String) -> String {
        text.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "it_IT")
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
