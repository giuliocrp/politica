//
//  FavoritesStore.swift
//  Politici
//

import Foundation
import Observation

/// Local favorites (Phase 19): the ids of starred representatives, in the
/// order they were starred. Purely local state — persisted in
/// `UserDefaults`, never leaves the device (see CLAUDE.md's local-first
/// constraint).
protocol FavoritesStore: AnyObject {
    var favoriteIds: [String] { get }
    func isFavorite(_ representativeId: String) -> Bool
    func toggle(_ representativeId: String)
}

/// `UserDefaults`-backed implementation. Payload contract (pinned, also
/// asserted by FavoritesStoreTests): JSON
/// `{"schemaVersion":1,"representativeIds":[...]}` under the key
/// `"favorites.v1"`. A corrupt or unrecognized payload self-heals to empty
/// with a console warning rather than crashing or guessing.
///
/// Observation model — a recorded Phase 19 decision (see
/// docs/v3/19-preferiti.md): `@Observable` rather than the codebase's one
/// pre-existing `ObservableObject` (`AddressAutocompleteService`). The
/// iOS 17.0 deployment target permits it, and it's what lets views react
/// to favorite changes through the plain `@Environment(\.services)`
/// container access every view already uses — `ObservableObject` would
/// need an `@ObservedObject` wrapper on a concrete class type, which the
/// container's protocol-typed property can't provide.
@Observable
final class UserDefaultsFavoritesStore: FavoritesStore {
    static let shared = UserDefaultsFavoritesStore()

    private static let storageKey = "favorites.v1"
    private static let schemaVersion = 1

    private struct Payload: Codable {
        var schemaVersion: Int
        var representativeIds: [String]
    }

    private let defaults: UserDefaults
    private(set) var favoriteIds: [String]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.favoriteIds = Self.load(from: defaults)
    }

    func isFavorite(_ representativeId: String) -> Bool {
        favoriteIds.contains(representativeId)
    }

    func toggle(_ representativeId: String) {
        if let index = favoriteIds.firstIndex(of: representativeId) {
            favoriteIds.remove(at: index)
        } else {
            favoriteIds.append(representativeId)
        }
        persist()
    }

    private func persist() {
        let payload = Payload(
            schemaVersion: Self.schemaVersion,
            representativeIds: Self.deduplicated(favoriteIds)
        )
        if let data = try? JSONEncoder().encode(payload) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    private static func load(from defaults: UserDefaults) -> [String] {
        guard let data = defaults.data(forKey: storageKey) else {
            return []  // first run — no payload is not corruption, no warning
        }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data),
              payload.schemaVersion == schemaVersion else {
            print("FavoritesStore: corrupt or unrecognized payload under '\(storageKey)' — resetting to empty")
            defaults.removeObject(forKey: storageKey)
            return []
        }
        return deduplicated(payload.representativeIds)
    }

    /// Order-preserving (first occurrence wins). Applied on load (heals a
    /// payload written by anything buggier than `toggle`, which itself
    /// can't produce duplicates) and again on write, per the Phase 19 spec.
    static func deduplicated(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.filter { seen.insert($0).inserted }
    }
}
