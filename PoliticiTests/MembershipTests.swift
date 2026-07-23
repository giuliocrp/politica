//
//  MembershipTests.swift
//  PoliticiTests
//
//  Phase 28 — group-membership history (docs/v4/28-membership-history.md).
//

import XCTest
@testable import Politici

final class MembershipTests: XCTestCase {
    private func d(_ s: String) -> Date { Vote.dateFormatter.date(from: s)! }

    /// A real-shaped group-switcher: LEGA until 2026-05-20, then MISTO (open).
    /// The handoff is same-day (old `end` == new `start`) — exactly the source
    /// pattern the half-open rule is designed for.
    private func switcher() -> [GroupMembership] {
        [
            GroupMembership(
                id: "m_pX_20221018", representativeId: "pX",
                groupName: "LEGA - SALVINI PREMIER (LEGA) (18.10.2022", groupSigla: "LEGA",
                start: d("2022-10-18"), end: d("2026-05-20")
            ),
            GroupMembership(
                id: "m_pX_20260520", representativeId: "pX",
                groupName: "MISTO (MISTO) (20.05.2026", groupSigla: "MISTO",
                start: d("2026-05-20"), end: nil
            ),
        ]
    }

    // MARK: - Pure-function edges (spec #3)

    func testMidIntervalResolvesToThatGroup() {
        XCTAssertEqual(MembershipService.membership(at: d("2024-01-01"), in: switcher())?.groupSigla, "LEGA")
    }

    /// Start is inclusive: on the first interval's start date the deputy is
    /// already a member.
    func testStartDateIsInclusive() {
        XCTAssertEqual(MembershipService.membership(at: d("2022-10-18"), in: switcher())?.groupSigla, "LEGA")
    }

    /// The switch day: it is simultaneously the old interval's `end` (exclusive)
    /// and the new interval's `start` (inclusive), so half-open assigns the NEW
    /// group — the day the deputy joined it.
    func testSwitchDayResolvesToNewGroup() {
        XCTAssertEqual(MembershipService.membership(at: d("2026-05-20"), in: switcher())?.groupSigla, "MISTO")
    }

    /// The day before the switch is still the old group — the exclusive-`end`
    /// edge from the other side.
    func testDayBeforeSwitchIsOldGroup() {
        XCTAssertEqual(MembershipService.membership(at: d("2026-05-19"), in: switcher())?.groupSigla, "LEGA")
    }

    /// A date before the first interval resolves to nil — never fabricated as
    /// the earliest known group (the pinned editorial rule).
    func testDateBeforeFirstIntervalIsNil() {
        XCTAssertNil(MembershipService.membership(at: d("2020-01-01"), in: switcher()))
    }

    /// The open-ended current interval covers every date at or after its start,
    /// including far-future dates (`end == nil`).
    func testOpenEndedIntervalCoversFutureDates() {
        XCTAssertEqual(MembershipService.membership(at: d("2030-12-31"), in: switcher())?.groupSigla, "MISTO")
    }

    /// A never-switched deputy (single open interval): inclusive start, covered
    /// mid-range, nil before the start.
    func testSingleOpenIntervalStartInclusiveMidAndBeforeNil() {
        let one = [GroupMembership(
            id: "m_pY_20221018", representativeId: "pY",
            groupName: "FRATELLI D'ITALIA (FDI) (18.10.2022", groupSigla: "FDI",
            start: d("2022-10-18"), end: nil
        )]
        XCTAssertEqual(MembershipService.membership(at: d("2022-10-18"), in: one)?.groupSigla, "FDI")
        XCTAssertEqual(MembershipService.membership(at: d("2025-06-01"), in: one)?.groupSigla, "FDI")
        XCTAssertNil(MembershipService.membership(at: d("2022-10-17"), in: one))
    }

    // MARK: - Shipping data (spec #4 and structure)

    func testShippingMembershipsDecodeWithExpectedStructure() throws {
        let file = try LocalJSONLoader.decode(MembershipsFile.self, fromResource: "memberships_camera")
        XCTAssertEqual(file.schemaVersion, 1)
        // Count itself is data-dependent (grows as deputies switch groups over
        // the legislature), like votes.json — so the STRUCTURE is pinned, not
        // the exact 468: 400 deputies, each with exactly one open interval.
        XCTAssertGreaterThanOrEqual(file.memberships.count, 400)
        XCTAssertEqual(file.memberships.filter { $0.end == nil }.count, 400)
        let byRep = Dictionary(grouping: file.memberships, by: \.representativeId)
        XCTAssertEqual(byRep.count, 400)
        XCTAssertTrue(byRep.values.allSatisfy { intervals in
            intervals.filter { $0.end == nil }.count == 1
        })
        // ids unique; every representativeId is "p"-prefixed (Camera).
        XCTAssertEqual(Set(file.memberships.map(\.id)).count, file.memberships.count)
        XCTAssertTrue(file.memberships.allSatisfy { $0.representativeId.hasPrefix("p") })
    }

    /// Spec #4: for every deputy appearing in votes.json, the group at *today*
    /// equals their shipped group (sigla — the canonical field). This is the
    /// Swift-side twin of validate_data.py's reconciliation invariant.
    func testEveryVotingDeputyGroupAtTodayMatchesShippedGroup() throws {
        let reps = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        let repById = Dictionary(uniqueKeysWithValues: reps.map { ($0.id, $0) })
        let votesFile = try LocalJSONLoader.decode(VotesFile.self, fromResource: "votes")
        let service = MembershipService()
        let today = Date()
        for depId in Set(votesFile.positions.map(\.representativeId)) {
            let rep = try XCTUnwrap(repById[depId], "deputy \(depId) missing from representatives.json")
            let current = service.membershipAt(representativeId: depId, date: today)
            XCTAssertEqual(current?.groupSigla, rep.party, "group-at-today != shipped party for \(depId)")
        }
    }

    /// Real-data boundary anchor: p301459 (Laura Ravetto) switched LEGA → MISTO
    /// on 2026-05-20 — a real vote date in the shipped sample — so half-open
    /// puts her in MISTO that day and LEGA the day before. NOTE: this pins a
    /// specific deputy/date from memberships_camera.json; a future adesioni
    /// refetch that changes her intervals would require re-pinning (a re-pin,
    /// not a regression — same shape as the Phase 27 vote-anchor pins).
    func testShippedSwitcherResolvesAcrossItsBoundaryVoteDate() {
        let service = MembershipService()
        XCTAssertEqual(service.membershipAt(representativeId: "p301459", date: d("2026-05-20"))?.groupSigla, "MISTO")
        XCTAssertEqual(service.membershipAt(representativeId: "p301459", date: d("2026-05-19"))?.groupSigla, "LEGA")
    }
}
