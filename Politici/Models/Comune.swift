//
//  Comune.swift
//  Politici
//

import CoreLocation
import Foundation

/// One Italian comune, decoded from `comuni.json` — the offline comuni table
/// (v4 Phase 30 — docs/v4/30-comuni-geocoding.md; v4 Phase 30B —
/// docs/v4/30b-comuni-assignment.md).
///
/// It carries two independent things, feeding two deliberately distinct
/// resolution paths:
///
/// * `camera` / `senato` — **the collegio assignment ISTAT itself publishes**
///   for this comune (`CU20_COD` / `SU20_COD`). This is what a comune-**name**
///   query answers with: a sourced fact, not a value derived from simplified
///   geometry. It is legitimately multi-valued — six comuni (Roma, Milano,
///   Napoli, Torino, Palermo, Genova) genuinely span more than one uninominale
///   collegio — so it is always an array, and no single member of it may ever
///   be presented as *the* collegio of the comune.
/// * `lat` / `lon` — one interior point, retained for the **coordinate** path
///   (a `CLGeocoder` result, a map tap, any arbitrary point), which still
///   resolves by point-in-polygon through `DistrictService`. That path is
///   unchanged from Phase 30 and can legitimately disagree with the published
///   assignment near a simplified boundary; the two paths answer different
///   questions.
///
/// `province` is the ISTAT provincia / città-metropolitana name
/// (`DEN_P_CM`). It is the homonym disambiguator: six comune names occur in
/// two provinces (`Castro` in Bergamo and Lecce, …), and `(name, province)`
/// is unique across all 7,904 comuni — so it also serves as the model's
/// `id`. `lat`/`lon` are the decoded storage; `coordinate` is the derived
/// `CLLocationCoordinate2D` (which is itself neither `Codable` nor
/// `Hashable`, hence the split).
nonisolated struct Comune: Codable, Hashable, Identifiable {
    let name: String
    let province: String
    let lat: Double
    let lon: Double
    /// Published Camera-uninominale collegio ids, sorted. Never empty.
    let camera: [String]
    /// Published Senato-uninominale collegio ids, sorted, `"S"`-prefixed to
    /// match the shipped district ids. Never empty.
    let senato: [String]

    var id: String { "\(name)|\(province)" }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// The published collegio ids for one chamber — one or many, never a
    /// single arbitrary pick out of many.
    func collegioIds(for chamber: Chamber) -> [String] {
        switch chamber {
        case .camera: camera
        case .senato: senato
        }
    }

    /// True when the source assigns this comune to more than one uninominale
    /// collegio in either chamber, i.e. when no single collegio is *the*
    /// answer for the whole comune.
    var spansMultipleCollegi: Bool {
        camera.count > 1 || senato.count > 1
    }
}

/// Raised when `comuni.json` carries a `schemaVersion` this build does not
/// implement. Deliberately fatal to the load rather than tolerated: the
/// Phase 30B schema bump crosses importer, validator, model and service, and
/// the failure mode to design against is a mismatched pair that *degrades
/// quietly* — a v1 file read by a v2 build would otherwise have to invent an
/// empty published assignment, which is exactly the fabrication standing
/// constraint #4 forbids. `ComuneService` surfaces it as `loadError` with a
/// console warning and answers nothing, rather than answering wrongly.
nonisolated enum ComuniFileError: Error, Equatable {
    case unsupportedSchemaVersion(found: Int, expected: Int)
}

/// Top-level shape of `comuni.json`: `{"schemaVersion":2,"comuni":[...]}`.
nonisolated struct ComuniFile: Codable {
    /// The only version this build can read. Kept in lockstep with
    /// `SCHEMA_VERSION` in `tools/import_comuni.py` and
    /// `COMUNI_SCHEMA_VERSION` in `tools/validate_data.py`.
    static let expectedSchemaVersion = 2

    let schemaVersion: Int
    let comuni: [Comune]

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case comuni
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.expectedSchemaVersion else {
            throw ComuniFileError.unsupportedSchemaVersion(
                found: schemaVersion,
                expected: Self.expectedSchemaVersion
            )
        }
        comuni = try container.decode([Comune].self, forKey: .comuni)
    }
}
