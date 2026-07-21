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

    /// The store the app actually runs with (see `ServiceContainer.live`).
    /// In release builds this is always `shared`, i.e. `.standard`-backed.
    /// In DEBUG it additionally honors the Phase 24 UI-test launch argument
    /// — see `uiTestSuite()`.
    static var live: UserDefaultsFavoritesStore {
        #if DEBUG
        if let suite = uiTestSuite() {
            return UserDefaultsFavoritesStore(defaults: suite)
        }
        #endif
        return shared
    }

    #if DEBUG
    /// UI-test seam (Phase 24): launching the app with
    /// `-favoritesSuite <name>` makes favorites persist in that named
    /// `UserDefaults` suite instead of `.standard`, and wipes the suite at
    /// launch so every UI test starts from a known-empty store without ever
    /// touching a real user's favorites. Reuses the store's existing
    /// `init(defaults:)` injection seam rather than adding a second one;
    /// reads the value through `.standard` because `-key value` launch
    /// arguments land in `UserDefaults`' argument domain. Compiled out of
    /// release builds entirely, and inert in DEBUG unless the argument is
    /// passed — the shipping app's behavior is unchanged either way.
    static func uiTestSuite() -> UserDefaults? {
        guard let name = UserDefaults.standard.string(forKey: "favoritesSuite"),
              !name.isEmpty,
              let suite = UserDefaults(suiteName: name) else { return nil }
        suite.removePersistentDomain(forName: name)
        return suite
    }
    #endif

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
