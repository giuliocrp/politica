//
//  VoteService.swift
//  Politici
//

import Foundation
import Observation

/// Loads `votes.json` lazily and answers vote-history lookups plus the
/// Phase 20 per-event aggregation.
///
/// **Lazy loading (Phase 27 — docs/v4/27-votes-stratified.md).** The
/// stratified expansion grew `votes.json` from 711 KB to ~1.7 MB, whose cold
/// decode measured ~20 ms — enough to be a visible main-thread hitch if done
/// eagerly at launch. So decoding is deferred to the first `loadIfNeeded()`
/// and runs **off** the main thread (`Task.detached`), with the decoded
/// result applied back on the main actor. `@Observable`, so the three
/// consuming screens (Votazioni, VoteHistory, the profile's recent-votes
/// section) can render an idle/loading/loaded/failed state.
///
/// Two on-disk shapes are accepted: the normalized Phase 20
/// `{"events":[...],"positions":[...]}` schema (the shipping file), tried
/// first; and the older flat `[Vote]` array, kept as a fallback because the
/// frozen `votes.sample.json` fixture still uses it. In flat mode there are
/// no event records and `allEvents()` is empty by design — the aggregation is
/// keyed strictly on the source-backed `voteEventId`, and synthesizing events
/// from any other field (e.g. grouping by `sourceUrl`) is exactly what the
/// Phase 20 gate forbids.
@Observable
final class VoteService {
    /// idle → loading → loaded/failed. Consumed by the views to switch
    /// between a `ProgressView` and the content.
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed
    }

    static let shared = VoteService()

    private(set) var state: LoadState = .idle
    private(set) var votes: [Vote] = []
    private(set) var eventRecords: [VoteEventRecord] = []
    private(set) var positionRecords: [VotePositionRecord] = []
    private(set) var loadError: Error?

    private let resource: String
    private let bundle: Bundle
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    #if DEBUG
    /// Set by `decode(...)` to whether it actually ran off the main thread —
    /// read by a unit test to prove the decode happens off the main actor.
    /// DEBUG only; sequenced by the `await` in `loadIfNeeded`, never read
    /// concurrently with the write.
    nonisolated(unsafe) static var lastDecodeRanOffMainThread = false
    #endif

    init(resource: String = "votes", bundle: Bundle = .main) {
        self.resource = resource
        self.bundle = bundle
    }

    /// Idempotent under concurrent callers: the first call starts one
    /// detached decode; a concurrent caller awaits that same in-flight task;
    /// once `loaded`/`failed` every later call returns immediately. The decode
    /// runs in a `Task.detached` (off the main actor) and the result is
    /// applied on the main actor.
    func loadIfNeeded() async {
        switch state {
        case .loaded, .failed:
            return
        case .loading:
            await loadTask?.value
            return
        case .idle:
            break
        }

        state = .loading
        let resource = self.resource
        let bundle = self.bundle
        let task = Task { @MainActor [weak self] in
            let outcome = await Task.detached(priority: .userInitiated) {
                Self.decode(resource: resource, bundle: bundle)
            }.value
            self?.apply(outcome)
        }
        loadTask = task
        await task.value
    }

    private func apply(_ outcome: LoadOutcome) {
        switch outcome {
        case let .success(votes, events, positions):
            self.votes = votes
            self.eventRecords = events
            self.positionRecords = positions
            self.loadError = nil
            self.state = .loaded
        case let .failure(error):
            self.votes = []
            self.eventRecords = []
            self.positionRecords = []
            self.loadError = error
            self.state = .failed
        }
        self.loadTask = nil
    }

    func allVotes() -> [Vote] {
        votes
    }

    func votes(for representativeId: String) -> [Vote] {
        votes
            .filter { $0.representativeId == representativeId }
            .sorted { $0.date > $1.date }
    }

    /// Every imported votazione, newest first — the Votazioni screen's data.
    /// Empty when the loaded resource has no event records (the flat sample
    /// fixture), or before `loadIfNeeded()` has completed.
    func allEvents() -> [VoteEvent] {
        Self.aggregateEvents(eventRecords, positions: positionRecords)
            .sorted { ($0.date, $0.id) > ($1.date, $1.id) }
    }

    // MARK: - Decoding (off the main actor)

    private enum LoadOutcome: Sendable {
        case success(votes: [Vote], events: [VoteEventRecord], positions: [VotePositionRecord])
        case failure(VoteLoadError)
    }

    /// Runs off the main actor (see `loadIfNeeded`). Tries the normalized
    /// schema first, then the flat `[Vote]` fallback for the sample fixture.
    nonisolated private static func decode(resource: String, bundle: Bundle) -> LoadOutcome {
        #if DEBUG
        lastDecodeRanOffMainThread = !Thread.isMainThread
        assert(!Thread.isMainThread, "votes.json must be decoded off the main thread")
        #endif
        do {
            let file = try LocalJSONLoader.decode(VotesFile.self, fromResource: resource, bundle: bundle)
            let votes = joinedVotes(events: file.events, positions: file.positions)
            return .success(votes: votes, events: file.events, positions: file.positions)
        } catch {
            do {
                let flat = try LocalJSONLoader.decode([Vote].self, fromResource: resource, bundle: bundle)
                return .success(votes: flat, events: [], positions: [])
            } catch {
                return .failure(VoteLoadError(message: error.localizedDescription))
            }
        }
    }

    /// Aggregation keyed strictly on `voteEventId`, and independent of
    /// position order (a pure function, unit-tested as such): one `VoteEvent`
    /// per event record, with per-`VoteChoice` counts over exactly the
    /// positions carrying that event's id.
    nonisolated static func aggregateEvents(
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
    /// (`VoteHistoryView`, profile previews) from the normalized records. A
    /// position whose event is missing is skipped — the pipeline validator
    /// guarantees this never happens in shipping data, so it's DEBUG-loud
    /// rather than silently tolerated.
    nonisolated static func joinedVotes(events: [VoteEventRecord], positions: [VotePositionRecord]) -> [Vote] {
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

/// Sendable error carried from the off-main decode back to the main actor
/// (a raw `Error` existential is not `Sendable`).
struct VoteLoadError: Error, LocalizedError, Sendable {
    let message: String
    var errorDescription: String? { message }
}
