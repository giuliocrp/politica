//
//  GeoJSONLoader.swift
//  Politici
//

import Foundation
import MapKit

/// Shared error type for every local (bundled) data-loading service.
enum DataLoadingError: LocalizedError {
    case resourceNotFound(String)
    case decodingFailed(String, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .resourceNotFound(let name):
            return "Impossibile trovare \(name) nel bundle dell'app."
        case .decodingFailed(let name, let underlying):
            return "Impossibile decodificare \(name): \(underlying.localizedDescription)"
        }
    }
}

/// Small shared helper so each service doesn't repeat its own
/// "find resource → read Data → decode" boilerplate.
enum LocalJSONLoader {
    static func decode<T: Decodable>(
        _ type: T.Type,
        fromResource resource: String,
        withExtension ext: String = "json",
        bundle: Bundle = .main
    ) throws -> T {
        guard let url = bundle.url(forResource: resource, withExtension: ext) else {
            throw DataLoadingError.resourceNotFound("\(resource).\(ext)")
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as DataLoadingError {
            throw error
        } catch {
            throw DataLoadingError.decodingFailed("\(resource).\(ext)", underlying: error)
        }
    }
}

/// A district's `properties` object, decoded independently of its geometry
/// (which `MKGeoJSONDecoder` parses natively into `MKPolygon` — see
/// `GeoJSONLoader.loadDistricts`).
private struct DistrictProperties: Decodable {
    let id: String
    let name: String
    let chamber: Chamber
    let provenance: DataProvenance?
    let collegioType: CollegioType?
    let circoscrizione: String?
    let subCode: String?
    let sourceName: String?
}

/// Bounding box for a set of districts (or a single one), used to size an
/// initial map camera region.
struct MapBounds {
    let mapRect: MKMapRect

    var region: MKCoordinateRegion {
        let base = MKCoordinateRegion(mapRect)
        return MKCoordinateRegion(
            center: base.center,
            span: MKCoordinateSpan(
                latitudeDelta: max(base.span.latitudeDelta * 1.3, 0.02),
                longitudeDelta: max(base.span.longitudeDelta * 1.3, 0.02)
            )
        )
    }
}

enum GeoJSONLoader {
    /// Parses `districts.geojson` (a GeoJSON `FeatureCollection`) into
    /// domain `District` values, using `MKGeoJSONDecoder` for the geometry
    /// (native `MKPolygon`/`MultiPolygon`/interior-ring support) and a
    /// small `Decodable` struct for each feature's `properties`.
    static func loadDistricts(
        resource: String = "districts",
        bundle: Bundle = .main
    ) throws -> [District] {
        guard let url = bundle.url(forResource: resource, withExtension: "geojson") else {
            throw DataLoadingError.resourceNotFound("\(resource).geojson")
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw DataLoadingError.decodingFailed("\(resource).geojson", underlying: error)
        }

        do {
            let objects = try MKGeoJSONDecoder().decode(data)
            let features = objects.compactMap { $0 as? MKGeoJSONFeature }
            return try features.map { try makeDistrict(from: $0, resource: resource) }
        } catch let error as DataLoadingError {
            throw error
        } catch {
            throw DataLoadingError.decodingFailed("\(resource).geojson", underlying: error)
        }
    }

    private static func makeDistrict(from feature: MKGeoJSONFeature, resource: String) throws -> District {
        guard let propertiesData = feature.properties else {
            throw DataLoadingError.decodingFailed(
                "\(resource).geojson",
                underlying: DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: [], debugDescription: "feature has no properties")
                )
            )
        }

        let properties: DistrictProperties
        do {
            properties = try JSONDecoder().decode(DistrictProperties.self, from: propertiesData)
        } catch {
            throw DataLoadingError.decodingFailed("\(resource).geojson", underlying: error)
        }

        // MKGeoJSONDecoder represents a GeoJSON "Polygon" geometry as a
        // single MKPolygon, but a "MultiPolygon" as one MKMultiPolygon
        // wrapping its parts — NOT as multiple MKPolygon entries directly
        // in `feature.geometry`. Both must be unwrapped to get every part.
        let polygons: [MKPolygon] = feature.geometry.flatMap { shape -> [MKPolygon] in
            if let polygon = shape as? MKPolygon {
                return [polygon]
            } else if let multiPolygon = shape as? MKMultiPolygon {
                return multiPolygon.polygons
            } else {
                return []
            }
        }
        guard !polygons.isEmpty else {
            throw DataLoadingError.decodingFailed(
                "\(resource).geojson",
                underlying: DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: [], debugDescription: "feature \(properties.id) has no Polygon/MultiPolygon geometry")
                )
            )
        }

        return District(
            id: properties.id,
            name: properties.name,
            chamber: properties.chamber,
            polygons: polygons,
            provenance: properties.provenance ?? .sample,
            collegioType: properties.collegioType ?? .sconosciuto,
            circoscrizione: properties.circoscrizione,
            subCode: properties.subCode,
            sourceName: properties.sourceName
        )
    }

    /// Bounding box across every polygon part of every given district, e.g.
    /// to fit an initial map camera around all constituencies at once.
    static func bounds(for districts: [District]) -> MapBounds? {
        guard !districts.isEmpty else { return nil }
        let rect = districts.reduce(MKMapRect.null) { $0.union($1.boundingMapRect) }
        guard !rect.isNull else { return nil }
        return MapBounds(mapRect: rect)
    }

    /// Bounding box for a single district's polygon(s).
    static func bounds(for district: District) -> MapBounds? {
        bounds(for: [district])
    }
}
