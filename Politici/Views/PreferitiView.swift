//
//  PreferitiView.swift
//  Politici
//

import SwiftUI

/// The starred representatives, in starring order (Phase 19 — see
/// docs/v3/19-preferiti.md). Ids that no longer resolve against the
/// current dataset (e.g. a representative dropped by a future data
/// refresh) are skipped at render but deliberately retained in the store —
/// hiding is reversible, deleting the user's data is not.
struct PreferitiView: View {
    @Binding var path: [AppRoute]
    @Environment(\.services) private var services

    private var favorites: [Representative] {
        Self.resolvedFavorites(
            ids: services.favoritesStore.favoriteIds,
            lookup: services.representativeService.representative(withId:)
        )
    }

    var body: some View {
        ScrollView {
            if favorites.isEmpty {
                ContentUnavailableView(
                    "Nessun preferito.",
                    systemImage: "star",
                    description: Text("Tocca la stella sul profilo di un rappresentante per aggiungerlo.")
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(favorites) { representative in
                        Button {
                            path.append(.representativeProfile(representativeId: representative.id))
                        } label: {
                            RepresentativeRow(representative: representative)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Preferiti")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Pure resolution step, unit-tested in isolation: unresolvable ids are
    /// skipped, order is preserved, and the input list is never mutated —
    /// the store keeps unresolvable ids untouched.
    static func resolvedFavorites(
        ids: [String],
        lookup: (String) -> Representative?
    ) -> [Representative] {
        ids.compactMap(lookup)
    }
}

#Preview {
    NavigationStack {
        PreferitiView(path: .constant([]))
    }
}
