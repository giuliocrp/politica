//
//  ManifestService.swift
//  Politici
//

import Foundation

/// Loads `sources.json` once and exposes the data-provenance manifest.
/// `FontiEDatiView` renders its per-source cards straight from here, and
/// `HomeView` renders the one-line data-vintage disclosure derived below.
final class ManifestService {
    static let shared = ManifestService()

    private(set) var manifest: SourcesManifest?
    private(set) var loadError: Error?

    init(resource: String = "sources", bundle: Bundle = .main) {
        do {
            manifest = try LocalJSONLoader.decode(SourcesManifest.self, fromResource: resource, bundle: bundle)
        } catch {
            loadError = error
            manifest = nil
        }
    }

    // MARK: - Data vintage (Phase 31 — docs/v4/31-live-refresh-adr.md)

    /// The most recent `retrievedAt` across the manifest — an upper bound on
    /// the whole bundle's vintage: nothing in the app was retrieved after it.
    ///
    /// Deliberately the **max over every entry, with no id-keyed exclusion**
    /// (ADR §7.2): the max is the only value that makes the rendered sentence
    /// true, and an exclusion would suppress the one condition worth seeing
    /// rather than hiding it.
    ///
    /// The exclusion originally weighed was for the `prototipo-dati-dimostrativi`
    /// fixture row, which is now retired from the manifest altogether
    /// (`tools/make_manifest.py`'s `RETIRED_SOURCE_IDS`; ADR §7.4). Every
    /// remaining row is a real source, so the max and the min are now both
    /// dates that describe data the app actually ships.
    ///
    /// Entries whose `retrievedAt` does not parse are skipped rather than
    /// crashing or defaulting — an unparseable date is not evidence of any
    /// vintage. `nil` when the manifest failed to load or nothing parsed.
    static func latestRetrievedAt(in sources: [DataSource]) -> Date? {
        sources.compactMap { DateFormatting.parseISODate($0.retrievedAt) }.max()
    }

    var latestRetrievedAt: Date? {
        Self.latestRetrievedAt(in: manifest?.sources ?? [])
    }

    /// The pinned Italian disclosure line (Phase 31 §7).
    ///
    /// It states the **last retrieval**, not that every source is current to
    /// that date: minimal-scope refetches are the repo's preferred practice
    /// (Phases 27 and 28 each advanced one source alone), so the manifest
    /// normally carries a spread of dates and a "tutto aggiornato al X"
    /// claim would assert more than the data supports. The per-source
    /// breakdown is one tap away on "Informazioni e fonti".
    static func dataVintageText(for date: Date) -> String {
        "Ultimo aggiornamento dei dati: \(DateFormatting.longString(from: date))"
    }

    /// `nil` — so the line is simply absent, never a placeholder date — when
    /// the manifest failed to load or carries no parseable `retrievedAt`.
    var dataVintageText: String? {
        // Written out rather than `latestRetrievedAt.map(Self.dataVintageText(for:))`:
        // `Optional.map` takes a nonisolated closure, so handing it a reference
        // to this MainActor-isolated method warns under the project's
        // `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
        guard let date = latestRetrievedAt else { return nil }
        return Self.dataVintageText(for: date)
    }
}
