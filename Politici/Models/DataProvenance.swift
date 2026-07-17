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
enum DataProvenance: String, Codable, Hashable {
    case sample
    case official

    var displayName: String {
        switch self {
        case .sample: return "Dati dimostrativi"
        case .official: return "Fonte ufficiale"
        }
    }
}
