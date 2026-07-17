//
//  DistrictService.swift
//  Politici
//

import CoreLocation
import Foundation

/// Loads `districts.geojson` once and answers district lookups, including
/// resolving a map coordinate to the district whose polygon contains it.
final class DistrictService {
    static let shared = DistrictService()

    private(set) var districts: [District] = []
    private(set) var loadError: Error?

    init(resource: String = "districts", bundle: Bundle = .main) {
        do {
            districts = try GeoJSONLoader.loadDistricts(resource: resource, bundle: bundle)
        } catch {
            loadError = error
            districts = []
        }
    }

    func allDistricts() -> [District] {
        districts
    }

    func district(withId id: String) -> District? {
        districts.first { $0.id == id }
    }

    /// Finds the district whose polygon contains `coordinate` via ray-casting.
    /// Returns `nil` if no district's exterior ring contains the point.
    func district(for coordinate: CLLocationCoordinate2D) -> District? {
        districts.first { district in
            PointInPolygon.contains(coordinate, in: district.exteriorCoordinates)
        }
    }
}
