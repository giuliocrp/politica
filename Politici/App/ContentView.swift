//
//  ContentView.swift
//  Politici
//
//  Created by Giulio Carpi Lapi on 16/07/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var path: [AppRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(path: $path)
                .navigationDestination(for: AppRoute.self) { route in
                    destination(for: route)
                }
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .map:
            MapView(path: $path)
        case .addressSearch(let initialQuery):
            AddressSearchView(path: $path, initialQuery: initialQuery)
        case .districtDetail(let districtId):
            DistrictDetailView(districtId: districtId, path: $path)
        case .representativeList:
            RepresentativeListView(path: $path)
        case .representativeProfile(let representativeId):
            RepresentativeProfileView(representativeId: representativeId, path: $path)
        case .voteHistory(let representativeId):
            VoteHistoryView(representativeId: representativeId)
        case .fontiEDati:
            FontiEDatiView()
        }
    }
}

#Preview {
    ContentView()
}
