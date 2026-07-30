//
//  ComuneService.swift
//  Politici
//

import Foundation

/// The outcome of looking a comune **name** up in the bundled table — the
/// "one, many, or none" the Phase 30B name path has to be able to express
/// (docs/v4/30b-comuni-assignment.md).
///
/// `none` is a genuine absence: an unknown name resolves to nothing, never to
/// a nearest neighbour and never to a default — the same nil-not-fallback
/// discipline as Phase 28's absent membership and Phase 29's below-threshold
/// metric. `ambiguous` is the homonym case (`Castro` exists in Bergamo *and*
/// Lecce): the caller must ask which province before showing any collegio.
///
/// Note that `one` still says nothing about how many *collegi* the answer has:
/// a single comune can be assigned to several (Roma spans seven Camera
/// collegi). That multiplicity lives on `Comune.collegioIds(for:)`.
nonisolated enum ComuneNameMatch: Equatable {
    case none
    case one(Comune)
    case ambiguous([Comune])
}

/// The comuni-table lookup seam, so `GeocodingService` (and tests) can depend
/// on the capability without loading the bundled `comuni.json`.
protocol ComuneLookup {
    /// Every comune whose name matches `query` (see the concrete doc below).
    /// Homonyms return more than one candidate, to be disambiguated by
    /// province; an unknown name returns `[]`.
    func comuni(matching query: String) -> [Comune]
}

extension ComuneLookup {
    /// `comuni(matching:)` classified into the three cases a caller actually
    /// has to branch on. Derived rather than reimplemented, so every
    /// conforming type (including test fakes) gets the same classification.
    func match(name query: String) -> ComuneNameMatch {
        let candidates = comuni(matching: query)
        switch candidates.count {
        case 0: return .none
        case 1: return .one(candidates[0])
        default: return .ambiguous(candidates)
        }
    }
}

/// Loads `comuni.json` once and answers exact comune-name lookups (v4 Phase 30
/// — docs/v4/30-comuni-geocoding.md; v4 Phase 30B —
/// docs/v4/30b-comuni-assignment.md).
///
/// The table is ~876 KiB / 7,904 comuni, so it loads eagerly in `init` on the
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
            // A schemaVersion this build doesn't implement lands here too, by
            // design: the table stays empty and every lookup answers nothing,
            // so a version mismatch is a loud, total absence rather than a
            // quiet degradation into wrong-but-plausible answers.
            if case ComuniFileError.unsupportedSchemaVersion(let found, let expected) = error {
                print("ComuneService: comuni.json schemaVersion \(found), this build implements \(expected) — table not loaded")
            }
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
