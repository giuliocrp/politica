//
//  Representative.swift
//  Politici
//

import Foundation

enum ElectionType: String, TolerantStringEnum, Hashable {
    case uninominale
    case plurinominale
    case estero
    case sconosciuto

    static var unknownCase: ElectionType { .sconosciuto }
}

extension ElectionType: Codable {
    init(from decoder: Decoder) throws {
        self = try Self.decodeTolerant(from: decoder)
    }
}

struct Representative: Identifiable, Hashable {
    let id: String
    let name: String
    let chamber: Chamber
    let districtId: String
    let party: String
    let parliamentaryGroup: String
    let committees: [String]
    let attendanceRate: Double?
    let photoName: String
    let provenance: DataProvenance
    let legislature: String?
    let electionType: ElectionType
    let stableSourceId: String?
    let sourceUrl: URL?
}

/// `provenance` defaults to `.sample` and `electionType` defaults to
/// `.sconosciuto` when absent, so the current sample fixture (which predates
/// these fields) keeps decoding unchanged.
extension Representative: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, chamber, districtId, party, parliamentaryGroup, committees
        case attendanceRate, photoName, provenance, legislature, electionType
        case stableSourceId, sourceUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        chamber = try container.decode(Chamber.self, forKey: .chamber)
        districtId = try container.decode(String.self, forKey: .districtId)
        party = try container.decode(String.self, forKey: .party)
        parliamentaryGroup = try container.decode(String.self, forKey: .parliamentaryGroup)
        committees = try container.decode([String].self, forKey: .committees)
        attendanceRate = try container.decodeIfPresent(Double.self, forKey: .attendanceRate)
        photoName = try container.decode(String.self, forKey: .photoName)
        provenance = try container.decodeIfPresent(DataProvenance.self, forKey: .provenance) ?? .sample
        legislature = try container.decodeIfPresent(String.self, forKey: .legislature)
        electionType = try container.decodeIfPresent(ElectionType.self, forKey: .electionType) ?? .sconosciuto
        stableSourceId = try container.decodeIfPresent(String.self, forKey: .stableSourceId)
        sourceUrl = try container.decodeIfPresent(URL.self, forKey: .sourceUrl)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(chamber, forKey: .chamber)
        try container.encode(districtId, forKey: .districtId)
        try container.encode(party, forKey: .party)
        try container.encode(parliamentaryGroup, forKey: .parliamentaryGroup)
        try container.encode(committees, forKey: .committees)
        try container.encodeIfPresent(attendanceRate, forKey: .attendanceRate)
        try container.encode(photoName, forKey: .photoName)
        try container.encode(provenance, forKey: .provenance)
        try container.encodeIfPresent(legislature, forKey: .legislature)
        try container.encode(electionType, forKey: .electionType)
        try container.encodeIfPresent(stableSourceId, forKey: .stableSourceId)
        try container.encodeIfPresent(sourceUrl, forKey: .sourceUrl)
    }
}
