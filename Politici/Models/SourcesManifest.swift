//
//  SourcesManifest.swift
//  Politici
//

import Foundation

/// One entry in `Data/sources.json` describing where a dataset came from.
/// Dates stay raw ISO-8601 strings on the model; the two surfaces that need a
/// `Date` (`FontiEDatiView`'s per-source card and `ManifestService`'s
/// data-vintage line) parse at the edge via `DateFormatting.parseISODate`,
/// which lets an unparseable value degrade to an honest absence rather than
/// failing the whole decode.
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
