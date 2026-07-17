//
//  GeoJSONLoader.swift
//  Politici
//

import CoreLocation
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

/// Axis-aligned bounding box for a set of coordinates, used to size an initial
/// map camera region or fit a district's overlay on screen.
struct MapBounds {
    let northEast: CLLocationCoordinate2D
    let southWest: CLLocationCoordinate2D

    var region: MKCoordinateRegion {
        let center = CLLocationCoordinate2D(
            latitude: (northEast.latitude + southWest.latitude) / 2,
            longitude: (northEast.longitude + southWest.longitude) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(abs(northEast.latitude - southWest.latitude) * 1.3, 0.02),
            longitudeDelta: max(abs(northEast.longitude - southWest.longitude) * 1.3, 0.02)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}

enum GeoJSONLoader {
    /// Parses `districts.geojson` (a GeoJSON `FeatureCollection`) into domain `District` values.
    static func loadDistricts(
        resource: String = "districts",
        bundle: Bundle = .main
    ) throws -> [District] {
        let collection = try LocalJSONLoader.decode(
            DistrictFeatureCollection.self,
            fromResource: resource,
            withExtension: "geojson",
            bundle: bundle
        )
        return collection.features
    }

    /// Bounding box across every ring/point of the given districts, e.g. to fit an
    /// initial map camera around all constituencies at once.
    static func bounds(for districts: [District]) -> MapBounds? {
        let coordinates = districts.flatMap { $0.polygonRings.flatMap { $0 } }
        guard !coordinates.isEmpty else { return nil }

        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)

        guard let minLat = latitudes.min(), let maxLat = latitudes.max(),
              let minLon = longitudes.min(), let maxLon = longitudes.max() else {
            return nil
        }

        return MapBounds(
            northEast: CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon),
            southWest: CLLocationCoordinate2D(latitude: minLat, longitude: minLon)
        )
    }

    /// Bounding box for a single district's polygon.
    static func bounds(for district: District) -> MapBounds? {
        bounds(for: [district])
    }
}
