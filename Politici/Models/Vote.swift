//
//  Vote.swift
//  Politici
//

import Foundation

// `nonisolated` (here and on the other vote models) so VoteService can decode
// votes.json off the main actor (Phase 27) — the project defaults types to
// @MainActor, but these are pure Sendable data models with no UI state.
nonisolated enum VoteChoice: String, TolerantStringEnum, CaseIterable, Hashable {
    case favorevole = "Favorevole"
    case contrario = "Contrario"
    case astenuto = "Astenuto"
    case assente = "Assente"
    case sconosciuto = "Sconosciuto"

    static var unknownCase: VoteChoice { .sconosciuto }

    /// SF Symbol used by `VoteBadge` so the outcome is never conveyed by
    /// color alone.
    var symbolName: String {
        switch self {
        case .favorevole: return "checkmark"
        case .contrario: return "xmark"
        case .astenuto: return "minus"
        case .assente: return "slash.circle"
        case .sconosciuto: return "questionmark"
        }
    }

    /// VoiceOver label for `VoteBadge` — distinct from `rawValue` (the
    /// visible word) so it reads as a clear statement rather than a bare
    /// party-line adjective.
    var accessibilityLabel: String {
        switch self {
        case .favorevole: return "Voto favorevole"
        case .contrario: return "Voto contrario"
        case .astenuto: return "Astenuto"
        case .assente: return "Assente"
        case .sconosciuto: return "Esito non disponibile"
        }
    }
}

nonisolated extension VoteChoice: Codable {
    // Inlined (rather than via TolerantStringEnum.decodeTolerant) so the
    // conformance stays nonisolated for the off-main decode; same tolerant
    // semantics (unknown raw value -> .sconosciuto).
    nonisolated init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = VoteChoice(rawValue: raw) ?? .sconosciuto
    }
}

nonisolated enum VoteResult: String, TolerantStringEnum, CaseIterable, Hashable {
    case approvato = "Approvato"
    case respinto = "Respinto"
    case sconosciuto = "Sconosciuto"

    static var unknownCase: VoteResult { .sconosciuto }
}

nonisolated extension VoteResult: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = VoteResult(rawValue: raw) ?? .sconosciuto
    }
}

nonisolated struct Vote: Identifiable, Hashable {
    let id: String
    let representativeId: String
    let title: String
    let date: Date
    let vote: VoteChoice
    let result: VoteResult
    let sourceUrl: String?
    let provenance: DataProvenance
}

/// Decodes/encodes `date` as a plain `yyyy-MM-dd` string so the model stays
/// self-contained regardless of which `JSONDecoder` configuration loads it.
/// `provenance` defaults to `.sample` when absent, and `vote`/`result` decode
/// tolerantly (unrecognized raw values become `.sconosciuto` rather than
/// throwing), so the current sample fixture keeps decoding unchanged.
nonisolated extension Vote: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, representativeId, title, date, vote, result, sourceUrl, provenance
    }

    /// Shared with `VoteEventRecord` (Phase 20), which stores the same
    /// `yyyy-MM-dd` strings. Nonisolated (via the enclosing type) so it's
    /// usable from the off-main decode (Phase 27); `DateFormatter` is
    /// Sendable and this one is never mutated after construction.
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Rome")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        representativeId = try container.decode(String.self, forKey: .representativeId)
        title = try container.decode(String.self, forKey: .title)
        vote = try container.decode(VoteChoice.self, forKey: .vote)
        result = try container.decode(VoteResult.self, forKey: .result)
        sourceUrl = try container.decodeIfPresent(String.self, forKey: .sourceUrl)
        provenance = try container.decodeIfPresent(DataProvenance.self, forKey: .provenance) ?? .sample

        let dateString = try container.decode(String.self, forKey: .date)
        guard let parsedDate = Self.dateFormatter.date(from: dateString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .date,
                in: container,
                debugDescription: "Formato data non valido: \(dateString)"
            )
        }
        date = parsedDate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(representativeId, forKey: .representativeId)
        try container.encode(title, forKey: .title)
        try container.encode(Self.dateFormatter.string(from: date), forKey: .date)
        try container.encode(vote, forKey: .vote)
        try container.encode(result, forKey: .result)
        try container.encodeIfPresent(sourceUrl, forKey: .sourceUrl)
        try container.encode(provenance, forKey: .provenance)
    }
}

// MARK: - Normalized shipping schema (Phase 20 — docs/v3/20-vote-browsing.md)

/// `votes.json`'s on-disk shape since Phase 20:
/// `{"events":[...],"positions":[...]}` — the once-per-event fields live on
/// `VoteEventRecord`, each position references its event via the
/// source-backed `voteEventId` (the ocd:votazione URI slug, e.g.
/// `"vs19_690_076"` — never minted). The frozen `votes.sample.json` fixture
/// keeps the older flat `[Vote]` shape; `VoteService` decodes either.
nonisolated struct VotesFile: Codable {
    let events: [VoteEventRecord]
    let positions: [VotePositionRecord]
}

nonisolated struct VoteEventRecord: Identifiable, Hashable {
    let id: String
    let title: String
    let date: Date
    let result: VoteResult
    let sourceUrl: String?
    let provenance: DataProvenance
}

nonisolated extension VoteEventRecord: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, title, date, result, sourceUrl, provenance
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        result = try container.decode(VoteResult.self, forKey: .result)
        sourceUrl = try container.decodeIfPresent(String.self, forKey: .sourceUrl)
        provenance = try container.decodeIfPresent(DataProvenance.self, forKey: .provenance) ?? .sample

        let dateString = try container.decode(String.self, forKey: .date)
        guard let parsedDate = Vote.dateFormatter.date(from: dateString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .date,
                in: container,
                debugDescription: "Formato data non valido: \(dateString)"
            )
        }
        date = parsedDate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(Vote.dateFormatter.string(from: date), forKey: .date)
        try container.encode(result, forKey: .result)
        try container.encodeIfPresent(sourceUrl, forKey: .sourceUrl)
        try container.encode(provenance, forKey: .provenance)
    }
}

nonisolated struct VotePositionRecord: Identifiable, Hashable, Codable {
    let id: String
    let voteEventId: String
    let representativeId: String
    let vote: VoteChoice
}

/// One votazione aggregated for the Votazioni screen — counts keyed
/// strictly by `voteEventId` (see `VoteService.aggregateEvents`). Not a
/// decoded type: always derived from the records above.
nonisolated struct VoteEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let date: Date
    let result: VoteResult
    let counts: [VoteChoice: Int]
    let sourceUrl: String?

    var totalPositions: Int { counts.values.reduce(0, +) }
}
