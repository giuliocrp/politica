//
//  MembershipService.swift
//  Politici
//

import Foundation

/// Loads `memberships_camera.json` once and answers the
/// group-at-a-given-date lookup (Phase 28 — docs/v4/28-membership-history.md).
///
/// This is **infrastructure only** — no view consumes it yet. It exists so a
/// future within-sample alignment metric (methodology gate line 6,
/// `docs/v3/votes-methodology.md`) can attribute each vote to the group the
/// deputy held **on that vote's date**, never their current group. The file
/// is small (~106 KiB), so it loads eagerly in `init` on the main actor like
/// `RepresentativeService`, not lazily/off-main like `VoteService`.
///
/// Editorial rule (pinned): `membershipAt` returns **nil** for any date not
/// covered by an interval (e.g. before a deputy's first membership). A caller
/// must render nil as *unknown* — **never** the last-known or current group.
/// Inferring a party affiliation for a named politician is fabrication; there
/// is no fallback path.
final class MembershipService {
    static let shared = MembershipService()

    private(set) var memberships: [GroupMembership] = []
    private(set) var loadError: Error?
    private var byRepresentative: [String: [GroupMembership]] = [:]

    init(resource: String = "memberships_camera", bundle: Bundle = .main) {
        do {
            let file = try LocalJSONLoader.decode(MembershipsFile.self, fromResource: resource, bundle: bundle)
            memberships = file.memberships
            byRepresentative = Dictionary(grouping: file.memberships, by: \.representativeId)
        } catch {
            loadError = error
            memberships = []
            byRepresentative = [:]
        }
    }

    /// The group the deputy belonged to on `date`, or `nil` if no interval
    /// covers it. Half-open `[start, end)`.
    func membershipAt(representativeId: String, date: Date) -> GroupMembership? {
        Self.membership(at: date, in: byRepresentative[representativeId] ?? [])
    }

    /// Pure lookup over one deputy's intervals, exposed statically so tests can
    /// exercise it on hand-built fixtures independent of any bundled resource.
    /// Half-open containment: `start <= date < end` (or `end == nil`). On the
    /// validated shipping data the intervals are non-overlapping, so at most
    /// one matches; if two ever did, the one with the latest `start` (the more
    /// recent) wins — a group-switch date always resolves to the joined group.
    static func membership(at date: Date, in intervals: [GroupMembership]) -> GroupMembership? {
        intervals
            .filter { $0.start <= date && ($0.end.map { date < $0 } ?? true) }
            .max { ($0.start, $0.id) < ($1.start, $1.id) }
    }
}
