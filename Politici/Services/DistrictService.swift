//
//  DistrictService.swift
//  Politici
//

import CoreLocation
import Foundation
import MapKit

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

    /// Finds the district whose geometry contains `coordinate`.
    ///
    /// Real districts (e.g. ISTAT's 147 Camera collegi, several with
    /// dozens of MultiPolygon parts for small islands) are far more
    /// expensive to ray-cast than the old 5 sample rectangles, so this
    /// first narrows to districts whose cheap bounding-box actually
    /// contains the point before running exact point-in-polygon testing on
    /// just those candidates — typically one, occasionally a couple near a
    /// shared border.
    func district(for coordinate: CLLocationCoordinate2D) -> District? {
        let point = MKMapPoint(coordinate)
        let candidates = districts.filter { $0.boundingMapRect.contains(point) }
        return candidates.first { PointInPolygon.contains(coordinate, inAny: $0.polygons) }
    }
}
