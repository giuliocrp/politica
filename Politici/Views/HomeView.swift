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
                comeFunzionaSection
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
                    .accessibilityHidden(true)
                TextField("Inserisci un indirizzo o una città", text: $addressQuery)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.search)
                    .onSubmit(navigateToSearch)
                    .accessibilityHint("Cerca il collegio elettorale per indirizzo o città")
                Button(action: navigateToSearch) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .disabled(addressQuery.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Cerca")
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
            Button {
                path.append(.collegiList)
            } label: {
                StatCard(value: "\(services.districtService.allDistricts().count)", label: "Collegi uninominali")
            }
            .buttonStyle(.plain)
            .accessibilityHint("Apre l'elenco completo dei collegi")

            Button {
                path.append(.representativeList)
            } label: {
                StatCard(value: "\(services.representativeService.allRepresentatives().count)", label: "Rappresentanti")
            }
            .buttonStyle(.plain)
            .accessibilityHint("Apre l'elenco completo dei rappresentanti")

            StatCard(value: "2", label: "Camere del Parlamento")
        }
    }

    private var comeFunzionaSection: some View {
        DisclosureGroup("Come funziona l'elezione") {
            VStack(alignment: .leading, spacing: 10) {
                BulletRow(text: "Alla Camera, 147 deputati sono eletti direttamente in un collegio uninominale: il loro nome è associato al collegio geografico che rappresentano, visibile sulla mappa.")
                BulletRow(text: "Gli altri deputati della Camera sono eletti con il sistema proporzionale (collegi plurinominali) o nella circoscrizione Estero: sono consultabili nell'elenco dei rappresentanti, ma non sono associati a un collegio geografico specifico.")
                BulletRow(text: "Al Senato, 73 dei 74 collegi uninominali mostrano il senatore eletto direttamente nel collegio (seleziona \"Senato\" nel selettore della mappa); un collegio è attualmente privo di senatore in carica nei dati ufficiali. Gli altri senatori — eletti con il sistema proporzionale, nella circoscrizione Estero o nominati a vita — sono consultabili nell'elenco dei rappresentanti, senza un'area specifica sulla mappa.")
            }
            .padding(.top, 8)
        }
        .font(.headline)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Rappresentanti in evidenza")
                    .font(.headline)
                Spacer()
                Button("Vedi tutti") {
                    path.append(.representativeList)
                }
                .font(.subheadline)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityHint("Apre l'elenco completo dei rappresentanti")
            }
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
        .frame(minHeight: 44)
        .contentShape(Rectangle())
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
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        HomeView(path: .constant([]))
    }
}
