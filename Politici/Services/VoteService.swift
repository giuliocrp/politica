//
//  VoteService.swift
//  Politici
//

import Foundation

/// Loads `votes.json` once and answers vote-history lookups plus the
/// Phase 20 per-event aggregation.
///
/// Two on-disk shapes are accepted: the normalized Phase 20
/// `{"events":[...],"positions":[...]}` schema (the shipping file), tried
/// first; and the older flat `[Vote]` array, kept as a fallback because
/// the frozen `votes.sample.json` fixture still uses it. In flat mode
/// there are no event records and `allEvents()` is empty by design — the
/// aggregation is keyed strictly on the source-backed `voteEventId`, and
/// synthesizing events from any other field (e.g. grouping by `sourceUrl`)
/// is exactly what the Phase 20 gate forbids.
final class VoteService {
    static let shared = VoteService()

    private(set) var votes: [Vote] = []
    private(set) var eventRecords: [VoteEventRecord] = []
    private(set) var positionRecords: [VotePositionRecord] = []
    private(set) var loadError: Error?

    init(resource: String = "votes", bundle: Bundle = .main) {
        do {
            let file = try LocalJSONLoader.decode(VotesFile.self, fromResource: resource, bundle: bundle)
            eventRecords = file.events
            positionRecords = file.positions
            votes = Self.joinedVotes(events: file.events, positions: file.positions)
        } catch {
            do {
                votes = try LocalJSONLoader.decode([Vote].self, fromResource: resource, bundle: bundle)
            } catch {
                loadError = error
                votes = []
            }
        }
    }

    func allVotes() -> [Vote] {
        votes
    }

    func votes(for representativeId: String) -> [Vote] {
        votes
            .filter { $0.representativeId == representativeId }
            .sorted { $0.date > $1.date }
    }

    /// Every imported votazione, newest first — the Votazioni screen's
    /// data. Empty when the loaded resource has no event records (the flat
    /// sample fixture).
    func allEvents() -> [VoteEvent] {
        Self.aggregateEvents(eventRecords, positions: positionRecords)
            .sorted { ($0.date, $0.id) > ($1.date, $1.id) }
    }

    /// Aggregation keyed strictly on `voteEventId`, and independent of
    /// position order (a pure function, unit-tested as such): one
    /// `VoteEvent` per event record, with per-`VoteChoice` counts over
    /// exactly the positions carrying that event's id.
    static func aggregateEvents(
        _ events: [VoteEventRecord],
        positions: [VotePositionRecord]
    ) -> [VoteEvent] {
        var countsByEvent: [String: [VoteChoice: Int]] = [:]
        for position in positions {
            countsByEvent[position.voteEventId, default: [:]][position.vote, default: 0] += 1
        }
        return events.map { event in
            VoteEvent(
                id: event.id,
                title: event.title,
                date: event.date,
                result: event.result,
                counts: countsByEvent[event.id] ?? [:],
                sourceUrl: event.sourceUrl
            )
        }
    }

    /// Rebuilds the flat per-position view the rest of the app consumes
    /// (`VoteHistoryView`, profile previews) from the normalized records.
    /// A position whose event is missing is skipped — the pipeline
    /// validator guarantees this never happens in shipping data, so it's
    /// DEBUG-loud rather than silently tolerated.
    static func joinedVotes(events: [VoteEventRecord], positions: [VotePositionRecord]) -> [Vote] {
        let eventsById = Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0) })
        return positions.compactMap { position in
            guard let event = eventsById[position.voteEventId] else {
                #if DEBUG
                assertionFailure("posizione \(position.id) senza evento \(position.voteEventId)")
                #endif
                return nil
            }
            return Vote(
                id: position.id,
                representativeId: position.representativeId,
                title: event.title,
                date: event.date,
                vote: position.vote,
                result: event.result,
                sourceUrl: event.sourceUrl,
                provenance: event.provenance
            )
        }
    }
}
