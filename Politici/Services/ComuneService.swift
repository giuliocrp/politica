//
//  ComuneService.swift
//  Politici
//

import Foundation

/// The comuni-table lookup seam, so `GeocodingService` (and tests) can depend
/// on the capability without loading the bundled `comuni.json`.
protocol ComuneLookup {
    /// Every comune whose name matches `query` (see the concrete doc below).
    /// Homonyms return more than one candidate, to be disambiguated by
    /// province; an unknown name returns `[]`.
    func comuni(matching query: String) -> [Comune]
}

/// Loads `comuni.json` once and answers exact comune-name lookups for the
/// offline geocoding tier (v4 Phase 30 — docs/v4/30-comuni-geocoding.md).
///
/// The table is ~568 KiB / 7,904 comuni, so it loads eagerly in `init` on the
/// main actor like `RepresentativeService` / `MembershipService`, not
/// lazily/off-main like `VoteService`.
final class ComuneService: ComuneLookup {
    static let shared = ComuneService()

    private(set) var comuni: [Comune] = []
    private(set) var loadError: Error?

    /// Comuni bucketed by their folded name (`NameFolding.fold`). A bucket has
    /// more than one entry only for the six homonym names.
    private var byFoldedName: [String: [Comune]] = [:]

    init(resource: String = "comuni", bundle: Bundle = .main) {
        do {
            let file = try LocalJSONLoader.decode(ComuniFile.self, fromResource: resource, bundle: bundle)
            comuni = file.comuni
            byFoldedName = Dictionary(grouping: file.comuni) { NameFolding.fold($0.name) }
        } catch {
            loadError = error
            comuni = []
            byFoldedName = [:]
        }
    }

    /// All comuni whose folded name **equals** the folded `query` — an exact
    /// (accent- and case-insensitive) name match, not a substring one: with
    /// 7,904 names a substring match would falsely fire ("Roma" is a substring
    /// of "Romano di Lombardia"). A bilingual `"X/Y"` query is split on `/`
    /// and each side is tried, so `"Bolzano/Bozen"` resolves via its Italian
    /// side `"Bolzano"` (the table carries Italian-only names — a German-only
    /// query legitimately returns `[]`). Homonyms yield every candidate,
    /// sorted by `(name, province)` for a deterministic order; the caller
    /// disambiguates by province.
    func comuni(matching query: String) -> [Comune] {
        let sides = query.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        let keys = (sides.isEmpty ? [query] : sides)
            .map(NameFolding.fold)
            .filter { !$0.isEmpty }

        var result: [Comune] = []
        var seen = Set<String>()
        for key in keys {
            for comune in byFoldedName[key] ?? [] where seen.insert(comune.id).inserted {
                result.append(comune)
            }
        }
        return result.sorted { ($0.name, $0.province) < ($1.name, $1.province) }
    }
}
