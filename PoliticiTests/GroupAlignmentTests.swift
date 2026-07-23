//
//  GroupAlignmentTests.swift
//  PoliticiTests
//
//  Phase 29 — group-alignment metric (docs/v4/29-alignment-metric.md).
//
//  The expected values below were HAND-COMPUTED and recorded in the phase
//  report BEFORE the implementation was run (the verify-expectations-
//  independently rule), one fixture per gate/edge rule. Each test's doc comment
//  restates its hand computation so the assertion is auditable against the
//  report, not against whatever the code happens to return.
//

import XCTest
@testable import Politici

final class GroupAlignmentTests: XCTestCase {
    private func d(_ s: String) -> Date { Vote.dateFormatter.date(from: s)! }

    /// One open (current) interval for `rep` in `sigla`, since 2020-01-01.
    private func openMember(_ rep: String, _ sigla: String, since: String = "2020-01-01") -> GroupMembership {
        GroupMembership(
            id: "m_\(rep)_\(sigla)", representativeId: rep,
            groupName: "\(sigla) (\(sigla))", groupSigla: sigla,
            start: d(since), end: nil
        )
    }

    private func event(_ id: String, _ date: String) -> VoteEventRecord {
        VoteEventRecord(id: id, title: id, date: d(date), result: .approvato, sourceUrl: nil, provenance: .official)
    }

    private func pos(_ event: String, _ rep: String, _ choice: VoteChoice) -> VotePositionRecord {
        VotePositionRecord(id: "\(event)_\(rep)", voteEventId: event, representativeId: rep, vote: choice)
    }

    // MARK: - majorityChoice (the tie / expressed-only helper)

    /// Plurality wins; a top-count tie (of two or four expressed positions)
    /// returns nil; astenuto is a first-class winner; absences are ignored when
    /// computing the majority (never counted as a position).
    func testMajorityChoicePluralityTieAndExpressedOnly() {
        XCTAssertEqual(GroupAlignment.majorityChoice([.favorevole, .favorevole, .contrario]), .favorevole)
        XCTAssertNil(GroupAlignment.majorityChoice([.favorevole, .contrario]))
        XCTAssertNil(GroupAlignment.majorityChoice([.favorevole, .favorevole, .contrario, .contrario]))
        XCTAssertEqual(GroupAlignment.majorityChoice([.astenuto, .astenuto, .favorevole]), .astenuto)
        // Absences drop out: only the single Favorevole is expressed → Favorevole.
        XCTAssertEqual(GroupAlignment.majorityChoice([.assente, .assente, .favorevole]), .favorevole)
        XCTAssertNil(GroupAlignment.majorityChoice([.assente]))
        XCTAssertNil(GroupAlignment.majorityChoice([]))
    }

    // MARK: - Pure-function fixtures (spec #2)

    /// UNANIMOUS group + astenuto aligned. G = {r1,r2,r3}, all vote the same on
    /// both events: E1 all Favorevole (majority Fav), E2 all Astenuto (majority
    /// Astenuto). r1 matches both → 2/2. Confirms astenuto is scored as its own
    /// aligned category, not folded into anything.
    func testUnanimousGroupAllAlignedIncludingAstenuto() {
        let events = [event("E1", "2026-01-01"), event("E2", "2026-01-02")]
        let positions = [
            pos("E1", "r1", .favorevole), pos("E1", "r2", .favorevole), pos("E1", "r3", .favorevole),
            pos("E2", "r1", .astenuto), pos("E2", "r2", .astenuto), pos("E2", "r3", .astenuto),
        ]
        let memberships = [openMember("r1", "G"), openMember("r2", "G"), openMember("r3", "G")]
        let score = GroupAlignment.score(representativeId: "r1", events: events, positions: positions, memberships: memberships)
        XCTAssertEqual(score, GroupAlignment.Score(matched: 2, denominator: 2))
        XCTAssertEqual(score.percentage, 100)
    }

    /// SPLIT group. E1: r1 Contrario against r2..r5 Favorevole → majority Fav
    /// (4-1). The dissenter r1 → 0/1 (0%); a follower r2 → 1/1 (100%).
    func testSplitGroupDissenterUnalignedFollowerAligned() {
        let events = [event("E1", "2026-01-01")]
        let positions = [
            pos("E1", "r1", .contrario),
            pos("E1", "r2", .favorevole), pos("E1", "r3", .favorevole),
            pos("E1", "r4", .favorevole), pos("E1", "r5", .favorevole),
        ]
        let memberships = ["r1", "r2", "r3", "r4", "r5"].map { openMember($0, "G") }
        let dissenter = GroupAlignment.score(representativeId: "r1", events: events, positions: positions, memberships: memberships)
        let follower = GroupAlignment.score(representativeId: "r2", events: events, positions: positions, memberships: memberships)
        XCTAssertEqual(dissenter, GroupAlignment.Score(matched: 0, denominator: 1))
        XCTAssertEqual(dissenter.percentage, 0)
        XCTAssertEqual(follower, GroupAlignment.Score(matched: 1, denominator: 1))
    }

    /// TIE-EXCLUSION. E1: G = {r1,r2 Fav; r3,r4 Contr} → 2-2 tie → no majority →
    /// the vote is excluded from every member's denominator. E2: all Favorevole
    /// (majority Fav), r1 matches. So r1 = 1/1, NOT 1/2 or 2/2 — the tie vote is
    /// gone from the base, the decisive check on the tie rule.
    func testGroupMajorityTieExcludesThatVoteFromDenominator() {
        let events = [event("E1", "2026-01-01"), event("E2", "2026-01-02")]
        let positions = [
            pos("E1", "r1", .favorevole), pos("E1", "r2", .favorevole),
            pos("E1", "r3", .contrario), pos("E1", "r4", .contrario),
            pos("E2", "r1", .favorevole), pos("E2", "r2", .favorevole),
            pos("E2", "r3", .favorevole), pos("E2", "r4", .favorevole),
        ]
        let memberships = ["r1", "r2", "r3", "r4"].map { openMember($0, "G") }
        let score = GroupAlignment.score(representativeId: "r1", events: events, positions: positions, memberships: memberships)
        XCTAssertEqual(score, GroupAlignment.Score(matched: 1, denominator: 1))
    }

    /// ABSENCE-EXCLUSION. E1: r1 Assente, r2/r3 Favorevole → majority (over
    /// expressed only) Fav; r1 has no expressed position, so E1 is not in r1's
    /// denominator — the absence is neither agreement NOR disagreement. E2: r1
    /// Favorevole, matches. r1 = 1/1 (not 1/2 and not 0/2). The always-present
    /// r2 sees both events → 2/2, confirming E1's majority was still computed.
    func testAbsenceExcludedNotCountedAsDisagreement() {
        let events = [event("E1", "2026-01-01"), event("E2", "2026-01-02")]
        let positions = [
            pos("E1", "r1", .assente), pos("E1", "r2", .favorevole), pos("E1", "r3", .favorevole),
            pos("E2", "r1", .favorevole), pos("E2", "r2", .favorevole), pos("E2", "r3", .favorevole),
        ]
        let memberships = ["r1", "r2", "r3"].map { openMember($0, "G") }
        let absentThenPresent = GroupAlignment.score(representativeId: "r1", events: events, positions: positions, memberships: memberships)
        let alwaysPresent = GroupAlignment.score(representativeId: "r2", events: events, positions: positions, memberships: memberships)
        XCTAssertEqual(absentThenPresent, GroupAlignment.Score(matched: 1, denominator: 1))
        XCTAssertEqual(alwaysPresent, GroupAlignment.Score(matched: 2, denominator: 2))
    }

    /// ASTENUTO AS OWN CATEGORY. E1: r1..r3 Astenuto, r4/r5 Favorevole →
    /// majority Astenuto (3-2). An abstainer r1 → 1/1 (aligned); a Favorevole
    /// voter r4 → 0/1 (astenuto is NOT the same as favorevole).
    func testAstenutoIsItsOwnCategoryForMajorityAndMatch() {
        let events = [event("E1", "2026-01-01")]
        let positions = [
            pos("E1", "r1", .astenuto), pos("E1", "r2", .astenuto), pos("E1", "r3", .astenuto),
            pos("E1", "r4", .favorevole), pos("E1", "r5", .favorevole),
        ]
        let memberships = ["r1", "r2", "r3", "r4", "r5"].map { openMember($0, "G") }
        let abstainer = GroupAlignment.score(representativeId: "r1", events: events, positions: positions, memberships: memberships)
        let favVoter = GroupAlignment.score(representativeId: "r4", events: events, positions: positions, memberships: memberships)
        XCTAssertEqual(abstainer, GroupAlignment.Score(matched: 1, denominator: 1))
        XCTAssertEqual(favVoter, GroupAlignment.Score(matched: 0, denominator: 1))
    }

    /// THRESHOLD BOUNDARY (denominator 9 vs 10). 10 events; group {r1,r2} both
    /// Favorevole (so every majority is Fav and r1 always aligns). At 9 expressed
    /// (r1 Assente on E10) → 9/9, below the threshold of 10 → renders nothing
    /// (valueText nil). At 10 expressed → 10/10, at the threshold → renders.
    func testThresholdBoundaryNineDoesNotRenderTenDoes() {
        let dates = (1...10).map { String(format: "2026-01-%02d", $0) }
        let events = zip(1...10, dates).map { event("E\($0.0)", $0.1) }
        var positions: [VotePositionRecord] = []
        for i in 1...10 {
            positions.append(pos("E\(i)", "r2", .favorevole))
            // r1 expresses on E1..E9; on E10 r1 is Assente in the 9-case.
            positions.append(pos("E\(i)", "r1", i == 10 ? .assente : .favorevole))
        }
        let memberships = ["r1", "r2"].map { openMember($0, "G") }
        let nine = GroupAlignment.score(representativeId: "r1", events: events, positions: positions, memberships: memberships)
        XCTAssertEqual(nine, GroupAlignment.Score(matched: 9, denominator: 9))
        XCTAssertFalse(nine.meetsThreshold)
        XCTAssertNil(GroupAlignment.valueText(for: nine))

        // Flip r1's E10 absence to a real expressed vote → denominator 10.
        positions.removeAll { $0.id == "E10_r1" }
        positions.append(pos("E10", "r1", .favorevole))
        let ten = GroupAlignment.score(representativeId: "r1", events: events, positions: positions, memberships: memberships)
        XCTAssertEqual(ten, GroupAlignment.Score(matched: 10, denominator: 10))
        XCTAssertTrue(ten.meetsThreshold)
        XCTAssertNotNil(GroupAlignment.valueText(for: ten))
    }

    /// GROUP-SWITCHER whose alignment DIFFERS BY INTERVAL (the point of Phase
    /// 28). r1 is in G1 until 2026-03-01, then G2. E1 (2026-02-01) and E2
    /// (2026-03-15). On E1, G1 is unanimously Contrario (r1 matches) while G2 is
    /// Favorevole; on E2, G2 (with r1) is Favorevole (r1 matches).
    /// With the switch, r1 is scored G1@E1 then G2@E2 → 2/2. If r1 had instead
    /// stayed in G2 the whole time, E1 would score against G2's Favorevole
    /// majority → r1 Contrario unaligned → 1/2. The two scores differ, which is
    /// exactly the fabrication the date-aware attribution prevents.
    func testGroupSwitcherAlignmentDiffersByInterval() {
        let events = [event("E1", "2026-02-01"), event("E2", "2026-03-15")]
        let positions = [
            // E1 (before switch): G1 all Contrario (incl. r1); G2 all Favorevole.
            pos("E1", "r1", .contrario), pos("E1", "gA", .contrario), pos("E1", "gB", .contrario),
            pos("E1", "g2a", .favorevole), pos("E1", "g2b", .favorevole),
            // E2 (after switch): G1 Contrario; G2 all Favorevole (incl. r1).
            pos("E2", "r1", .favorevole), pos("E2", "gA", .contrario), pos("E2", "gB", .contrario),
            pos("E2", "g2a", .favorevole), pos("E2", "g2b", .favorevole),
        ]
        let others = [openMember("gA", "G1"), openMember("gB", "G1"), openMember("g2a", "G2"), openMember("g2b", "G2")]
        let switching = others + [
            GroupMembership(id: "m_r1_G1", representativeId: "r1", groupName: "G1 (G1)", groupSigla: "G1",
                            start: d("2020-01-01"), end: d("2026-03-01")),
            GroupMembership(id: "m_r1_G2", representativeId: "r1", groupName: "G2 (G2)", groupSigla: "G2",
                            start: d("2026-03-01"), end: nil),
        ]
        let neverSwitched = others + [openMember("r1", "G2")]

        let withSwitch = GroupAlignment.score(representativeId: "r1", events: events, positions: positions, memberships: switching)
        let withoutSwitch = GroupAlignment.score(representativeId: "r1", events: events, positions: positions, memberships: neverSwitched)
        XCTAssertEqual(withSwitch, GroupAlignment.Score(matched: 2, denominator: 2))
        XCTAssertEqual(withoutSwitch, GroupAlignment.Score(matched: 1, denominator: 2))
        XCTAssertNotEqual(withSwitch, withoutSwitch)
    }

    /// A representative with no positions at all (e.g. a senator, or the Camera
    /// President who casts no roll-call votes) → 0/0: below threshold, no
    /// percentage, no value line, no a11y line. Never a fabricated 0%.
    func testRepresentativeWithNoPositionsRendersNothing() {
        let score = GroupAlignment.score(representativeId: "sX", events: [], positions: [], memberships: [])
        XCTAssertEqual(score, GroupAlignment.Score(matched: 0, denominator: 0))
        XCTAssertFalse(score.meetsThreshold)
        XCTAssertNil(score.percentage)
        XCTAssertNil(GroupAlignment.valueText(for: score))
        XCTAssertNil(GroupAlignment.accessibilityText(for: score))
    }

    // MARK: - Pinned Italian strings (spec #3 — the shipping vocabulary)

    /// The exact user-facing strings this phase introduces. Pinning them here is
    /// the regression guard; the report records the same wording verbatim.
    func testPinnedItalianStringsAndValueFormatting() {
        XCTAssertEqual(GroupAlignment.metricLabel, "Allineamento nel campione di votazioni importate")
        XCTAssertEqual(GroupAlignment.minimumDenominator, 10)
        XCTAssertEqual(
            GroupAlignment.sampleCaption,
            "Quota dei voti espressi (favorevole, contrario o astenuto) che coincidono con la posizione di maggioranza del gruppo di appartenenza alla data di ciascun voto; le assenze sono escluse. Il campione di votazioni importate è scelto per copertura ed è in parte procedurale: la percentuale descrive il comportamento su questo campione, non l'attività complessiva in Parlamento. Nei gruppi molto piccoli, incluso il Gruppo Misto, l'allineamento è quasi automatico."
        )
        // Integer percentage, rounded to nearest, with the denominator shown.
        XCTAssertEqual(GroupAlignment.valueText(for: .init(matched: 26, denominator: 27)), "96% — su 27 voti espressi") // 96.296 → 96
        XCTAssertEqual(GroupAlignment.valueText(for: .init(matched: 24, denominator: 27)), "89% — su 27 voti espressi") // 88.888 → 89
        XCTAssertNil(GroupAlignment.valueText(for: .init(matched: 9, denominator: 9)))                                   // below threshold
        XCTAssertEqual(
            GroupAlignment.accessibilityText(for: .init(matched: 27, denominator: 27)),
            "Allineamento nel campione di votazioni importate: 100 percento, su 27 voti espressi."
        )
    }

    // MARK: - Shipping data (spec #5 + determinism)

    private func shippingInputs() throws -> (events: [VoteEventRecord], positions: [VotePositionRecord],
                                             memberships: [GroupMembership], reps: [Representative]) {
        let votes = try LocalJSONLoader.decode(VotesFile.self, fromResource: "votes")
        let memberships = try LocalJSONLoader.decode(MembershipsFile.self, fromResource: "memberships_camera").memberships
        let reps = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        return (votes.events, votes.positions, memberships, reps)
    }

    /// Determinism proven by DIFF, not inspection: compute every deputy's score
    /// twice over the identical shipping input, serialize both to a canonical
    /// sorted string, and assert byte-identical. The computation is
    /// order-independent by construction (it counts positions), and this is the
    /// check that it stays so.
    func testShippingScoresAreDeterministic() throws {
        let (events, positions, memberships, reps) = try shippingInputs()
        let camera = reps.filter { $0.chamber == .camera }.map(\.id).sorted()
        func dump() -> String {
            camera.map { id in
                let s = GroupAlignment.score(representativeId: id, events: events, positions: positions, memberships: memberships)
                return "\(id):\(s.matched)/\(s.denominator)"
            }.joined(separator: "\n")
        }
        XCTAssertEqual(dump(), dump())
    }

    /// Shipping invariants, robust to a future refetch (no exact per-deputy
    /// value is pinned — those shift with the sample, like votes.json's count):
    /// every Camera score is in bounds (0 ≤ matched ≤ denominator ≤ event count),
    /// a substantial number of deputies render, and senators — Camera-only votes
    /// — always score 0/0 so the metric never appears for them.
    func testShippingScoresAreWithinBoundsAndCameraOnly() throws {
        let (events, positions, memberships, reps) = try shippingInputs()
        let eventCount = events.count
        var rendered = 0
        for rep in reps where rep.chamber == .camera {
            let s = GroupAlignment.score(representativeId: rep.id, events: events, positions: positions, memberships: memberships)
            XCTAssertGreaterThanOrEqual(s.matched, 0)
            XCTAssertLessThanOrEqual(s.matched, s.denominator)
            XCTAssertLessThanOrEqual(s.denominator, eventCount)
            if s.meetsThreshold { rendered += 1 }
        }
        XCTAssertGreaterThanOrEqual(rendered, 100, "expected many Camera deputies to clear the threshold")
        for rep in reps where rep.chamber == .senato {
            let s = GroupAlignment.score(representativeId: rep.id, events: events, positions: positions, memberships: memberships)
            XCTAssertEqual(s, GroupAlignment.Score(matched: 0, denominator: 0), "senator \(rep.id) must have no metric")
        }
    }
}
