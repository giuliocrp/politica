//
//  PointInPolygon.swift
//  Politici
//

import CoreLocation

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
}
