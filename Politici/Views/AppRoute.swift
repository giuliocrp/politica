//
//  AppRoute.swift
//  Politici
//

import Foundation

/// Every screen reachable via the root `NavigationStack`, keyed by the domain
/// identifiers needed to load that screen's data.
enum AppRoute: Hashable {
    case map
    case addressSearch(initialQuery: String)
    case districtDetail(districtId: String)
    case collegiList
    case representativeList
    case representativeProfile(representativeId: String)
    case voteHistory(representativeId: String)
    case fontiEDati
}
