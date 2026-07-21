//
//  FavoritesStoreTests.swift
//  PoliticiTests
//

import XCTest
@testable import Politici

/// Coverage for the Phase 19 favorites store (see docs/v3/19-preferiti.md),
/// exercised against a suite-scoped `UserDefaults` so no test ever touches
/// the real standard defaults. The storage key and payload shape asserted
/// here are the pinned `"favorites.v1"` contract.
final class FavoritesStoreTests: XCTestCase {
    private let suiteName = "FavoritesStoreTests"
    private let storageKey = "favorites.v1"
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testFirstRunIsEmpty() {
        let store = UserDefaultsFavoritesStore(defaults: defaults)
        XCTAssertTrue(store.favoriteIds.isEmpty)
    }

    func testToggleRoundTrip() {
        let store = UserDefaultsFavoritesStore(defaults: defaults)

        store.toggle("p123")
        XCTAssertTrue(store.isFavorite("p123"))
        XCTAssertEqual(store.favoriteIds, ["p123"])

        store.toggle("s45")
        XCTAssertEqual(store.favoriteIds, ["p123", "s45"], "starring order is preserved")

        store.toggle("p123")
        XCTAssertFalse(store.isFavorite("p123"))
        XCTAssertEqual(store.favoriteIds, ["s45"])
    }

    func testPersistenceAcrossInstances() {
        let first = UserDefaultsFavoritesStore(defaults: defaults)
        first.toggle("p123")
        first.toggle("s45")

        // A second instance over the same defaults models an app relaunch.
        let second = UserDefaultsFavoritesStore(defaults: defaults)
        XCTAssertEqual(second.favoriteIds, ["p123", "s45"])
    }

    func testCorruptPayloadResetsToEmptyAndStaysUsable() {
        defaults.set(Data("non è JSON".utf8), forKey: storageKey)

        let store = UserDefaultsFavoritesStore(defaults: defaults)
        XCTAssertTrue(store.favoriteIds.isEmpty, "corrupt payload must self-heal to empty")

        store.toggle("p123")
        XCTAssertEqual(UserDefaultsFavoritesStore(defaults: defaults).favoriteIds, ["p123"])
    }

    func testUnrecognizedSchemaVersionResetsToEmpty() {
        let futurePayload = #"{"schemaVersion":999,"representativeIds":["p123"]}"#
        defaults.set(Data(futurePayload.utf8), forKey: storageKey)

        let store = UserDefaultsFavoritesStore(defaults: defaults)
        XCTAssertTrue(store.favoriteIds.isEmpty, "an uninterpretable schema version is treated as corrupt, not guessed at")
    }

    func testLoadedDuplicatesAreDeduplicatedPreservingFirstOccurrence() {
        let payloadWithDupes = #"{"schemaVersion":1,"representativeIds":["a","b","a","c","b"]}"#
        defaults.set(Data(payloadWithDupes.utf8), forKey: storageKey)

        let store = UserDefaultsFavoritesStore(defaults: defaults)
        XCTAssertEqual(store.favoriteIds, ["a", "b", "c"])
    }

    func testResolvedFavoritesSkipsUnresolvableIdsAndLeavesStoreUntouched() throws {
        func representative(id: String) throws -> Representative {
            let json = """
            {
              "id": "\(id)",
              "name": "Test \(id)",
              "chamber": "Camera",
              "party": "Test",
              "parliamentaryGroup": "Test",
              "committees": [],
              "photoName": "person.crop.circle.fill"
            }
            """
            return try JSONDecoder().decode(Representative.self, from: Data(json.utf8))
        }
        let known = [
            "a": try representative(id: "a"),
            "b": try representative(id: "b"),
        ]

        let store = UserDefaultsFavoritesStore(defaults: defaults)
        store.toggle("a")
        store.toggle("sparito")
        store.toggle("b")

        let resolved = PreferitiView.resolvedFavorites(ids: store.favoriteIds) { known[$0] }

        XCTAssertEqual(resolved.map(\.id), ["a", "b"], "unresolvable ids are skipped, order preserved")
        XCTAssertEqual(
            store.favoriteIds, ["a", "sparito", "b"],
            "resolution must never delete unresolvable ids from the store"
        )
    }
}
