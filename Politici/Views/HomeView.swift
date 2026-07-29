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
                votazioniCTA
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
                .accessibilityIdentifier("home.title")
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
                    .accessibilityIdentifier("home.search.field")
                Button(action: navigateToSearch) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .disabled(addressQuery.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Cerca")
                .accessibilityIdentifier("home.search.submit")
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
        .accessibilityIdentifier("home.cta.map")
    }

    private var statsSection: some View {
        // 2×2 since Phase 19's Preferiti card joined the original three —
        // four cards in one HStack would cramp on smaller widths.
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            Button {
                path.append(.collegiList)
            } label: {
                StatCard(value: "\(services.districtService.allDistricts(collegioType: .uninominale).count)", label: "Collegi uninominali")
            }
            .buttonStyle(.plain)
            .accessibilityHint("Apre l'elenco completo dei collegi")
            .accessibilityIdentifier("home.stat.collegi")

            Button {
                path.append(.representativeList)
            } label: {
                StatCard(value: "\(services.representativeService.allRepresentatives().count)", label: "Rappresentanti")
            }
            .buttonStyle(.plain)
            .accessibilityHint("Apre l'elenco completo dei rappresentanti")
            .accessibilityIdentifier("home.stat.rappresentanti")

            StatCard(value: "2", label: "Camere del Parlamento")
                .accessibilityIdentifier("home.stat.camere")

            Button {
                path.append(.preferiti)
            } label: {
                StatCard(value: "\(services.favoritesStore.favoriteIds.count)", label: "Preferiti")
            }
            .buttonStyle(.plain)
            .accessibilityHint("Apre l'elenco dei preferiti")
            .accessibilityIdentifier("home.stat.preferiti")
        }
    }

    private var votazioniCTA: some View {
        Button {
            path.append(.votazioniList)
        } label: {
            Label("Votazioni in Aula (campione)", systemImage: "checklist")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .accessibilityHint("Apre l'elenco delle votazioni importate")
        .accessibilityIdentifier("home.cta.votazioni")
    }

    private var comeFunzionaSection: some View {
        DisclosureGroup("Come funziona l'elezione") {
            VStack(alignment: .leading, spacing: 10) {
                BulletRow(text: "Alla Camera, 147 deputati sono eletti direttamente in un collegio uninominale: il loro nome è associato al collegio geografico che rappresentano, visibile sulla mappa.")
                BulletRow(text: "Gli altri deputati della Camera sono eletti con il sistema proporzionale nei collegi plurinominali o nella circoscrizione Estero. I 49 collegi plurinominali della Camera sono ora visibili sulla mappa (seleziona \"Plurinominali\" nel selettore): la pagina di ciascuno elenca i deputati eletti in quel collegio, e ogni pagina di collegio uninominale mostra i deputati plurinominali della sua circoscrizione. I deputati eletti all'Estero restano consultabili solo nell'elenco dei rappresentanti.")
                BulletRow(text: "Al Senato, 73 dei 74 collegi uninominali mostrano il senatore eletto direttamente nel collegio (seleziona \"Senato\" nel selettore della mappa); un collegio è attualmente privo di senatore in carica nei dati ufficiali. Ogni pagina di collegio uninominale del Senato elenca anche i senatori eletti con il sistema proporzionale nella sua regione. Sono visibili anche i 26 collegi plurinominali del Senato, come geografia, ma nessun senatore è ancora collegato al proprio collegio in questo prototipo. I senatori eletti nella circoscrizione Estero o nominati a vita restano consultabili solo nell'elenco dei rappresentanti.")
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
                .accessibilityIdentifier("representative.row.\(representative.id)")
            }
        }
    }

    /// The data-vintage line sits *inside* the "Informazioni e fonti" button
    /// rather than beside it: the footer states one fact — the last retrieval
    /// across every source — and the per-source breakdown that qualifies it is
    /// then one tap away. It is deliberately a plain statement with no
    /// threshold and no warning colour (Phase 31 — docs/v4/31-live-refresh-adr.md
    /// §7); when the manifest fails to load the line is simply absent, never a
    /// placeholder date. No `accessibilityIdentifier` is set on the inner
    /// `Text`s: they are inside a `Button` label, so the button is the single
    /// accessibility element and a child identifier would be unreachable —
    /// the shadowing trap `CLAUDE.md` records from Phase 30B.
    private var footer: some View {
        Button {
            path.append(.fontiEDati)
        } label: {
            VStack(spacing: 4) {
                Text("Informazioni e fonti")
                    .font(.footnote)
                if let vintage = services.manifestService.dataVintageText {
                    Text(vintage)
                        .font(.caption)
                }
            }
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityIdentifier("home.footer.fonti")
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
