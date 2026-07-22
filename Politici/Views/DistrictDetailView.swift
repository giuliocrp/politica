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
                    if district.collegioType == .plurinominale {
                        plurinominaleCollegioSection(for: district)
                    } else {
                        representativesSection(for: district)
                        plurinominaleSection(for: district)
                    }
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
            if let regione = district.regione {
                Text("Regione: \(regione)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("district.header")
    }

    private func representativesSection(for district: District) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Camera pages name the seat's electoral nature explicitly
            // (Phase 18); Senato pages keep the Phase 16 title.
            Text(district.chamber == .camera ? "Eletto nel collegio uninominale" : "Rappresentanti eletti")
                .font(.headline)
                .accessibilityIdentifier("district.section.uninominale")

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
                    .accessibilityIdentifier("representative.row.\(representative.id)")
                }
            }
        }
    }

    /// Camera only (Phase 18): the plurinominale deputies of this
    /// collegio's circoscrizione. Estero deputies never appear here — the
    /// service filter excludes them by electionType, and "Estero" is never
    /// a district's circoscrizione.
    @ViewBuilder
    private func plurinominaleSection(for district: District) -> some View {
        if district.chamber == .camera, let circoscrizione = district.circoscrizione {
            let deputies = services.representativeService.plurinominaleRepresentatives(
                inCircoscrizione: circoscrizione
            )
            VStack(alignment: .leading, spacing: 12) {
                Text("Rappresentanti plurinominali della circoscrizione \(circoscrizione)")
                    .font(.headline)
                    .accessibilityIdentifier("district.section.plurinominale")
                Text("Eletti con il sistema proporzionale nei collegi plurinominali della circoscrizione: rappresentano l'intera circoscrizione, non questo specifico collegio uninominale.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if deputies.isEmpty {
                    Text("Nessun deputato plurinominale in questa circoscrizione.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(deputies) { deputy in
                        Button {
                            path.append(.representativeProfile(representativeId: deputy.id))
                        } label: {
                            RepresentativeRow(representative: deputy)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("representative.row.\(deputy.id)")
                    }
                }
            }
        }
    }

    /// A plurinominale-collegio page (Phase 25): the deputies elected here by
    /// proportional list. Camera only carries the linkage; a Senato
    /// plurinominale collegio ships as geography with an honest empty state
    /// (senators aren't yet linked to a collegio in this prototype — the same
    /// stance the Senato uninominale layer took at Phase 16).
    private func plurinominaleCollegioSection(for district: District) -> some View {
        let deputies = district.chamber == .camera
            ? services.representativeService.deputies(inPlurinominaleCollegio: district.id)
            : []
        return VStack(alignment: .leading, spacing: 12) {
            Text(district.chamber == .camera
                ? "Deputati eletti in questo collegio plurinominale"
                : "Rappresentanti eletti")
                .font(.headline)
                .accessibilityIdentifier("district.section.plurinominaleCollegio")

            if district.chamber == .camera {
                Text("Eletti con il sistema proporzionale nelle liste di questo collegio plurinominale.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if deputies.isEmpty {
                Text("Nessun rappresentante collegato in questa versione del prototipo.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(deputies) { deputy in
                    Button {
                        path.append(.representativeProfile(representativeId: deputy.id))
                    } label: {
                        RepresentativeRow(representative: deputy)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("representative.row.\(deputy.id)")
                }
            }
        }
    }
}

/// Shared avatar/name/party row used by `HomeView`'s featured list,
/// `RepresentativeListView`, and here.
struct RepresentativeRow: View {
    let representative: Representative
    @Environment(\.services) private var services

    var body: some View {
        HStack(spacing: 12) {
            InitialsAvatar(
                name: representative.name,
                color: services.partyStyleService.color(for: representative.party),
                diameter: 52
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(representative.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(services.partyStyleService.shortName(for: representative.party))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
        .accessibilityHint("Apre il profilo del rappresentante")
    }
}

/// A local-first stand-in for a representative's photo: a colored circle
/// with their initials, derived purely from their name — no image asset, no
/// remote fetch (see CLAUDE.md's local-first constraint). Always marked
/// `.accessibilityHidden(true)` by its callers: it's decorative once the
/// surrounding row/header already states the person's full name as real
/// text, so its `minimumScaleFactor` (needed to fit 2 letters in a fixed
/// circle at large Dynamic Type sizes) never causes any information loss —
/// VoiceOver never reads from it in the first place.
struct InitialsAvatar: View {
    let name: String
    let color: Color
    var diameter: CGFloat = 52

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: diameter, height: diameter)
            .overlay {
                Text(Initials.from(name))
                    .font(.system(size: diameter * 0.38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
            }
    }
}

#Preview {
    NavigationStack {
        DistrictDetailView(districtId: "IT-RM-C01", path: .constant([]))
    }
}
