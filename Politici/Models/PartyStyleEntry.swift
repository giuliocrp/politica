//
//  PartyStyleEntry.swift
//  Politici
//

import Foundation

/// One entry in `Data/parties.json`: a visual style for a single exact
/// `Representative.party` (or `parliamentaryGroup`) string value, as it
/// literally appears in the shipping data — see
/// docs/v2/02-post-import-audit.md for why same-party-different-spelling
/// pairs across chambers (e.g. "FDI" vs. "Fratelli d'Italia") are listed as
/// separate entries rather than merged.
struct PartyStyleEntry: Codable, Hashable {
    let value: String
    let shortName: String
    /// `"#RRGGBB"`, chosen for >= 4.5:1 contrast against white text.
    let colorHex: String
}
