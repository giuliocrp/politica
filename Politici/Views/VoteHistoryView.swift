//
//  VoteHistoryView.swift
//  Politici
//

import SwiftUI

struct VoteHistoryView: View {
    let representativeId: String
    @Environment(\.services) private var services
    @State private var selectedChoice: VoteChoice?
    @State private var searchText = ""

    private var representative: Representative? {
        services.representativeService.representative(withId: representativeId)
    }

    private var votes: [Vote] {
        services.voteService.votes(for: representativeId)
    }

    private var filteredVotes: [Vote] {
        Self.filtered(votes, choice: selectedChoice, searchText: searchText)
    }

    var body: some View {
        Group {
            switch services.voteService.state {
            case .idle, .loading:
                ProgressView("Caricamento votazioni…")
                    .accessibilityIdentifier("voteHistory.loading")
            case .failed:
                ContentUnavailableView(
                    "Votazioni non disponibili",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Impossibile caricare le votazioni in questa versione del prototipo.")
                )
            case .loaded:
                if votes.isEmpty {
                    ContentUnavailableView(
                        "Nessuna votazione",
                        systemImage: "checkmark.circle.trianglebadge.exclamationmark",
                        description: Text("Nessuna votazione disponibile in questa versione del prototipo.")
                    )
                } else {
                    List {
                        Section {
                            if filteredVotes.isEmpty {
                                // Honest empty state for an over-narrow filter —
                                // distinct from the no-data case above.
                                Text("Nessuna votazione corrisponde ai filtri selezionati.")
                                    .foregroundStyle(.secondary)
                                    .accessibilityIdentifier("voteHistory.emptyFilter")
                                    .listRowSeparator(.hidden)
                            } else {
                                ForEach(filteredVotes) { vote in
                                    VoteRow(vote: vote)
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                }
                            }
                        } header: {
                            choiceFilterChips
                                .textCase(nil)
                        }
                    }
                    .listStyle(.plain)
                    .searchable(text: $searchText, prompt: "Cerca nel titolo")
                }
            }
        }
        .navigationTitle(representative.map { "Voti di \($0.name)" } ?? "Cronologia Voti")
        .navigationBarTitleDisplayMode(.inline)
        .task { await services.voteService.loadIfNeeded() }
    }

    /// Chip row: "Tutte" plus the four real outcomes. A `.sconosciuto`
    /// position (none in shipping data) stays reachable via "Tutte".
    private var choiceFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "Tutte", choice: nil)
                ForEach([VoteChoice.favorevole, .contrario, .astenuto, .assente], id: \.self) { choice in
                    filterChip(title: choice.rawValue, choice: choice)
                }
            }
        }
    }

    private func filterChip(title: String, choice: VoteChoice?) -> some View {
        let isSelected = selectedChoice == choice
        return Button {
            selectedChoice = choice
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.12),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(choice == nil ? "Tutte le votazioni" : "Filtra per \(title)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("voteHistory.chip.\(choice?.rawValue ?? "tutte")")
    }

    /// Pure filter (unit-tested as such): outcome chip and title search
    /// compose with AND; the search is case- and diacritic-insensitive via
    /// `localizedStandardContains`, and blank search text matches all.
    static func filtered(_ votes: [Vote], choice: VoteChoice?, searchText: String) -> [Vote] {
        votes.filter { vote in
            if let choice, vote.vote != choice { return false }
            let query = searchText.trimmingCharacters(in: .whitespaces)
            return query.isEmpty || vote.title.localizedStandardContains(query)
        }
    }
}

/// Shared vote summary card used both in the full history list and the
/// "recent votes" preview on `RepresentativeProfileView`.
struct VoteRow: View {
    let vote: Vote

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Grouped as one VoiceOver element — none of this static info
            // (title/date/badge/esito) is individually interactive. The
            // "Fonte" link below is deliberately kept OUTSIDE this group:
            // combining a container that has a nested Link/Button would
            // swallow that control from VoiceOver's swipe navigation, not
            // just merge its text into the group's label.
            VStack(alignment: .leading, spacing: 8) {
                // Real titles can run long (bill/motion names, not the short
                // placeholders used by the sample fixture) — wrap rather
                // than truncate, so the subject of the vote stays legible.
                Text(vote.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

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
                        .accessibilityHidden(true)
                    Text("Esito: \(vote.result.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("vote.row.\(vote.id)")

            if let sourceUrl = vote.sourceUrl, let url = URL(string: sourceUrl) {
                Link(destination: url) {
                    Label("Fonte", systemImage: "arrow.up.right.square")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel("Fonte ufficiale")
                .accessibilityHint("Apre la scheda della votazione sul sito della Camera dei Deputati")
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Vote outcome badge — never color-only: an SF Symbol plus the existing
/// Italian word (e.g. "checkmark" + "Favorevole"), with a distinct
/// accessibility label so VoiceOver states the vote clearly rather than
/// just reading the visible word.
struct VoteBadge: View {
    let choice: VoteChoice

    var body: some View {
        Label(choice.rawValue, systemImage: choice.symbolName)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
            .accessibilityLabel(choice.accessibilityLabel)
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
