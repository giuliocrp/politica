//
//  PointInPolygonTests.swift
//  PoliticiTests
//

import CoreLocation
import XCTest
@testable import Politici

final class PointInPolygonTests: XCTestCase {
    /// A plain 10x10 square: lat/lon both range 0...10.
    private let square: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: 0, longitude: 0),
        CLLocationCoordinate2D(latitude: 0, longitude: 10),
        CLLocationCoordinate2D(latitude: 10, longitude: 10),
        CLLocationCoordinate2D(latitude: 10, longitude: 0)
    ]

    /// An L-shaped concave polygon: the full bottom half (lat 0...5, lon 0...10)
    /// plus the left half of the top (lat 5...10, lon 0...5). The upper-right
    /// quadrant (lat 5...10, lon 5...10) is a notch cut out of the bounding box.
    private let concaveL: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: 0, longitude: 0),
        CLLocationCoordinate2D(latitude: 0, longitude: 10),
        CLLocationCoordinate2D(latitude: 5, longitude: 10),
        CLLocationCoordinate2D(latitude: 5, longitude: 5),
        CLLocationCoordinate2D(latitude: 10, longitude: 5),
        CLLocationCoordinate2D(latitude: 10, longitude: 0)
    ]

    func testPointClearlyInsideSquareIsContained() {
        let point = CLLocationCoordinate2D(latitude: 5, longitude: 5)
        XCTAssertTrue(PointInPolygon.contains(point, in: square))
    }

    func testPointClearlyOutsideSquareIsNotContained() {
        let point = CLLocationCoordinate2D(latitude: 15, longitude: 15)
        XCTAssertFalse(PointInPolygon.contains(point, in: square))
    }

    func testPointOnEdgeOfSquareIsContained() {
        // (lat: 5, lon: 0) sits exactly on the left edge of the square.
        let point = CLLocationCoordinate2D(latitude: 5, longitude: 0)
        XCTAssertTrue(PointInPolygon.contains(point, in: square))
    }

    func testPointAtVertexOfSquareIsContained() {
        let point = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        XCTAssertTrue(PointInPolygon.contains(point, in: square))
    }

    func testPointInNotchOfConcavePolygonIsNotContained() {
        // (lat: 8, lon: 8) falls inside the L's missing upper-right quadrant.
        let point = CLLocationCoordinate2D(latitude: 8, longitude: 8)
        XCTAssertFalse(PointInPolygon.contains(point, in: concaveL))
    }

    func testPointInSolidArmOfConcavePolygonIsContained() {
        // (lat: 8, lon: 2) falls inside the L's left/top arm.
        let point = CLLocationCoordinate2D(latitude: 8, longitude: 2)
        XCTAssertTrue(PointInPolygon.contains(point, in: concaveL))
    }

    func testDegeneratePolygonNeverContainsAPoint() {
        let point = CLLocationCoordinate2D(latitude: 5, longitude: 5)
        let line: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 10, longitude: 10)
        ]
        XCTAssertFalse(PointInPolygon.contains(point, in: line))
        XCTAssertFalse(PointInPolygon.contains(point, in: []))
    }
}
