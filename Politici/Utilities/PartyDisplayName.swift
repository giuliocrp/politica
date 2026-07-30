//
//  PartyDisplayName.swift
//  Politici
//

import Foundation

/// Derives the **full name** of a parliamentary group for display, from the
/// group string the shipping data carries verbatim.
///
/// The Camera source's group `dc:title` is **malformed at source**: it is cut
/// off at an opening parenthesis, e.g. `"FRATELLI D'ITALIA (FDI) (18.10.2022"`
/// — a sigla in brackets, then an unterminated date. Both
/// `representatives.json`'s `parliamentaryGroup` and
/// `memberships_camera.json`'s `groupName` preserve that string **exactly**,
/// because reconstructing the missing suffix would be fabrication
/// (docs/v4/28-membership-history.md §5.4). Repairing the *data* is therefore
/// off the table; what a display can honestly do is show the part of the
/// source string that precedes the defect and drop the rest.
///
/// So this is a **pure display-side truncation, never a rewrite**. It removes
/// a suffix the source itself supplied and returns the source's own remaining
/// characters — casing, punctuation and spelling untouched (which is why
/// Camera names render in the source's upper case). It never substitutes a
/// name from anywhere else, and it never invents one.
///
/// The rule fires only on that exact malformed shape — a trailing
/// `" (<sigla>)"` followed by `" (<dd.mm.yyyy"` with **no** closing bracket at
/// the very end of the string. Anything else is returned unchanged, which is
/// what keeps the Senato values safe: they are already clean full names, and
/// one of them legitimately *ends* in a parenthetical
/// (`"Per le Autonomie (SVP-PATT, Campobase)"`) that a naive "strip the last
/// bracket" rule would mangle. The sigla search runs backwards for the same
/// reason: `"NOI MODERATI (NOI CON L'ITALIA, …)-MAIE-CENTRO POPOLARE
/// (NM(N-C-U-I)M-CP) (27.10.2022"` contains brackets in both the name and the
/// sigla, and a leftmost match would cut it at the first one.
///
/// **Coupled to the defect, on purpose — and guarded.** Because the rule keys
/// on the *unterminated* date, it stops firing the moment the source is
/// repaired: a properly closed `"… (FDI) (18.10.2022)"` no longer matches, is
/// returned whole, and the date silently reappears on every Camera profile.
/// Widening the rule to strip closed parentheticals too is **not** the fix —
/// that is what would mangle `"Per le Autonomie (SVP-PATT, Campobase)"`. The
/// fix, when it happens, is to re-derive the rule against whatever the source
/// then actually emits. Until then the tripwire is
/// `PartyDisplayNameTests.testNoShippingPartyNameEndsInADateLikeFragment`,
/// which rejects a date-like tail whether or not it is closed, so a refetch
/// that repairs the source fails the suite loudly instead of regressing the
/// screen quietly. The neighbouring `testCameraNamesLose…` fails on the same
/// event from the other direction: every Camera name must get *shorter*.
///
/// Verified against all 19 distinct group strings in the shipping data (10
/// Camera, 9 Senato) plus the sample fixture — see `PartyDisplayNameTests`.
nonisolated enum PartyDisplayName {
    /// `"<name> (<sigla>) (<dd.mm.yyyy"` → `"<name>"`. Every other string,
    /// including one that would reduce to nothing, is returned unchanged.
    static func full(from groupName: String) -> String {
        guard let dateBracket = groupName.range(of: " (", options: .backwards),
              isTruncatedDate(groupName[dateBracket.upperBound...]) else { return groupName }

        let withoutDate = groupName[..<dateBracket.lowerBound]
        guard withoutDate.hasSuffix(")"),
              let siglaBracket = withoutDate.range(of: " (", options: .backwards) else { return groupName }

        let name = withoutDate[..<siglaBracket.lowerBound]
        // A source string that carried nothing but the defective suffix has no
        // honest full name to show: keep it whole rather than render a blank.
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return groupName }
        return String(name)
    }

    /// `true` for exactly `"dd.mm.yyyy"` and nothing else — in particular, not
    /// for a *closed* `"dd.mm.yyyy)"`, which would be a well-formed source
    /// string this must leave alone.
    private static func isTruncatedDate(_ tail: Substring) -> Bool {
        tail.range(of: #"^\d{2}\.\d{2}\.\d{4}$"#, options: .regularExpression) != nil
    }
}
