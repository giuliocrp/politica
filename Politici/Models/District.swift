//
//  District.swift
//  Politici
//

import Foundation
import MapKit

enum Chamber: String, Codable, CaseIterable, Hashable {
    case camera = "Camera"
    case senato = "Senato"
}

enum CollegioType: String, TolerantStringEnum, Hashable {
    case uninominale
    case plurinominale
    case sconosciuto

    static var unknownCase: CollegioType { .sconosciuto }
}

extension CollegioType: Codable {
    init(from decoder: Decoder) throws {
        self = try Self.decodeTolerant(from: decoder)
    }
}

/// A district's geometry may have multiple disjoint parts (e.g. a mainland
/// collegio that also includes a small offshore island — genuinely common
/// in the real ISTAT data: 56 of 147 shipping collegi are MultiPolygon, not
/// a hypothetical edge case; see docs/v2/03-boundaries-audit.md), and each
/// part may itself have interior holes (`MKPolygon.interiorPolygons`).
/// `MKPolygon` already models both natively, so districts are built
/// directly from `MKGeoJSONDecoder`'s output (see `GeoJSONLoader`) rather
/// than a hand-rolled coordinate representation.
struct District: Identifiable {
    let id: String
    let name: String
    let chamber: Chamber
    let polygons: [MKPolygon]
    let provenance: DataProvenance
    let collegioType: CollegioType
    /// NOTE: for the real ISTAT data this is NOT a geographic region despite
    /// the name — see docs/v2/03-boundaries-audit.md. Kept as a generic
    /// optional label rather than renamed, since the sample fixture's
    /// `region` values (and any future genuinely-regional source) still fit
    /// this shape.
    let region: String?
    let sourceName: String?

    /// Union bounding box across every polygon part, e.g. to fit a map
    /// camera around just this district, or as a cheap pre-filter before
    /// exact point-in-polygon testing (see `DistrictService.district(for:)`).
    var boundingMapRect: MKMapRect {
        polygons.reduce(MKMapRect.null) { $0.union($1.boundingMapRect) }
    }
}

/// `MKPolygon` isn't `Equatable`/`Hashable`, so identity is the district's
/// own `id` — two `District` values are equal iff they represent the same
/// collegio, regardless of geometry (which never changes for a given id).
extension District: Equatable, Hashable {
    static func == (lhs: District, rhs: District) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
