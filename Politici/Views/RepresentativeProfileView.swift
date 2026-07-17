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
    }

    @ViewBuilder
    private func header(for representative: Representative) -> some View {
        VStack(spacing: 12) {
            Image(systemName: representative.photoName)
                .font(.system(size: 56))
                .foregroundStyle(.white)
                .frame(width: 96, height: 96)
                .background(PartyStyle.color(for: representative.party), in: Circle())

            Text(representative.name)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text(representative.party)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(representative.parliamentaryGroup)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(PartyStyle.color(for: representative.party).opacity(0.15), in: Capsule())
                .foregroundStyle(PartyStyle.color(for: representative.party))

            if let attendanceRate = representative.attendanceRate {
                attendanceBadge(rate: attendanceRate)
            }

            Text(representative.chamber == .camera ? "Camera dei Deputati" : "Senato della Repubblica")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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

    private var recentVotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Votazioni recenti")
                .font(.headline)

            if recentVotes.isEmpty {
                Text("Nessuna votazione registrata.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recentVotes) { vote in
                    VoteRow(vote: vote)
                }
            }

            Button {
                path.append(.voteHistory(representativeId: representativeId))
            } label: {
                Text("Cronologia completa")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
}

#Preview {
    NavigationStack {
        RepresentativeProfileView(representativeId: "REP001", path: .constant([]))
    }
}
