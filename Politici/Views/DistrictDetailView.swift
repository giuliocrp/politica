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
                Text("Nessun rappresentante collegato in questa versione del prototipo.")
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
    @Environment(\.services) private var services

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: representative.photoName)
                .font(.system(size: 34))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(services.partyStyleService.color(for: representative.party), in: Circle())

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

#Preview {
    NavigationStack {
        DistrictDetailView(districtId: "IT-RM-C01", path: .constant([]))
    }
}
