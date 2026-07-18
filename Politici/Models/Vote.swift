//
//  Vote.swift
//  Politici
//

import Foundation

enum VoteChoice: String, TolerantStringEnum, CaseIterable, Hashable {
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

extension VoteChoice: Codable {
    init(from decoder: Decoder) throws {
        self = try Self.decodeTolerant(from: decoder)
    }
}

enum VoteResult: String, TolerantStringEnum, CaseIterable, Hashable {
    case approvato = "Approvato"
    case respinto = "Respinto"
    case sconosciuto = "Sconosciuto"

    static var unknownCase: VoteResult { .sconosciuto }
}

extension VoteResult: Codable {
    init(from decoder: Decoder) throws {
        self = try Self.decodeTolerant(from: decoder)
    }
}

struct Vote: Identifiable, Hashable {
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
extension Vote: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, representativeId, title, date, vote, result, sourceUrl, provenance
    }

    private static let dateFormatter: DateFormatter = {
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
