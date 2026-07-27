//
//  Comune.swift
//  Politici
//

import CoreLocation
import Foundation

/// One Italian comune with a single interior point, decoded from
/// `comuni.json` — the offline geocoding table (v4 Phase 30 —
/// docs/v4/30-comuni-geocoding.md). A comune name resolves to this
/// `coordinate`, which the existing point-in-polygon path
/// (`DistrictService.district(for:chamber:)`) then turns into a collegio,
/// entirely offline.
///
/// `province` is the ISTAT provincia / città-metropolitana name
/// (`DEN_P_CM`). It is the homonym disambiguator: six comune names occur in
/// two provinces (`Castro` in Bergamo and Lecce, …), and `(name, province)`
/// is unique across all 7,904 comuni — so it also serves as the model's
/// `id`. `lat`/`lon` are the decoded storage; `coordinate` is the derived
/// `CLLocationCoordinate2D` (which is itself neither `Codable` nor
/// `Hashable`, hence the split).
struct Comune: Codable, Hashable, Identifiable {
    let name: String
    let province: String
    let lat: Double
    let lon: Double

    var id: String { "\(name)|\(province)" }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

/// Top-level shape of `comuni.json`: `{"schemaVersion":1,"comuni":[...]}`.
struct ComuniFile: Codable {
    let schemaVersion: Int
    let comuni: [Comune]
}
