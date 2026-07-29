//
//  Membership.swift
//  Politici
//

import Foundation

/// One parliamentary-group membership interval of a Camera deputy
/// (Phase 28 — docs/v4/28-membership-history.md). Decoded from
/// `memberships_camera.json`. Intervals are **half-open `[start, end)`**:
/// `start` is inclusive, `end` is exclusive, and `end == nil` marks the
/// single current (open) interval. The half-open rule is evidenced, not
/// chosen — the source uses same-day handoff (a switcher's old `end` equals
/// the new `start`), so half-open is the only rule that resolves the switch
/// day to a single group (see the report for the p301459 / 2026-05-20 case).
///
/// `groupSigla` is the canonical, clean group identifier (`"FDI"`, `"MISTO"`,
/// …) — the value any UI should display. `groupName` is the source group's
/// `dc:title`, preserved **exactly**, including the documented
/// truncation-at-`"("` source quirk (e.g. `"MISTO (MISTO) (18.10.2022"` — an
/// unterminated parenthesis); it is kept for provenance/traceability and is
/// never "repaired" (reconstructing the missing suffix would be fabrication).
struct GroupMembership: Identifiable, Hashable {
    let id: String
    let representativeId: String
    let groupName: String
    let groupSigla: String
    let start: Date
    /// `nil` for the single current (open) interval; a date for a past one.
    let end: Date?
}

/// Decodes `start`/`end` as plain `yyyy-MM-dd` strings (reusing
/// `Vote.dateFormatter`, the project's shared Europe/Rome ISO parser) so the
/// model stays self-contained regardless of the `JSONDecoder` configuration.
extension GroupMembership: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, representativeId, groupName, groupSigla, start, end
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        representativeId = try container.decode(String.self, forKey: .representativeId)
        groupName = try container.decode(String.self, forKey: .groupName)
        groupSigla = try container.decode(String.self, forKey: .groupSigla)

        let startString = try container.decode(String.self, forKey: .start)
        guard let startDate = Vote.dateFormatter.date(from: startString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .start, in: container,
                debugDescription: "Formato data non valido: \(startString)"
            )
        }
        start = startDate

        if let endString = try container.decodeIfPresent(String.self, forKey: .end) {
            guard let endDate = Vote.dateFormatter.date(from: endString) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .end, in: container,
                    debugDescription: "Formato data non valido: \(endString)"
                )
            }
            end = endDate
        } else {
            end = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(representativeId, forKey: .representativeId)
        try container.encode(groupName, forKey: .groupName)
        try container.encode(groupSigla, forKey: .groupSigla)
        try container.encode(Vote.dateFormatter.string(from: start), forKey: .start)
        try container.encodeIfPresent(end.map(Vote.dateFormatter.string(from:)), forKey: .end)
    }
}

/// `memberships_camera.json`'s on-disk shape:
/// `{"schemaVersion":1,"memberships":[...]}`.
struct MembershipsFile: Codable {
    let schemaVersion: Int
    let memberships: [GroupMembership]
}
