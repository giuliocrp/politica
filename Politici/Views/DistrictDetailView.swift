//
//  DistrictDetailView.swift
//  Politici
//

import SwiftUI

struct DistrictDetailView: View {
    let districtId: String
    @Binding var path: [AppRoute]
    @Environment(\.services) private var services

    private var district: District? { services.districtService.district(withId: districtId) }
    private var representatives: [Representative] { services.representativeService.representatives(for: districtId) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let district {
                    header(for: district)
                    representativesSection
                } else {
                    ContentUnavailableView(
                        "Collegio non trovato",
                        systemImage: "map",
                        description: Text("Non è stato possibile trovare i dati per questo collegio.")
                    )
                    .padding(.top, 40)
                }
            }
            .padding()
        }
        .navigationTitle(district?.name ?? "Collegio")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func header(for district: District) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(district.name)
                .font(.largeTitle.bold())
            Label(
                district.chamber == .camera ? "Camera dei Deputati" : "Senato della Repubblica",
                systemImage: district.chamber == .camera ? "building.columns" : "building.columns.fill"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var representativesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rappresentanti eletti")
                .font(.headline)

            if representatives.isEmpty {
                Text("Nessun rappresentante trovato per questo collegio.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(representatives) { representative in
                    Button {
                        path.append(.representativeProfile(representativeId: representative.id))
                    } label: {
                        RepresentativeRow(representative: representative)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Shared avatar/name/party row used by `HomeView`'s featured list and here.
struct RepresentativeRow: View {
    let representative: Representative

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: representative.photoName)
                .font(.system(size: 34))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(PartyStyle.color(for: representative.party), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(representative.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(representative.party)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Maps a party name to a distinguishing accent color used across representative UI.
enum PartyStyle {
    static func color(for party: String) -> Color {
        switch party {
        case "Fratelli d'Italia": return .indigo
        case "Partito Democratico": return .red
        case "Movimento 5 Stelle": return .yellow
        case "Lega": return .green
        case "Forza Italia": return .blue
        case "Alleanza Verdi e Sinistra": return .mint
        case "Azione - Italia Viva": return .orange
        default: return .gray
        }
    }
}

#Preview {
    NavigationStack {
        DistrictDetailView(districtId: "IT-RM-C01", path: .constant([]))
    }
}
