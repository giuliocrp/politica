//
//  Vote.swift
//  Politici
//

import Foundation

enum VoteChoice: String, Codable, CaseIterable, Hashable {
    case favorevole = "Favorevole"
    case contrario = "Contrario"
    case astenuto = "Astenuto"
    case assente = "Assente"
}

enum VoteResult: String, Codable, CaseIterable, Hashable {
    case approvato = "Approvato"
    case respinto = "Respinto"
}

struct Vote: Identifiable, Hashable {
    let id: String
    let representativeId: String
    let title: String
    let date: Date
    let vote: VoteChoice
    let result: VoteResult
    let sourceUrl: String?
}

/// Decodes/encodes `date` as a plain `yyyy-MM-dd` string so the model stays
/// self-contained regardless of which `JSONDecoder` configuration loads it.
extension Vote: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, representativeId, title, date, vote, result, sourceUrl
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
    }
}
