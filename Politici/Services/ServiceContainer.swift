//
//  ServiceContainer.swift
//  Politici
//

import SwiftUI

/// Bundles the app's local-first services so they're constructed once at launch
/// and injected into the view hierarchy via the SwiftUI environment, instead of
/// every view reaching for a `.shared` singleton directly.
struct ServiceContainer {
    let districtService: DistrictService
    let representativeService: RepresentativeService
    let voteService: VoteService
    /// Phase 28 — parliamentary-group membership intervals. No view consumes
    /// it yet; it's wired here so the Phase 29 alignment metric can inject it
    /// through the environment like every other service.
    let membershipService: MembershipService
    let geocodingService: GeocodingService
    /// Phase 30 — the offline comuni-centroid table. Backs `GeocodingService`'s
    /// middle tier and `AddressSearchView`'s up-front homonym disambiguation.
    let comuneService: ComuneService
    let manifestService: ManifestService
    let partyStyleService: PartyStyleService
    let favoritesStore: any FavoritesStore

    static let live = ServiceContainer(
        districtService: .shared,
        representativeService: .shared,
        voteService: .shared,
        membershipService: .shared,
        geocodingService: .live,
        comuneService: .shared,
        manifestService: .shared,
        partyStyleService: .shared,
        favoritesStore: UserDefaultsFavoritesStore.live
    )
}

private struct ServiceContainerKey: EnvironmentKey {
    static let defaultValue = ServiceContainer.live
}

extension EnvironmentValues {
    var services: ServiceContainer {
        get { self[ServiceContainerKey.self] }
        set { self[ServiceContainerKey.self] = newValue }
    }
}
