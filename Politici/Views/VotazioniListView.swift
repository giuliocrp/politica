//
//  VotazioniListView.swift
//  Politici
//

import SwiftUI

/// The imported votazioni, one row per event (Phase 20 — see
/// docs/v3/20-vote-browsing.md). A single screen: rows have no detail
/// route, only the per-event official source link. The scope line states
/// plainly that this is a curated sample, with N read from the data —
/// never a hardcoded count.
struct VotazioniListView: View {
    @Environment(\.services) private var services

    private var events: [VoteEvent] {
        services.voteService.allEvents()
    }

    var body: some View {
        Group {
            if events.isEmpty {
                ContentUnavailableView(
                    "Nessuna votazione",
                    systemImage: "checkmark.circle.trianglebadge.exclamationmark",
                    description: Text("Nessuna votazione disponibile in questa versione del prototipo.")
                )
            } else {
                List {
                    Section {
                        ForEach(events) { event in
                            VoteEventRow(event: event)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                    } header: {
                        Text("Campione di \(events.count) votazioni importate — non l'archivio completo")
                            .font(.footnote)
                            .textCase(nil)
                            .accessibilityIdentifier("votazioni.scope")
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Votazioni")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One aggregated votazione: title, date, esito, per-choice tallies, and
/// the official source link (its own VoiceOver element, same pattern as
/// `VoteRow`'s).
struct VoteEventRow: View {
    let event: VoteEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(DateFormatting.longString(from: event.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Image(systemName: event.result == .approvato ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(event.result == .approvato ? .green : .red)
                        .accessibilityHidden(true)
                    Text("Esito: \(event.result.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                tallyRow
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("vote.event.\(event.id)")

            if let sourceUrl = event.sourceUrl, let url = URL(string: sourceUrl) {
                Link(destination: url) {
                    Label("Fonte", systemImage: "arrow.up.right.square")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel("Fonte ufficiale")
                .accessibilityHint("Apre la scheda della votazione sul sito della Camera dei Deputati")
                .accessibilityIdentifier("vote.event.source.\(event.id)")
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    /// The four pinned tallies; a `.sconosciuto` count appears only when
    /// nonzero (the importer maps vocabulary explicitly, so shipping data
    /// has none — but hiding a nonzero one would be dishonest).
    private var tallyRow: some View {
        HStack(spacing: 12) {
            tally(.favorevole, label: "Favorevoli")
            tally(.contrario, label: "Contrari")
            tally(.astenuto, label: "Astenuti")
            tally(.assente, label: "Assenti")
            if count(for: .sconosciuto) > 0 {
                tally(.sconosciuto, label: "Esito non disponibile")
            }
        }
    }

    private func count(for choice: VoteChoice) -> Int {
        event.counts[choice] ?? 0
    }

    private func tally(_ choice: VoteChoice, label: String) -> some View {
        Label("\(count(for: choice))", systemImage: choice.symbolName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityLabel("\(label): \(count(for: choice))")
    }
}

#Preview {
    NavigationStack {
        VotazioniListView()
    }
}
