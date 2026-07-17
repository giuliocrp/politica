//
//  SourcesManifest.swift
//  Politici
//

import Foundation

/// One entry in `Data/sources.json` describing where a dataset came from.
/// Dates are kept as raw ISO-8601 strings rather than parsed `Date`s — this
/// manifest has no UI in v2 yet, so there's no formatting need to justify the
/// extra parsing surface.
struct DataSource: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let url: String
    let license: String
    let retrievedAt: String
    let notes: String
}

/// Top-level contents of `Data/sources.json`, tracking data provenance
/// separately from the domain data itself.
struct SourcesManifest: Codable, Hashable {
    let schemaVersion: Int
    let generatedAt: String
    let sources: [DataSource]
}
