//
//  GroupAlignment.swift
//  Politici
//

import Foundation

/// Pure, stateless computation of a Camera deputy's **group alignment** over
/// the shipped votes sample (Phase 29 — docs/v4/29-alignment-metric.md).
///
/// This is the first vote-derived metric this app ships, and it ships only
/// because every line of the `docs/v3/votes-methodology.md` gate passes
/// (re-measured 6/6 in the Phase 29 commit). Every standing rule in that
/// document binds it:
///
/// - **Absences are excluded from the denominator.** The Camera source's
///   `"Non ha votato"` conflates *absent / in missione / present-but-not-voting*
///   into the single `.assente` value (docs/v2/04-votes-import.md); it is never
///   treated as agreement or disagreement, only excluded. In this sample there
///   is no separate "in missione" value — it is folded into `.assente` at
///   source and drops out with every other absence.
/// - **`astenuto` is its own expressed category** (gate line 5): it counts in
///   the denominator, and a deputy is "aligned" on a vote iff the group's
///   majority expressed position is *also* astenuto.
/// - **Group membership is taken at the vote's date** (Phase 28), so a
///   group-switcher is scored against the group they actually belonged to on
///   each vote — never their current group.
/// - **Secret ballots** are excluded at fetch scope, so they never reach here.
///
/// Design decisions **user-approved 2026-07-23** (Q7 + the presentation), with
/// the reasoning recorded in the phase report:
/// - group-majority **tie** (two expressed positions sharing the top count) →
///   that vote is **excluded** from that member's denominator (no group
///   position to align to);
/// - **minimum denominator 10** — below it the metric does **not** render; the
///   deputy shows an honest absence (no line), never `0%`, a midpoint, or the
///   group's value;
/// - the value is presented as an integer percentage **with its denominator
///   shown alongside** — on this sample ~93 % of eligible deputies sit at
///   exactly 100 %, so the base is what keeps the precision honest.
///
/// It is deliberately **never** shown on a list, never ranked, and never
/// colored as a judgment: ranking would sort deputies by one or two votes'
/// difference out of a coverage-driven sample and turn a sampling artefact into
/// an apparent finding about a named person.
///
/// `GroupAlignment` is a caseless namespace — no stored state — so it is a pure
/// function of its `(events, positions, memberships)` inputs and is exercised
/// directly on hand-built fixtures in `GroupAlignmentTests`.
enum GroupAlignment {
    /// The **only** permitted name for this metric (methodology gate). Pinned;
    /// this constant is the single occurrence of the label string in the app
    /// target — the UI references it rather than repeating the literal. The
    /// label itself states the sample-bound scope.
    static let metricLabel = "Allineamento nel campione di votazioni importate"

    /// Prominent honesty caption shown beneath the value. States what the
    /// number is, that absences are excluded, that the sample is a
    /// coverage-driven stratified pick (part procedural) describing behaviour
    /// *on this sample* and not the whole of Parliament, and that small groups
    /// (Gruppo Misto included) align almost automatically.
    static let sampleCaption = "Quota dei voti espressi (favorevole, contrario o astenuto) che coincidono con la posizione di maggioranza del gruppo di appartenenza alla data di ciascun voto; le assenze sono escluse. Il campione di votazioni importate è scelto per copertura ed è in parte procedurale: la percentuale descrive il comportamento su questo campione, non l'attività complessiva in Parlamento. Nei gruppi molto piccoli, incluso il Gruppo Misto, l'allineamento è quasi automatico."

    /// Below this many expressed, group-defined, non-tie votes the metric does
    /// not render (Q7, user-approved 2026-07-23). See the phase report for the
    /// per-deputy denominator distribution that grounds the number.
    static let minimumDenominator = 10

    /// The expressed positions — the only ones that enter the denominator.
    /// `.assente` (and the never-shipped `.sconosciuto`) are excluded.
    static let expressedChoices: Set<VoteChoice> = [.favorevole, .contrario, .astenuto]

    /// One deputy's alignment over the sample. `matched / denominator`, with the
    /// denominator the honest base. Value types + `Equatable` so a test can
    /// compute the whole cohort twice and prove byte-identical determinism.
    struct Score: Equatable {
        /// Numerator: expressed positions matching the group's majority.
        let matched: Int
        /// Denominator *n*: expressed positions with a known group-at-date and a
        /// **defined** (non-tie) group majority. Absences, unknown-group votes,
        /// and group-tie votes are all excluded.
        let denominator: Int

        /// Whether *n* clears the minimum to render.
        var meetsThreshold: Bool { denominator >= GroupAlignment.minimumDenominator }

        /// Integer percentage, or `nil` when there is no basis (`denominator`
        /// 0). Rounded to nearest. Shown only alongside `denominator`.
        var percentage: Int? {
            guard denominator > 0 else { return nil }
            return Int((Double(matched) / Double(denominator) * 100).rounded())
        }
    }

    /// The value line, or `nil` when the deputy is below threshold (the caller
    /// then renders nothing — an honest absence). e.g. `"96% — su 27 voti espressi"`.
    static func valueText(for score: Score) -> String? {
        guard score.meetsThreshold, let percentage = score.percentage else { return nil }
        return "\(percentage)% — su \(score.denominator) voti espressi"
    }

    /// VoiceOver label — spells the value out as a sentence rather than a bare
    /// percentage. `nil` below threshold.
    static func accessibilityText(for score: Score) -> String? {
        guard score.meetsThreshold, let percentage = score.percentage else { return nil }
        return "\(metricLabel): \(percentage) percento, su \(score.denominator) voti espressi."
    }

    /// The group's majority expressed position for one cohort of positions, or
    /// `nil` on a **tie** (two expressed positions sharing the top count) — a
    /// tie means there is no single group position to align to, so the vote is
    /// dropped from members' denominators. Non-expressed positions are ignored.
    static func majorityChoice(_ choices: [VoteChoice]) -> VoteChoice? {
        var counts: [VoteChoice: Int] = [:]
        for choice in choices where expressedChoices.contains(choice) {
            counts[choice, default: 0] += 1
        }
        guard let top = counts.values.max() else { return nil }
        let leaders = counts.filter { $0.value == top }
        return leaders.count == 1 ? leaders.first?.key : nil
    }

    /// Pure alignment computation. Scans `positions` once to build, per
    /// `(event, group-at-date)`, the group's expressed-position cohort and its
    /// majority, then scores the target deputy's own expressed positions
    /// against the majority of the group they held **on each vote's date**.
    ///
    /// Order-independent by construction (it counts positions), so the result
    /// is deterministic regardless of input or dictionary iteration order — a
    /// deputy with no expressed, group-defined, non-tie vote returns
    /// `Score(matched: 0, denominator: 0)` (senators, who have no positions,
    /// among them), which is below threshold and renders nothing.
    static func score(
        representativeId: String,
        events: [VoteEventRecord],
        positions: [VotePositionRecord],
        memberships: [GroupMembership]
    ) -> Score {
        let dateByEvent = Dictionary(events.map { ($0.id, $0.date) }, uniquingKeysWith: { first, _ in first })
        let membershipsByRep = Dictionary(grouping: memberships, by: \.representativeId)

        // The group sigla the deputy held on the given event's date, half-open
        // per Phase 28 (reusing the one canonical containment rule), or `nil`.
        func groupSigla(_ representative: String, onEvent eventId: String) -> String? {
            guard let date = dateByEvent[eventId] else { return nil }
            return MembershipService.membership(at: date, in: membershipsByRep[representative] ?? [])?.groupSigla
        }

        // Per (event, group-at-date): the expressed positions of that cohort.
        var cohorts: [String: [String: [VoteChoice]]] = [:]  // eventId -> groupSigla -> [choice]
        for position in positions where expressedChoices.contains(position.vote) {
            guard let group = groupSigla(position.representativeId, onEvent: position.voteEventId) else { continue }
            cohorts[position.voteEventId, default: [:]][group, default: []].append(position.vote)
        }

        // Per (event, group): the majority (nil on a tie → the vote drops out).
        var majorityByEventGroup: [String: [String: VoteChoice]] = [:]
        for (eventId, groups) in cohorts {
            for (group, choices) in groups {
                if let majority = majorityChoice(choices) {
                    majorityByEventGroup[eventId, default: [:]][group] = majority
                }
            }
        }

        var matched = 0
        var denominator = 0
        for position in positions
        where position.representativeId == representativeId && expressedChoices.contains(position.vote) {
            guard let group = groupSigla(position.representativeId, onEvent: position.voteEventId),
                  let majority = majorityByEventGroup[position.voteEventId]?[group] else { continue }
            denominator += 1
            if position.vote == majority { matched += 1 }
        }
        return Score(matched: matched, denominator: denominator)
    }
}
