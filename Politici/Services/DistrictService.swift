//
//  DistrictService.swift
//  Politici
//

import CoreLocation
import Foundation
import MapKit

/// Loads one or more boundary resources (by default `districts.geojson`
/// for Camera + `districts_senato.geojson` for Senato — Phase 16) once and
/// answers district lookups, bucketed by each feature's own `chamber`
/// property rather than by which file it came from — a resource can
/// legitimately mix chambers (the `districts.sample` test fixture does,
/// 3 Camera + 2 Senato in one file) and this service buckets correctly
/// either way.
final class DistrictService {
    static let shared = DistrictService()

    /// Every district across every loaded resource, combined — for global
    /// lookups (`district(withId:)`) and combined totals (e.g. HomeView's
    /// "221 collegi uninominali" stat). Chamber-scoped call sites should
    /// prefer `allDistricts(chamber:)`/`district(for:chamber:)` instead of
    /// filtering this themselves.
    private(set) var districts: [District] = []
    private var districtsByChamber: [Chamber: [District]] = [:]
    private(set) var loadError: Error?

    init(resources: [String] = ["districts", "districts_senato"], bundle: Bundle = .main) {
        var loaded: [District] = []
        var firstError: Error?
        for resource in resources {
            do {
                loaded += try GeoJSONLoader.loadDistricts(resource: resource, bundle: bundle)
            } catch {
                firstError = firstError ?? error
            }
        }
        districts = loaded
        loadError = firstError
        districtsByChamber = Dictionary(grouping: loaded, by: \.chamber)

        #if DEBUG
        assert(loadError == nil, "DistrictService failed to load one or more resources (\(resources)): \(String(describing: loadError))")
        #endif
    }

    /// Every district across every loaded resource, regardless of chamber.
    func allDistricts() -> [District] {
        districts
    }

    /// Every district for one chamber only — e.g. what `MapView`/
    /// `CollegiListView`'s chamber picker renders.
    func allDistricts(chamber: Chamber) -> [District] {
        districtsByChamber[chamber] ?? []
    }

    /// Looks up a district by id regardless of chamber — safe because
    /// Senato ids are unconditionally `"S"`-prefixed at import time, so no
    /// Camera/Senato id ever collides (verified: 147 + 74 = 221 unique ids
    /// — see docs/v3/16-senato-boundaries.md).
    func district(withId id: String) -> District? {
        districts.first { $0.id == id }
    }

    /// Finds the district of the given `chamber` whose geometry contains
    /// `coordinate`.
    ///
    /// Real districts (e.g. ISTAT's 147 Camera / 74 Senato collegi,
    /// several with dozens of MultiPolygon parts for small islands) are far
    /// more expensive to ray-cast than the old 5 sample rectangles, so this
    /// first narrows to districts whose cheap bounding-box actually
    /// contains the point before running exact point-in-polygon testing on
    /// just those candidates — typically one, occasionally a couple near a
    /// shared border.
    func district(for coordinate: CLLocationCoordinate2D, chamber: Chamber) -> District? {
        let point = MKMapPoint(coordinate)
        let candidates = allDistricts(chamber: chamber).filter { $0.boundingMapRect.contains(point) }
        return candidates.first { PointInPolygon.contains(coordinate, inAny: $0.polygons) }
    }

    /// Resolves `coordinate` against every chamber independently, returning
    /// at most one match per chamber — the address-search dual-chamber
    /// result ("Collegio Camera: …" / "Collegio Senato: …"), rather than
    /// silently preferring one chamber over the other.
    func districts(containing coordinate: CLLocationCoordinate2D) -> [Chamber: District] {
        var matches: [Chamber: District] = [:]
        for chamber in Chamber.allCases {
            if let match = district(for: coordinate, chamber: chamber) {
                matches[chamber] = match
            }
        }
        return matches
    }
}
