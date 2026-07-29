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
/// `nonisolated` — the same declaration `DataProvenance` uses, and for the
/// same reason. The project builds with `SWIFT_DEFAULT_ACTOR_ISOLATION =
/// MainActor`, so without it `fold` is MainActor-isolated and passing it as a
/// function value to a nonisolated closure parameter warns:
/// `ComuneService.comuni(matching:)` does exactly that
/// (`.map(NameFolding.fold)`), which made the **Release** build emit "call to
/// main actor-isolated static method 'fold' in a synchronous nonisolated
/// context". Folding a string touches no actor state, so nonisolated is the
/// accurate annotation rather than a workaround. Found and fixed in v4 Phase
/// 32A's release verification; pre-existing since Phase 30.
nonisolated enum NameFolding {
    static func fold(_ text: String) -> String {
        text.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "it_IT")
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
