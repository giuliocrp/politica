//
//  DataProvenance.swift
//  Politici
//

import Foundation

/// Marks whether a record's data is the app's fictional demo content or a
/// real, sourced record. Every model in v2 defaults to `.sample` when this
/// field is absent from JSON, so existing fixtures keep decoding unchanged —
/// see `docs/v2/00-audit.md` and `CLAUDE.md` constraint #4 (never present
/// fictional data as real).
nonisolated enum DataProvenance: String, Codable, Hashable {
    case sample
    case official

    /// Not currently rendered anywhere: the representative profile's provenance
    /// badge was its only surface, and the post-v4 tidy removed it (every
    /// shipping record is `.official`, so the badge said the same thing on
    /// every profile). Kept because `provenance` itself is still decoded,
    /// asserted across the suite, and load-bearing for constraint #4.
    var displayName: String {
        switch self {
        case .sample: return "Dati dimostrativi"
        case .official: return "Fonte ufficiale"
        }
    }
}
