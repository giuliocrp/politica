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
nonisolated enum GroupAlignment {
    /// The **only** permitted name for this metric (methodology gate). Pinned;
    /// this constant is the single occurrence of the label string in the app
    /// target — the UI references it rather than repeating the literal. The
    /// label itself states the sample-bound scope.
    static let metricLabel = "Allineamento nel campione di votazioni importate"

    /// Prominent honesty caption shown beneath the value. States what the
    /// number is, that absences are excluded, that the sample is a
    /// coverage-driven stratified pick (part procedural) describing behaviour
    /// *on this sample* and not the whole of Parliament, that small differences
    /// rest on few votes and must not be over-read (so it reads as strongly for
    /// a deputy at 85 % — where the sampling noise concentrates — as at 100 %),
    /// and that small groups (Gruppo Misto included) align almost automatically.
    static let sampleCaption = "Quota dei voti espressi (favorevole, contrario o astenuto) che coincidono con la posizione di maggioranza del gruppo di appartenenza alla data di ciascun voto; le assenze sono escluse. Il campione di votazioni importate è scelto per copertura ed è in parte procedurale, quindi la percentuale descrive il comportamento su questo campione, non l'attività complessiva in Parlamento. Le differenze tra deputati dipendono da pochi voti e non vanno sovrainterpretate: un valore più basso riflette il campione limitato, non necessariamente una tendenza generale. Nei gruppi molto piccoli, incluso il Gruppo Misto, l'allineamento è quasi automatico."

    /// Below this many expressed, group-defined, non-tie votes the metric does
    /// not render (Q7, user-approved 2026-07-23). See the phase report for the
    /// per-deputy denominator distribution that grounds the number.
    static let minimumDenominator = 10

    /// The expressed positions — the only ones that enter the denominator.
    /// `.assente` (and the never-shipped `.sconosciuto`) are excluded.
    static let expressedChoices: Set<VoteChoice> = [.favorevole, .contrario, .astenuto]

    /// The raw arithmetic tally — `matched` of `denominator`. This is the
    /// **internal** computation and the testing seam; it is deliberately *not*
    /// the type the UI holds, because a below-threshold or `0/0` tally must
    /// never be formatted as "0%". The presentable result is `Alignment`, via
    /// `alignment(...)`. Value type + `Equatable` so a test can compute the
    /// whole cohort twice and prove byte-identical determinism.
    struct Tally: Equatable {
        /// Numerator: expressed positions matching the group's majority.
        let matched: Int
        /// Denominator *n*: expressed positions with a known group-at-date and a
        /// **defined** (non-tie) group majority. Absences, unknown-group votes,
        /// and group-tie votes are all excluded.
        let denominator: Int
    }

    /// The **presentable** result — the only type a UI holds. A deputy below
    /// the minimum denominator, or with no basis at all, is `.insufficientData`,
    /// which carries **no number**. That makes the "0 % of 0 votes" misrender
    /// *non-representable*: the Camera President, for instance, holds group
    /// memberships yet casts no roll-call votes (a `Tally(0, 0)`), and this type
    /// renders him as an honest absence rather than as 0 % aligned. The
    /// nil-not-fallback rule is thus enforced by the type, not by caller
    /// discipline — a future surface literally cannot format an insufficient
    /// result as a percentage.
    enum Alignment: Equatable {
        /// Renderable: `denominator >= minimumDenominator`; `percentage` is the
        /// integer share, `denominator` the honest base shown alongside it.
        case value(percentage: Int, denominator: Int)
        /// Too few expressed, group-defined, non-tie votes (or none at all) —
        /// the caller renders nothing.
        case insufficientData
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

    /// The threshold-gated **public** result the UI consumes. `.insufficientData`
    /// below the minimum denominator (0/0 included); otherwise a renderable
    /// `.value`. This is the only entry point a view should call — it can never
    /// hand back a formattable zero.
    static func alignment(
        representativeId: String,
        events: [VoteEventRecord],
        positions: [VotePositionRecord],
        memberships: [GroupMembership]
    ) -> Alignment {
        let tally = tally(representativeId: representativeId, events: events, positions: positions, memberships: memberships)
        guard tally.denominator >= minimumDenominator else { return .insufficientData }
        let percentage = Int((Double(tally.matched) / Double(tally.denominator) * 100).rounded())
        return .value(percentage: percentage, denominator: tally.denominator)
    }

    /// The value line for a renderable result. A *total* function on the
    /// `.value` payload, so there is no code path that formats an insufficient
    /// result — e.g. `"96% — su 27 voti espressi"`.
    static func valueText(percentage: Int, denominator: Int) -> String {
        "\(percentage)% — su \(denominator) voti espressi"
    }

    /// VoiceOver label for a renderable result — spells the value out as a
    /// sentence rather than a bare percentage.
    static func accessibilityText(percentage: Int, denominator: Int) -> String {
        "\(metricLabel): \(percentage) percento, su \(denominator) voti espressi."
    }

    /// Pure arithmetic tally. Scans `positions` once to build, per
    /// `(event, group-at-date)`, the group's expressed-position cohort and its
    /// majority, then tallies the target deputy's own expressed positions
    /// against the majority of the group they held **on each vote's date**.
    ///
    /// Order-independent by construction (it counts positions), so the result
    /// is deterministic regardless of input or dictionary iteration order. A
    /// deputy with no expressed, group-defined, non-tie vote returns
    /// `Tally(matched: 0, denominator: 0)` (senators, who have no positions,
    /// among them) — which `alignment(...)` maps to `.insufficientData`. This
    /// function is the internal/testing seam; the UI calls `alignment(...)`.
    static func tally(
        representativeId: String,
        events: [VoteEventRecord],
        positions: [VotePositionRecord],
        memberships: [GroupMembership]
    ) -> Tally {
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
        return Tally(matched: matched, denominator: denominator)
    }
}
