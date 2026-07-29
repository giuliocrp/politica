//
//  VoteBrowsingTests.swift
//  PoliticiTests
//

import XCTest
@testable import Politici

/// Coverage for Phase 20 (see docs/v3/20-vote-browsing.md): the normalized
/// votes schema, the voteEventId-keyed aggregation as a pure function, the
/// flat-fixture fallback path, and the VoteHistory filter logic.
final class VoteBrowsingTests: XCTestCase {
    private func date(_ string: String) throws -> Date {
        try XCTUnwrap(Vote.dateFormatter.date(from: string))
    }

    private func event(id: String, title: String = "Votazione di prova", date: String = "2026-01-01", sourceUrl: String? = nil) throws -> VoteEventRecord {
        VoteEventRecord(
            id: id, title: title, date: try self.date(date),
            result: .approvato, sourceUrl: sourceUrl, provenance: .official
        )
    }

    private func position(id: String, eventId: String, representativeId: String = "p1", vote: VoteChoice) -> VotePositionRecord {
        VotePositionRecord(id: id, voteEventId: eventId, representativeId: representativeId, vote: vote)
    }

    // MARK: - Shipping data invariants

    func testShippingVotesFileMatchesPhase20Invariants() throws {
        let file = try LocalJSONLoader.decode(VotesFile.self, fromResource: "votes")
        XCTAssertEqual(file.events.count, 30, "the Phase 27 stratified sample is 30 events")
        XCTAssertTrue(file.positions.allSatisfy { !$0.voteEventId.isEmpty })
        XCTAssertEqual(
            Set(file.positions.map(\.voteEventId)),
            Set(file.events.map(\.id)),
            "distinct voteEventId set must be exactly the event-id set"
        )
    }

    func testShippingAggregatedTallySumsEqualPositionCounts() throws {
        let file = try LocalJSONLoader.decode(VotesFile.self, fromResource: "votes")
        let events = VoteService.aggregateEvents(file.events, positions: file.positions)
        let positionsByEvent = Dictionary(grouping: file.positions, by: \.voteEventId)
        XCTAssertEqual(events.count, 30)
        for event in events {
            XCTAssertEqual(
                event.totalPositions,
                positionsByEvent[event.id]?.count ?? 0,
                "event \(event.id): tally sum must equal its position count"
            )
        }
    }

    // MARK: - Aggregation as a pure function

    func testAggregationIsStableUnderPositionOrder() throws {
        let events = [try event(id: "vs19_1_001"), try event(id: "vs19_1_002")]
        let positions = [
            position(id: "a", eventId: "vs19_1_001", vote: .favorevole),
            position(id: "b", eventId: "vs19_1_001", vote: .contrario),
            position(id: "c", eventId: "vs19_1_002", vote: .astenuto),
            position(id: "d", eventId: "vs19_1_001", vote: .favorevole),
            position(id: "e", eventId: "vs19_1_002", vote: .assente),
        ]
        let aggregated = VoteService.aggregateEvents(events, positions: positions)
        let aggregatedShuffled = VoteService.aggregateEvents(events, positions: positions.reversed())
        XCTAssertEqual(aggregated, aggregatedShuffled, "aggregation must not depend on position order")
        XCTAssertEqual(aggregated[0].counts, [.favorevole: 2, .contrario: 1])
        XCTAssertEqual(aggregated[1].counts, [.astenuto: 1, .assente: 1])
    }

    func testAggregationKeysStrictlyOnVoteEventIdNotSourceUrl() throws {
        // Two distinct events deliberately sharing title, date, AND
        // sourceUrl: only voteEventId may tell them apart. This is the
        // grep-able guarantee that no sourceUrl-keyed grouping exists.
        let shared = "https://example.invalid/stessa-scheda"
        let events = [
            try event(id: "vs19_1_001", sourceUrl: shared),
            try event(id: "vs19_1_002", sourceUrl: shared),
        ]
        let positions = [
            position(id: "a", eventId: "vs19_1_001", vote: .favorevole),
            position(id: "b", eventId: "vs19_1_002", vote: .contrario),
        ]
        let aggregated = VoteService.aggregateEvents(events, positions: positions)
        XCTAssertEqual(aggregated.count, 2)
        XCTAssertEqual(aggregated[0].counts, [.favorevole: 1])
        XCTAssertEqual(aggregated[1].counts, [.contrario: 1])
    }

    // MARK: - Flat-fixture fallback

    // Now async: VoteService loads lazily (Phase 27), so tests that read its
    // decoded data must `await loadIfNeeded()` first.
    @MainActor
    func testSampleFlatFixtureLoadsViaFallbackWithNoEvents() async {
        let service = VoteService(resource: "votes.sample")
        await service.loadIfNeeded()
        XCTAssertFalse(service.votes.isEmpty, "the frozen flat fixture must keep decoding")
        XCTAssertTrue(
            service.allEvents().isEmpty,
            "flat mode has no source-backed event ids, so no events may be synthesized"
        )
    }

    @MainActor
    func testShippingServiceJoinsEventFieldsIntoVotes() async throws {
        let service = VoteService()
        await service.loadIfNeeded()
        XCTAssertNil(service.loadError)
        XCTAssertFalse(service.votes.isEmpty)
        let file = try LocalJSONLoader.decode(VotesFile.self, fromResource: "votes")
        XCTAssertEqual(service.votes.count, file.positions.count, "every position joins to exactly one Vote")
        XCTAssertTrue(service.votes.allSatisfy { !$0.title.isEmpty && $0.provenance == .official })
    }

    // MARK: - Lazy loading (Phase 27 — docs/v4/27-votes-stratified.md)

    @MainActor
    func testLoadIfNeededTransitionsIdleToLoaded() async {
        let service = VoteService()
        XCTAssertEqual(service.state, .idle, "nothing loads at init")
        XCTAssertTrue(service.votes.isEmpty, "no decode before loadIfNeeded")
        await service.loadIfNeeded()
        XCTAssertEqual(service.state, .loaded)
        XCTAssertFalse(service.votes.isEmpty)
        XCTAssertNil(service.loadError)
    }

    @MainActor
    func testConcurrentLoadIfNeededIsIdempotent() async throws {
        let service = VoteService()
        // Many concurrent callers must all observe one consistent load, not a
        // doubled or re-run decode.
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<25 { group.addTask { await service.loadIfNeeded() } }
        }
        XCTAssertEqual(service.state, .loaded)
        let file = try LocalJSONLoader.decode(VotesFile.self, fromResource: "votes")
        XCTAssertEqual(
            service.votes.count, file.positions.count,
            "concurrent loadIfNeeded must load exactly once (no doubled positions)"
        )
    }

    #if DEBUG
    @MainActor
    func testShippingDecodeRunsOffTheMainThread() async {
        let service = VoteService()
        await service.loadIfNeeded()
        XCTAssertTrue(
            VoteService.lastDecodeRanOffMainThread,
            "votes.json must be decoded off the main thread (Task.detached)"
        )
    }
    #endif

    // MARK: - VoteHistory filter logic (pure function)

    private func vote(id: String, title: String, choice: VoteChoice) throws -> Vote {
        Vote(
            id: id, representativeId: "p1", title: title, date: try date("2026-01-01"),
            vote: choice, result: .approvato, sourceUrl: nil, provenance: .official
        )
    }

    func testFilterByChoiceAndSearchCompose() throws {
        let votes = [
            try vote(id: "1", title: "Votazione finale — Decreto Scuola", choice: .favorevole),
            try vote(id: "2", title: "Ordine del giorno — Sanità", choice: .favorevole),
            try vote(id: "3", title: "Votazione finale — Decreto Scuola", choice: .contrario),
        ]

        XCTAssertEqual(VoteHistoryView.filtered(votes, choice: nil, searchText: "").map(\.id), ["1", "2", "3"])
        XCTAssertEqual(VoteHistoryView.filtered(votes, choice: .favorevole, searchText: "").map(\.id), ["1", "2"])
        XCTAssertEqual(VoteHistoryView.filtered(votes, choice: nil, searchText: "scuola").map(\.id), ["1", "3"])
        XCTAssertEqual(
            VoteHistoryView.filtered(votes, choice: .favorevole, searchText: "scuola").map(\.id),
            ["1"],
            "chip and search must compose with AND"
        )
        XCTAssertTrue(VoteHistoryView.filtered(votes, choice: .astenuto, searchText: "scuola").isEmpty)
    }

    func testFilterSearchIsCaseAndWhitespaceInsensitive() throws {
        let votes = [try vote(id: "1", title: "Decreto Sanità", choice: .favorevole)]
        XCTAssertEqual(VoteHistoryView.filtered(votes, choice: nil, searchText: "  SANITÀ ").count, 1)
        XCTAssertEqual(VoteHistoryView.filtered(votes, choice: nil, searchText: "   ").count, 1, "blank search matches all")
    }
}
