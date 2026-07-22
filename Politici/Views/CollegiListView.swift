//
//  CollegiListView.swift
//  Politici
//

import SwiftUI

/// A searchable, fully VoiceOver-navigable alternative to selecting a
/// collegio by tapping its polygon on `MapView` — the map itself has no
/// accessible way to discover or select an `MKPolygon` overlay, so this
/// view provides the same destination (`DistrictDetailView`) through an
/// ordinary list instead. Reachable from `MapView`'s "Sfoglia come elenco"
/// toolbar button and `HomeView`'s "Collegi uninominali" stat card.
struct CollegiListView: View {
    @Binding var path: [AppRoute]
    @Environment(\.services) private var services
    @State private var selectedChamber: Chamber = .camera
    @State private var selectedCollegioType: CollegioType = .uninominale
    @State private var searchText = ""

    private var allDistricts: [District] {
        services.districtService
            .allDistricts(chamber: selectedChamber, collegioType: selectedCollegioType)
            .sorted { $0.name < $1.name }
    }

    private var filteredDistricts: [District] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmedSearch.isEmpty else { return allDistricts }
        let normalizedQuery = trimmedSearch.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
        return allDistricts.filter { district in
            let normalizedName = district.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
            if normalizedName.contains(normalizedQuery) { return true }
            // Camera districts group by circoscrizione, Senato by regione —
            // never both on the same district (see District.swift) — so
            // checking whichever is non-nil covers both chambers.
            let grouping = district.circoscrizione ?? district.regione
            guard let grouping else { return false }
            let normalizedGrouping = grouping.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
            return normalizedGrouping.contains(normalizedQuery)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ChamberPicker(selection: $selectedChamber)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            CollegioTypePicker(selection: $selectedCollegioType)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            if filteredDistricts.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List(filteredDistricts) { district in
                    Button {
                        path.append(.districtDetail(districtId: district.id))
                    } label: {
                        CollegioRow(district: district)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("collegio.row.\(district.id)")
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
                .listStyle(.plain)
            }
        }
        .searchable(text: $searchText, prompt: "Cerca per nome o circoscrizione/regione")
        .navigationTitle("Collegi (\(allDistricts.count))")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CollegioRow: View {
    let district: District

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "map.fill")
                .font(.system(size: 20))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(district.chamber == .camera ? Color.blue : Color.purple, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(district.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                // Camera rows show circoscrizione, Senato rows show
                // regione — never both (see District.swift).
                if let grouping = district.circoscrizione ?? district.regione {
                    Text(grouping)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Apre i dettagli del collegio")
    }
}

#Preview {
    NavigationStack {
        CollegiListView(path: .constant([]))
    }
}
