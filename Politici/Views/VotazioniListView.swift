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
            switch services.voteService.state {
            case .idle, .loading:
                ProgressView("Caricamento votazioni…")
                    .accessibilityIdentifier("votazioni.loading")
            case .failed:
                ContentUnavailableView(
                    "Votazioni non disponibili",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Impossibile caricare le votazioni in questa versione del prototipo.")
                )
            case .loaded:
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
                            scopeHeader
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .navigationTitle("Votazioni")
        .navigationBarTitleDisplayMode(.inline)
        .task { await services.voteService.loadIfNeeded() }
    }

    /// States plainly what the sample IS a sample of (Phase 27): not "the N
    /// most recent" but a coverage-driven stratified pick across several
    /// sittings and months — deliberately part procedural (ordini del
    /// giorno), part final votes on atti. N is read from the data, never
    /// hardcoded.
    private var scopeHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Campione stratificato di \(events.count) votazioni importate — non l'archivio completo")
                .font(.footnote)
            Text("Selezione per copertura: sedute distribuite su più mesi, in parte voti procedurali (ordini del giorno), in parte votazioni finali su atti.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .textCase(nil)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("votazioni.scope")
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
                // `.secondary`, not `.tertiary` (Phase 32A a11y triage —
                // docs/v4/a11y-checklist.md). `.tertiary` is the system's
                // style for non-essential decoration; this is an interactive
                // link to the official record, and the whole-screen audit
                // flags it on both screens that carry it. Raising the
                // hierarchy strictly increases contrast against whatever the
                // real background turns out to be, so unlike the material-
                // backed findings it needs no on-device measurement to
                // justify. Same change in `VoteRow`.
                Link(destination: url) {
                    Label("Fonte", systemImage: "arrow.up.right.square")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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
