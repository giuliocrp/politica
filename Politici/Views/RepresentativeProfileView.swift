//
//  RepresentativeProfileView.swift
//  Politici
//

import SwiftUI

struct RepresentativeProfileView: View {
    let representativeId: String
    @Binding var path: [AppRoute]
    @Environment(\.services) private var services

    private var representative: Representative? {
        services.representativeService.representative(withId: representativeId)
    }

    private var recentVotes: [Vote] {
        Array(services.voteService.votes(for: representativeId).prefix(3))
    }

    var body: some View {
        ScrollView {
            if let representative {
                VStack(alignment: .leading, spacing: 24) {
                    header(for: representative)
                    committeesSection(for: representative)
                    recentVotesSection
                }
                .padding()
            } else {
                ContentUnavailableView(
                    "Rappresentante non trovato",
                    systemImage: "person.crop.circle.badge.questionmark"
                )
                .padding(.top, 40)
            }
        }
        .navigationTitle(representative?.name ?? "Profilo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if representative != nil {
                ToolbarItem(placement: .navigationBarTrailing) {
                    favoriteButton
                }
            }
        }
        .task { await services.voteService.loadIfNeeded() }
    }

    private var favoriteButton: some View {
        let isFavorite = services.favoritesStore.isFavorite(representativeId)
        return Button {
            services.favoritesStore.toggle(representativeId)
        } label: {
            Image(systemName: isFavorite ? "star.fill" : "star")
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(isFavorite ? "Rimuovi dai preferiti" : "Aggiungi ai preferiti")
        .accessibilityAddTraits(isFavorite ? .isSelected : [])
        .accessibilityIdentifier("profile.favorite")
    }

    @ViewBuilder
    private func header(for representative: Representative) -> some View {
        VStack(spacing: 12) {
            InitialsAvatar(
                name: representative.name,
                color: services.partyStyleService.color(for: representative.party),
                diameter: 96
            )
            .accessibilityHidden(true)

            Text(representative.name)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            // One party field, not two: the sigla line that used to sit above
            // this chip repeated what the chip already says. The chip shows the
            // group's full name with the Camera source's defective
            // `" (SIGLA) (dd.mm.yyyy"` suffix dropped display-side — see
            // `PartyDisplayName`, which never rewrites what the source says.
            Text(PartyDisplayName.full(from: representative.parliamentaryGroup))
                .font(.caption)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(services.partyStyleService.color(for: representative.party).opacity(0.15), in: Capsule())
                .foregroundStyle(services.partyStyleService.color(for: representative.party))

            if let mandateBadgeLabel = representative.mandate?.profileBadgeLabel {
                mandateBadge(mandateBadgeLabel)
            }

            if let attendanceRate = representative.attendanceRate {
                attendanceBadge(rate: attendanceRate)
            }

            Text(representative.chamber == .camera ? "Camera dei Deputati" : "Senato della Repubblica")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let circoscrizione = representative.circoscrizione {
                Text("Circoscrizione: \(circoscrizione)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // Senato mirror of the circoscrizione line (Phase 26): the regione
            // the senator was elected in ("Estero" for overseas senators;
            // absent for the a-vita).
            if let regione = representative.regione {
                Text("Regione: \(regione)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profile.header")
    }

    private func mandateBadge(_ text: String) -> some View {
        Label(text, systemImage: "star.circle.fill")
            .font(.caption.weight(.semibold))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.purple.opacity(0.15), in: Capsule())
            .foregroundStyle(.purple)
    }

    private func attendanceBadge(rate: Double) -> some View {
        let percentage = Int((rate * 100).rounded())
        let color: Color = rate >= 0.85 ? .green : (rate >= 0.70 ? .orange : .red)
        return Label("\(percentage)% presenze", systemImage: "checkmark.seal.fill")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private func committeesSection(for representative: Representative) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Commissioni")
                .font(.headline)
            if representative.committees.isEmpty {
                Text("Nessuna commissione assegnata.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(representative.committees, id: \.self) { committee in
                    Label(committee, systemImage: "person.3.fill")
                        .font(.subheadline)
                }
            }
        }
    }

    // The Phase 29 group-alignment section used to render here, between the
    // committees and the recent votes. It was removed from this screen in the
    // post-v4 tidy — the metric is still computed and still fully tested; see
    // `GroupAlignment`'s own note for why it stays.

    private var recentVotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Votazioni recenti")
                .font(.headline)

            switch services.voteService.state {
            case .idle, .loading:
                ProgressView()
                    .accessibilityIdentifier("profile.votes.loading")
            case .failed:
                Text("Impossibile caricare le votazioni in questa versione del prototipo.")
                    .foregroundStyle(.secondary)
            case .loaded:
                if recentVotes.isEmpty {
                    Text("Nessuna votazione disponibile in questa versione del prototipo.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recentVotes) { vote in
                        VoteRow(vote: vote)
                    }
                }
            }

            Button {
                path.append(.voteHistory(representativeId: representativeId))
            } label: {
                Text("Cronologia completa")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityHint("Apre l'elenco completo delle votazioni")
            .accessibilityIdentifier("profile.cta.voteHistory")
        }
    }
}

#Preview {
    NavigationStack {
        RepresentativeProfileView(representativeId: "REP001", path: .constant([]))
    }
}
