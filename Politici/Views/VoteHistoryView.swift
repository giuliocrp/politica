//
//  VoteHistoryView.swift
//  Politici
//

import SwiftUI

struct VoteHistoryView: View {
    let representativeId: String
    @Environment(\.services) private var services

    private var representative: Representative? {
        services.representativeService.representative(withId: representativeId)
    }

    private var votes: [Vote] {
        services.voteService.votes(for: representativeId)
    }

    var body: some View {
        Group {
            if votes.isEmpty {
                ContentUnavailableView(
                    "Nessuna votazione",
                    systemImage: "checkmark.circle.trianglebadge.exclamationmark",
                    description: Text("Non ci sono votazioni registrate per questo rappresentante.")
                )
            } else {
                List(votes) { vote in
                    VoteRow(vote: vote)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(representative.map { "Voti di \($0.name)" } ?? "Cronologia Voti")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Shared vote summary card used both in the full history list and the
/// "recent votes" preview on `RepresentativeProfileView`.
struct VoteRow: View {
    let vote: Vote

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(vote.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            HStack {
                Text(DateFormatting.longString(from: vote.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                VoteBadge(choice: vote.vote)
            }

            HStack(spacing: 6) {
                Image(systemName: vote.result == .approvato ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(vote.result == .approvato ? .green : .red)
                Text("Esito: \(vote.result.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Color-coded outcome badge: Favorevole (green), Contrario (red), Astenuto (orange), Assente (gray).
struct VoteBadge: View {
    let choice: VoteChoice

    var body: some View {
        Text(choice.rawValue)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch choice {
        case .favorevole: return .green
        case .contrario: return .red
        case .astenuto: return .orange
        case .assente: return .gray
        case .sconosciuto: return .gray
        }
    }
}

#Preview {
    NavigationStack {
        VoteHistoryView(representativeId: "REP001")
    }
}
