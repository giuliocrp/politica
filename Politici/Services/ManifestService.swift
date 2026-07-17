//
//  ManifestService.swift
//  Politici
//

import Foundation

/// Loads `sources.json` once and exposes the data-provenance manifest.
/// No UI consumes this yet — it exists so provenance is trackable in code
/// ahead of any "data source" screen.
final class ManifestService {
    static let shared = ManifestService()

    private(set) var manifest: SourcesManifest?
    private(set) var loadError: Error?

    init(resource: String = "sources", bundle: Bundle = .main) {
        do {
            manifest = try LocalJSONLoader.decode(SourcesManifest.self, fromResource: resource, bundle: bundle)
        } catch {
            loadError = error
            manifest = nil
        }
    }
}
