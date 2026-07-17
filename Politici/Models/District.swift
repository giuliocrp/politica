//
//  District.swift
//  Politici
//

import CoreLocation
import Foundation

enum Chamber: String, Codable, CaseIterable, Hashable {
    case camera = "Camera"
    case senato = "Senato"
}

struct Coordinate: Codable, Hashable {
    let latitude: Double
    let longitude: Double

    var clLocationCoordinate2D: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
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

struct District: Identifiable, Hashable {
    let id: String
    let name: String
    let chamber: Chamber
    /// GeoJSON polygon rings: first ring is the exterior boundary, any further rings are holes.
    let polygonRings: [[Coordinate]]
    let provenance: DataProvenance
    let collegioType: CollegioType
    let region: String?
    let sourceName: String?

    var exteriorCoordinates: [CLLocationCoordinate2D] {
        polygonRings.first?.map(\.clLocationCoordinate2D) ?? []
    }

    var centroid: CLLocationCoordinate2D {
        let coordinates = exteriorCoordinates
        guard !coordinates.isEmpty else {
            return CLLocationCoordinate2D(latitude: 41.9028, longitude: 12.4964)
        }
        let latitude = coordinates.map(\.latitude).reduce(0, +) / Double(coordinates.count)
        let longitude = coordinates.map(\.longitude).reduce(0, +) / Double(coordinates.count)
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Decodes directly from a GeoJSON `Feature` object (RFC 7946) with a `Polygon` geometry.
extension District: Decodable {
    private enum FeatureKeys: String, CodingKey {
        case properties
        case geometry
    }

    private enum PropertyKeys: String, CodingKey {
        case id
        case name
        case chamber
        case provenance
        case collegioType
        case region
        case sourceName
    }

    private enum GeometryKeys: String, CodingKey {
        case type
        case coordinates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FeatureKeys.self)

        let properties = try container.nestedContainer(keyedBy: PropertyKeys.self, forKey: .properties)
        id = try properties.decode(String.self, forKey: .id)
        name = try properties.decode(String.self, forKey: .name)
        chamber = try properties.decode(Chamber.self, forKey: .chamber)
        provenance = try properties.decodeIfPresent(DataProvenance.self, forKey: .provenance) ?? .sample
        collegioType = try properties.decodeIfPresent(CollegioType.self, forKey: .collegioType) ?? .sconosciuto
        region = try properties.decodeIfPresent(String.self, forKey: .region)
        sourceName = try properties.decodeIfPresent(String.self, forKey: .sourceName)

        let geometry = try container.nestedContainer(keyedBy: GeometryKeys.self, forKey: .geometry)
        // GeoJSON Polygon coordinates: [ring][pointIndex][lon, lat]
        let rawRings = try geometry.decode([[[Double]]].self, forKey: .coordinates)
        polygonRings = rawRings.map { ring in
            ring.map { point in
                Coordinate(latitude: point[1], longitude: point[0])
            }
        }
    }
}

/// Top-level wrapper matching a GeoJSON `FeatureCollection`.
struct DistrictFeatureCollection: Decodable {
    let features: [District]
}
