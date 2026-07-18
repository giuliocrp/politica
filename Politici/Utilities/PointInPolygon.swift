//
//  PointInPolygon.swift
//  Politici
//

import CoreLocation
import MapKit

enum PointInPolygon {
    /// Ray-casting (even-odd rule) point-in-polygon test.
    ///
    /// `polygon` is a ring of coordinates (open or closed — the last point does not
    /// need to repeat the first). Longitude is treated as x and latitude as y.
    static func contains(_ point: CLLocationCoordinate2D, in polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }

        var isInside = false
        var j = polygon.count - 1

        for i in 0..<polygon.count {
            let vertexI = polygon[i]
            let vertexJ = polygon[j]

            let straddles = (vertexI.latitude > point.latitude) != (vertexJ.latitude > point.latitude)
            if straddles {
                let edgeLongitudeAtPointLatitude = (vertexJ.longitude - vertexI.longitude)
                    * (point.latitude - vertexI.latitude)
                    / (vertexJ.latitude - vertexI.latitude)
                    + vertexI.longitude

                if point.longitude < edgeLongitudeAtPointLatitude {
                    isInside.toggle()
                }
            }

            j = i
        }

        return isInside
    }

    /// Tests `point` against a single `MKPolygon`'s exterior ring, excluding
    /// any interior rings (holes) it may have — a point inside a hole is
    /// not considered inside the polygon, even though it's inside the
    /// exterior ring.
    static func contains(_ point: CLLocationCoordinate2D, in polygon: MKPolygon) -> Bool {
        guard contains(point, in: polygon.exteriorRingCoordinates) else { return false }
        for hole in polygon.interiorPolygons ?? [] {
            if contains(point, in: hole.exteriorRingCoordinates) {
                return false
            }
        }
        return true
    }

    /// Tests `point` against every part of a MultiPolygon-safe district
    /// geometry (see `District.polygons`) — true if it falls inside *any*
    /// part (accounting for each part's own interior holes).
    static func contains(_ point: CLLocationCoordinate2D, inAny polygons: [MKPolygon]) -> Bool {
        polygons.contains { contains(point, in: $0) }
    }
}

extension MKPolygon {
    /// The polygon's own boundary ring as plain coordinates, for use with
    /// `PointInPolygon`'s ray-casting test. Does not include interior rings
    /// (holes) — see `interiorPolygons`.
    var exteriorRingCoordinates: [CLLocationCoordinate2D] {
        var coordinates = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coordinates, range: NSRange(location: 0, length: pointCount))
        return coordinates
    }
}
