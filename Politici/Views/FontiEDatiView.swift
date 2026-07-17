//
//  FontiEDatiView.swift
//  Politici
//

import SwiftUI

/// The app's attribution/about screen — its legal anchor. Renders source
/// cards live from the sources manifest rather than hardcoding them, so this
/// screen stays accurate once real sources are added.
struct FontiEDatiView: View {
    @Environment(\.services) private var services

    private var sources: [DataSource] {
        services.manifestService.manifest?.sources ?? []
    }

    private var appDisplayName: String {
        (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String) ?? "Politica"
    }

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "—"
    }

    private var appBuild: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "—"
    }

    var body: some View {
        List {
            Section("Informazioni sull'app") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(appDisplayName)
                        .font(.title2.bold())
                    Text("Versione \(appVersion) (build \(appBuild))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Politica è un prototipo indipendente a scopo informativo e dimostrativo. Non è affiliata a, né approvata da, la Camera dei Deputati, il Senato della Repubblica o altre istituzioni.")
                        .font(.body)
                        .padding(.top, 4)
                }
                .padding(.vertical, 4)
            }

            Section("Fonti dei dati") {
                if sources.isEmpty {
                    Text("Nessuna fonte disponibile al momento.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sources) { source in
                        SourceCard(source: source)
                    }
                }
            }

            Section("Avvertenze") {
                VStack(alignment: .leading, spacing: 10) {
                    BulletRow(text: "I dati mostrati sono uno snapshot e potrebbero non essere aggiornati.")
                    BulletRow(text: "Le sezioni contrassegnate come \"Dati dimostrativi\" contengono dati fittizi a solo scopo di prototipo.")
                    BulletRow(text: "Questa app non utilizza loghi o emblemi istituzionali.")
                    // REMOVE-IN-BOUNDARIES-PHASE: see MapView.swift's legend caption.
                    BulletRow(text: "I confini dei collegi sulla mappa sono dimostrativi e non corrispondono ai collegi elettorali reali.")
                }
                .padding(.vertical, 4)
            }

            Section("Licenze") {
                Text("Per i dettagli sulla licenza di ciascuna fonte, consulta i link riportati sopra nella sezione \"Fonti dei dati\".")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Informazioni e fonti")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SourceCard: View {
    let source: DataSource

    private var formattedRetrievedAt: String {
        if let date = DateFormatting.parseISODate(source.retrievedAt) {
            return DateFormatting.longString(from: date)
        }
        return source.retrievedAt
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(source.name)
                .font(.headline)
            Text("Licenza: \(source.license)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Dati aggiornati al: \(formattedRetrievedAt)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !source.url.isEmpty, let url = URL(string: source.url) {
                Link(destination: url) {
                    Label("Apri la fonte", systemImage: "arrow.up.right.square")
                        .font(.subheadline)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct BulletRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.body)
            Text(text)
                .font(.body)
        }
    }
}

#Preview {
    NavigationStack {
        FontiEDatiView()
    }
}
