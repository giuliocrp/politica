//
//  VoteService.swift
//  Politici
//

import Foundation

/// Loads `votes.json` once and answers vote-history lookups.
final class VoteService {
    static let shared = VoteService()

    private(set) var votes: [Vote] = []
    private(set) var loadError: Error?

    init(resource: String = "votes", bundle: Bundle = .main) {
        do {
            votes = try LocalJSONLoader.decode(
                [Vote].self,
                fromResource: resource,
                bundle: bundle
            )
        } catch {
            loadError = error
            votes = []
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
}
