//
//  RepresentativeListView.swift
//  Politici
//

import SwiftUI

/// Browses all 601 representatives (Camera + Senato), searchable by name and
/// filterable by party. Reachable from `HomeView`'s stat card and "Vedi
/// tutti" link — the Home screen itself only ever shows a 4-item preview.
struct RepresentativeListView: View {
    @Binding var path: [AppRoute]
    @Environment(\.services) private var services
    @State private var searchText = ""
    @State private var selectedPartyShortName: String?

    private var allRepresentatives: [Representative] {
        services.representativeService.allRepresentatives()
    }

    /// Distinct party short names actually present in the data, sorted
    /// alphabetically. Filtering by short name (rather than the raw `party`
    /// string) merges the Camera-sigla/Senato-full-name spelling variants of
    /// the same party (e.g. "FDI" and "Fratelli d'Italia" both -> "FdI")
    /// into a single chip, instead of showing visually duplicate chips.
    private var availablePartyShortNames: [String] {
        let shortNames = allRepresentatives.map { services.partyStyleService.shortName(for: $0.party) }
        return Array(Set(shortNames)).sorted()
    }

    private var filteredRepresentatives: [Representative] {
        var result = allRepresentatives
        if let selectedPartyShortName {
            result = result.filter { services.partyStyleService.shortName(for: $0.party) == selectedPartyShortName }
        }
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespaces)
        if !trimmedSearch.isEmpty {
            let normalizedQuery = trimmedSearch.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .italian)
            result = result.filter {
                $0.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .italian).contains(normalizedQuery)
            }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            partyFilterChips

            if filteredRepresentatives.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List(filteredRepresentatives) { representative in
                    Button {
                        path.append(.representativeProfile(representativeId: representative.id))
                    } label: {
                        RepresentativeRow(representative: representative)
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
                .listStyle(.plain)
            }
        }
        .searchable(text: $searchText, prompt: "Cerca per nome")
        .navigationTitle("Rappresentanti (\(allRepresentatives.count))")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var partyFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                PartyFilterChip(label: "Tutti", color: .secondary, isSelected: selectedPartyShortName == nil) {
                    selectedPartyShortName = nil
                }
                ForEach(availablePartyShortNames, id: \.self) { shortName in
                    PartyFilterChip(
                        label: shortName,
                        color: colorForShortName(shortName),
                        isSelected: selectedPartyShortName == shortName
                    ) {
                        selectedPartyShortName = selectedPartyShortName == shortName ? nil : shortName
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    /// The chip's accent color: any real party value that maps to this
    /// short name shares the same color by construction (see
    /// docs/v2/02-post-import-audit.md), so the first match is
    /// representative of them all.
    private func colorForShortName(_ shortName: String) -> Color {
        guard let party = allRepresentatives.first(where: { services.partyStyleService.shortName(for: $0.party) == shortName })?.party else {
            return .secondary
        }
        return services.partyStyleService.color(for: party)
    }
}

private struct PartyFilterChip: View {
    let label: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(isSelected ? .bold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? .white : color)
                .background(isSelected ? color : color.opacity(0.12), in: Capsule())
                .overlay(Capsule().strokeBorder(color.opacity(isSelected ? 0 : 0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private extension Locale {
    static let italian = Locale(identifier: "it_IT")
}

#Preview {
    NavigationStack {
        RepresentativeListView(path: .constant([]))
    }
}
