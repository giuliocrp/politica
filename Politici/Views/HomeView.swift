//
//  HomeView.swift
//  Politici
//

import SwiftUI

struct HomeView: View {
    @Binding var path: [AppRoute]
    @Environment(\.services) private var services
    @State private var addressQuery: String = ""

    private var featuredRepresentatives: [Representative] {
        Array(services.representativeService.allRepresentatives().prefix(4))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                searchSection
                mapCTA
                statsSection
                featuredSection
                footer
            }
            .padding()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    path.append(.fontiEDati)
                } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel("Informazioni e fonti")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Politica Italia")
                .font(.largeTitle.bold())
            Text("Scopri il tuo collegio elettorale, i rappresentanti in Parlamento e il loro operato — un prototipo locale, senza account né connessione a Internet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Trova il tuo collegio")
                .font(.headline)
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Inserisci un indirizzo o una città", text: $addressQuery)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.search)
                    .onSubmit(navigateToSearch)
                Button(action: navigateToSearch) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                }
                .disabled(addressQuery.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var mapCTA: some View {
        Button {
            path.append(.map)
        } label: {
            Label("Esplora la Mappa Interattiva", systemImage: "map.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
    }

    private var statsSection: some View {
        HStack(spacing: 12) {
            StatCard(value: "\(services.districtService.allDistricts().count)", label: "Collegi campione")
            StatCard(value: "\(services.representativeService.allRepresentatives().count)", label: "Rappresentanti")
            StatCard(value: "2", label: "Camere del Parlamento")
        }
    }

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rappresentanti in evidenza")
                .font(.headline)
            ForEach(featuredRepresentatives) { representative in
                Button {
                    path.append(.representativeProfile(representativeId: representative.id))
                } label: {
                    RepresentativeRow(representative: representative)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var footer: some View {
        Button {
            path.append(.fontiEDati)
        } label: {
            Text("Informazioni e fonti")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 4)
    }

    private func navigateToSearch() {
        guard !addressQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        path.append(.addressSearch(initialQuery: addressQuery))
    }
}

private struct StatCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    NavigationStack {
        HomeView(path: .constant([]))
    }
}
