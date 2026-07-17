//
//  RepresentativeService.swift
//  Politici
//

import Foundation

/// Loads `representatives.json` once and answers representative lookups.
final class RepresentativeService {
    static let shared = RepresentativeService()

    private(set) var representatives: [Representative] = []
    private(set) var loadError: Error?

    init(resource: String = "representatives", bundle: Bundle = .main) {
        do {
            representatives = try LocalJSONLoader.decode(
                [Representative].self,
                fromResource: resource,
                bundle: bundle
            )
        } catch {
            loadError = error
            representatives = []
        }
    }

    func allRepresentatives() -> [Representative] {
        representatives
    }

    func representative(withId id: String) -> Representative? {
        representatives.first { $0.id == id }
    }

    func representatives(for districtId: String) -> [Representative] {
        representatives.filter { $0.districtId == districtId }
    }
}
