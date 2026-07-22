//
//  DistrictService.swift
//  Politici
//

import CoreLocation
import Foundation
import MapKit

/// Loads one or more boundary resources (by default the four shipping files:
/// `districts.geojson` + `districts_senato.geojson` uninominali — Phase 16 —
/// and `districts_plurinominali_camera.geojson` +
/// `districts_plurinominali_senato.geojson` — Phase 25) once and answers
/// district lookups, bucketed by each feature's own `chamber` AND
/// `collegioType` properties rather than by which file it came from — a
/// resource can legitimately mix chambers/types (the `districts.sample`
/// fixture mixes chambers) and this service buckets correctly either way.
final class DistrictService {
    static let shared = DistrictService()

    /// A (chamber, collegioType) bucket key — the map's collegio-type
    /// selector and `CollegiListView`'s type filter each render exactly one
    /// bucket at a time (mutually exclusive overlay sets, Phase 25).
    private struct Bucket: Hashable {
        let chamber: Chamber
        let collegioType: CollegioType
    }

    /// Every district across every loaded resource, combined — for global
    /// lookups (`district(withId:)`) and combined totals. Chamber/type-scoped
    /// call sites should prefer the scoped accessors below instead of
    /// filtering this themselves.
    private(set) var districts: [District] = []
    private var districtsByChamber: [Chamber: [District]] = [:]
    private var districtsByBucket: [Bucket: [District]] = [:]
    private(set) var loadError: Error?

    init(
        resources: [String] = [
            "districts", "districts_senato",
            "districts_plurinominali_camera", "districts_plurinominali_senato",
        ],
        bundle: Bundle = .main
    ) {
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
        districtsByBucket = Dictionary(grouping: loaded) {
            Bucket(chamber: $0.chamber, collegioType: $0.collegioType)
        }

        #if DEBUG
        assert(loadError == nil, "DistrictService failed to load one or more resources (\(resources)): \(String(describing: loadError))")
        #endif
    }

    /// Every district across every loaded resource, regardless of chamber/type.
    func allDistricts() -> [District] {
        districts
    }

    /// Every district of one collegio type across both chambers — e.g.
    /// HomeView's "collegi uninominali" headline count (221 = 147 + 74).
    func allDistricts(collegioType: CollegioType) -> [District] {
        districts.filter { $0.collegioType == collegioType }
    }

    /// Every district for one chamber only, regardless of type.
    func allDistricts(chamber: Chamber) -> [District] {
        districtsByChamber[chamber] ?? []
    }

    /// The one mutually-exclusive overlay set the map/list renders: a single
    /// chamber's collegi of a single type (e.g. Camera uninominali, or Senato
    /// plurinominali).
    func allDistricts(chamber: Chamber, collegioType: CollegioType) -> [District] {
        districtsByBucket[Bucket(chamber: chamber, collegioType: collegioType)] ?? []
    }

    /// Looks up a district by id regardless of chamber/type — safe because
    /// every file uses an unconditional, non-overlapping id prefix (bare
    /// numeric Camera uninominale, "S"/"CP"/"SP"), verified collision-free:
    /// 147 + 74 + 49 + 26 = 296 unique ids (see the GO-PLURI probe and
    /// docs/v4/25-plurinominale-geography.md).
    func district(withId id: String) -> District? {
        districts.first { $0.id == id }
    }

    /// Finds the district of the given `chamber` and `collegioType` whose
    /// geometry contains `coordinate` — the same coordinate resolves to one
    /// district per (chamber, type) overlay set (a uninominale collegio and
    /// the plurinominale collegio that contains it are different features in
    /// different files).
    ///
    /// Real districts (several with dozens of MultiPolygon island parts) are
    /// expensive to ray-cast, so this first narrows to districts whose cheap
    /// bounding-box actually contains the point before running exact
    /// point-in-polygon testing on just those candidates.
    func district(
        for coordinate: CLLocationCoordinate2D,
        chamber: Chamber,
        collegioType: CollegioType
    ) -> District? {
        let point = MKMapPoint(coordinate)
        let candidates = allDistricts(chamber: chamber, collegioType: collegioType)
            .filter { $0.boundingMapRect.contains(point) }
        return candidates.first { PointInPolygon.contains(coordinate, inAny: $0.polygons) }
    }

    /// Uninominale convenience — the historical `district(for:chamber:)`
    /// meaning (the collegio uninominale a coordinate falls in), kept so the
    /// address-search dual-chamber result and existing tests read unchanged.
    func district(for coordinate: CLLocationCoordinate2D, chamber: Chamber) -> District? {
        district(for: coordinate, chamber: chamber, collegioType: .uninominale)
    }

    /// Resolves `coordinate` against every chamber's UNINOMINALE overlay
    /// independently, returning at most one match per chamber — the
    /// address-search dual-chamber result ("Collegio Camera: …" / "Collegio
    /// Senato: …"). Deliberately uninominale-scoped: the address search
    /// answers "which collegio directly elects a representative here", which
    /// is the uninominale one.
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
