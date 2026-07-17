//
//  PartyStyleService.swift
//  Politici
//

import Foundation
import SwiftUI

/// Loads `Data/parties.json` once and answers party-styling lookups, keyed
/// by the exact `Representative.party` string. Falls back to a neutral gray
/// for any value not present in the data — this is expected to happen for
/// party values that genuinely aren't in `Data/parties.json` yet, not an
/// error condition, so it degrades gracefully rather than failing loudly
/// the way `DistrictService`/`RepresentativeService` do for missing files.
final class PartyStyleService {
    static let shared = PartyStyleService()

    private(set) var entries: [String: PartyStyleEntry] = [:]
    private(set) var loadError: Error?

    private static let fallbackColor = Color.gray

    init(resource: String = "parties", bundle: Bundle = .main) {
        do {
            let list = try LocalJSONLoader.decode([PartyStyleEntry].self, fromResource: resource, bundle: bundle)
            entries = Dictionary(uniqueKeysWithValues: list.map { ($0.value, $0) })
        } catch {
            loadError = error
            entries = [:]
        }
    }

    /// The party's accent color, or neutral gray if `party` isn't mapped or
    /// its `colorHex` fails to parse.
    func color(for party: String) -> Color {
        guard let entry = entries[party], let color = Color(hex: entry.colorHex) else {
            return Self.fallbackColor
        }
        return color
    }

    /// The party's short display name, or `party` itself if unmapped.
    func shortName(for party: String) -> String {
        entries[party]?.shortName ?? party
    }
}
