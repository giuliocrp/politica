//
//  Representative.swift
//  Politici
//

import Foundation

nonisolated enum ElectionType: String, TolerantStringEnum, Hashable {
    case uninominale
    case plurinominale
    case estero
    case sconosciuto

    static var unknownCase: ElectionType { .sconosciuto }
}

nonisolated extension ElectionType: Codable {
    init(from decoder: Decoder) throws {
        self = try Self.decodeTolerant(from: decoder)
    }
}

/// Senato mandate category, decoded from the source's verbatim
/// `osr:tipoMandato` literals (see docs/v3/15-senato-exploration.md §7a for
/// the vocabulary audit and docs/v3/17-senato-mandates.md for the import).
/// The raw values are deliberately the source's own strings, not invented
/// slugs — `.diDirittoEAVita` (Presidente emerito) exists in the vocabulary
/// but is never expected on a currently-serving senator (its only known
/// bearer's mandate has ended); the pipeline validator asserts that stays
/// true. `.sconosciuto` is a decode-time fallback only — the importer fails
/// loudly on unknown raw values rather than ever writing it.
nonisolated enum MandateType: String, TolerantStringEnum, Hashable {
    case elettivo
    case nominaAVita = "a vita, di nomina del Presidente della Repubblica"
    case diDirittoEAVita = "di diritto e a vita, Presidente emerito della Repubblica"
    case sconosciuto

    static var unknownCase: MandateType { .sconosciuto }

    /// Profile badge text — non-nil only for the life-senator-by-appointment
    /// category. The wording reuses the source's own gender-neutral category
    /// phrasing verbatim (initial capital aside): the Senato data provides no
    /// gender field, and "Senatore/Senatrice a vita" would require inferring
    /// gender from the name, which this project never does.
    var profileBadgeLabel: String? {
        self == .nominaAVita ? "A vita, di nomina del Presidente della Repubblica" : nil
    }
}

nonisolated extension MandateType: Codable {
    init(from decoder: Decoder) throws {
        self = try Self.decodeTolerant(from: decoder)
    }
}

nonisolated struct Representative: Identifiable, Hashable {
    let id: String
    let name: String
    let chamber: Chamber
    /// In the current shipping data, only Camera deputies elected in a
    /// collegio uninominale carry a districtId (see the Phase 8 uninominale
    /// linkage in tools/import_representatives.py); it is nil for deputies
    /// elected via the plurinominale/estero routes and always nil for
    /// senators, since Senato collegio boundaries aren't part of this
    /// dataset. Always non-nil for the fictional sample dataset.
    let districtId: String?
    let party: String
    let parliamentaryGroup: String
    let committees: [String]
    let attendanceRate: Double?
    let photoName: String
    let provenance: DataProvenance
    let legislature: String?
    let electionType: ElectionType
    /// Present only for senators (Phase 17): the Senato source's mandate
    /// category. Camera records omit the key entirely — the Camera source
    /// has no equivalent concept, so absence (nil) is honest there rather
    /// than a `.sconosciuto` default.
    let mandate: MandateType?
    /// Present only for deputies (Phase 18): the Camera circoscrizione the
    /// deputy was elected in, stored in districts.geojson's own canonical
    /// casing so it compares/display-matches the district pages exactly;
    /// `"Estero"` for the overseas constituencies. The name deliberately
    /// matches `District.circoscrizione` (and is never `regione`, which is
    /// Senato's distinct grouping concept). Senato records omit the key.
    let circoscrizione: String?
    /// Present only for deputies whose dc:coverage names a plurinominale
    /// collegio (Phase 25 — 389 of 400: every uninominale and plurinominale
    /// deputy, absent for the 8 Estero and the 3 bare records). The value is
    /// the `"CP..."`-prefixed id of a district in
    /// `districts_plurinominali_camera.geojson`; it drives the plurinominale
    /// collegio detail page's deputy list. Senato records never carry it
    /// (Camera-only, same absent-not-null convention as `circoscrizione`).
    let collegioPlurinominale: String?
    /// Present only for elective senators (Phase 26): the regione the senator
    /// was elected in, derived from the source's `osr:regioneElezione` and
    /// stored in districts_senato.geojson's own canonical casing so it
    /// compares/display-matches the Senato district pages exactly; `"Estero"`
    /// for the two overseas-constituency senators. The name deliberately
    /// matches `District.regione` (and is never `circoscrizione`, which is
    /// Camera's distinct grouping concept). It is the Senato-side mirror of the
    /// Camera-only `circoscrizione`: Camera records omit it, and the 5 a-vita
    /// senators omit it too (they aren't elected in a regione).
    let regione: String?
    let stableSourceId: String?
    let sourceUrl: URL?
}

/// `provenance` defaults to `.sample` and `electionType` defaults to
/// `.sconosciuto` when absent, so the current sample fixture (which predates
/// these fields) keeps decoding unchanged.
nonisolated extension Representative: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, chamber, districtId, party, parliamentaryGroup, committees
        case attendanceRate, photoName, provenance, legislature, electionType
        case mandate, circoscrizione, collegioPlurinominale, regione, stableSourceId, sourceUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        chamber = try container.decode(Chamber.self, forKey: .chamber)
        districtId = try container.decodeIfPresent(String.self, forKey: .districtId)
        party = try container.decode(String.self, forKey: .party)
        parliamentaryGroup = try container.decode(String.self, forKey: .parliamentaryGroup)
        committees = try container.decode([String].self, forKey: .committees)
        attendanceRate = try container.decodeIfPresent(Double.self, forKey: .attendanceRate)
        photoName = try container.decode(String.self, forKey: .photoName)
        provenance = try container.decodeIfPresent(DataProvenance.self, forKey: .provenance) ?? .sample
        legislature = try container.decodeIfPresent(String.self, forKey: .legislature)
        electionType = try container.decodeIfPresent(ElectionType.self, forKey: .electionType) ?? .sconosciuto
        mandate = try container.decodeIfPresent(MandateType.self, forKey: .mandate)
        circoscrizione = try container.decodeIfPresent(String.self, forKey: .circoscrizione)
        collegioPlurinominale = try container.decodeIfPresent(String.self, forKey: .collegioPlurinominale)
        regione = try container.decodeIfPresent(String.self, forKey: .regione)
        stableSourceId = try container.decodeIfPresent(String.self, forKey: .stableSourceId)
        sourceUrl = try container.decodeIfPresent(URL.self, forKey: .sourceUrl)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(chamber, forKey: .chamber)
        try container.encodeIfPresent(districtId, forKey: .districtId)
        try container.encode(party, forKey: .party)
        try container.encode(parliamentaryGroup, forKey: .parliamentaryGroup)
        try container.encode(committees, forKey: .committees)
        try container.encodeIfPresent(attendanceRate, forKey: .attendanceRate)
        try container.encode(photoName, forKey: .photoName)
        try container.encode(provenance, forKey: .provenance)
        try container.encodeIfPresent(legislature, forKey: .legislature)
        try container.encode(electionType, forKey: .electionType)
        try container.encodeIfPresent(mandate, forKey: .mandate)
        try container.encodeIfPresent(circoscrizione, forKey: .circoscrizione)
        try container.encodeIfPresent(collegioPlurinominale, forKey: .collegioPlurinominale)
        try container.encodeIfPresent(regione, forKey: .regione)
        try container.encodeIfPresent(stableSourceId, forKey: .stableSourceId)
        try container.encodeIfPresent(sourceUrl, forKey: .sourceUrl)
    }
}
