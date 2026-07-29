//
//  ComuneGeocodingIntegrationTests.swift
//  PoliticiTests
//
//  Phase 30 — end-to-end offline geocoding (docs/v4/30-comuni-geocoding.md),
//  test spec 4; Phase 30B (docs/v4/30b-comuni-assignment.md) test spec 5.
//
//  Since Phase 30B this file pins the **COORDINATE path** specifically: a
//  coordinate (from CLGeocoder, a map tap, or — as here — a comune's bundled
//  interior point) resolved through DistrictService's point-in-polygon into
//  one collegio per chamber. Its behaviour is deliberately UNCHANGED by
//  Phase 30B; the comune-NAME path moved to the published assignment and is
//  covered by ComuneAssignmentTests.
//
//  Every (coordinate → collegio id) pair below was verified against the ISTAT
//  source in the Phase 30 report BEFORE being hardcoded: each comune's shipped
//  comuni.json interior point was resolved against the shipped collegi
//  polygons, and the Camera result cross-checked against the comune's own
//  source CU20_COD (docs/v4/30-comuni-geocoding.md §"Spot verification").
//  Roma/Milano/Napoli/Torino/Genova are split comuni: the coordinate lands in
//  the collegio containing the comune's largest territorial part, which is
//  exactly why a NAME query no longer answers this way.
//

import XCTest
@testable import Politici

final class ComuneGeocodingIntegrationTests: XCTestCase {
    private let comuni = ComuneService()
    private let districts = DistrictService()

    /// (comune, Camera uninominale id containing its interior point, Senato one).
    private let verifiedPairs: [(name: String, camera: String, senato: String)] = [
        ("Roma", "120105", "S120004"),
        ("Milano", "30108", "S30003"),
        ("Napoli", "150102", "S150004"),
        ("Torino", "10102", "S10001"),
        ("Firenze", "90007", "S90004"),
        ("Bologna", "80006", "S80003"),
        ("Bari", "160005", "S160003"),
        ("Genova", "70002", "S70001"),
        ("Venezia", "50101", "S50001"),
        ("Aosta", "20001", "S20001"),
        ("Trento", "40001", "S40001"),
        ("Cagliari", "200001", "S200001"),
        ("Bolzano", "40003", "S40004"),
        ("Perugia", "100002", "S100001"),
    ]

    func testVerifiedComuneToCollegioPairs() {
        XCTAssertNil(comuni.loadError)
        XCTAssertNil(districts.loadError)
        XCTAssertGreaterThanOrEqual(verifiedPairs.count, 10)

        for pair in verifiedPairs {
            let matches = comuni.comuni(matching: pair.name)
            XCTAssertEqual(matches.count, 1, "\(pair.name): atteso un solo comune (non omonimo)")
            guard let comune = matches.first else { continue }

            let camera = districts.district(for: comune.coordinate, chamber: .camera)
            XCTAssertEqual(camera?.id, pair.camera, "\(pair.name) → Camera")

            let senato = districts.district(for: comune.coordinate, chamber: .senato)
            XCTAssertEqual(senato?.id, pair.senato, "\(pair.name) → Senato")
        }
    }

    /// The dual-chamber coordinate entry point (`districts(containing:)`)
    /// resolves a coordinate to at most one collegio per chamber — the path
    /// AddressSearchView still uses for street addresses and autocomplete
    /// results.
    func testDualChamberResolutionForAComuneCoordinate() {
        guard let firenze = comuni.comuni(matching: "Firenze").first else {
            return XCTFail("Firenze non trovata nella tabella comuni")
        }
        let matches = districts.districts(containing: firenze.coordinate)
        XCTAssertEqual(matches[.camera]?.id, "90007")
        XCTAssertEqual(matches[.senato]?.id, "S90004")
    }

    /// The two paths are **deliberately distinct** (Phase 30B test spec 5),
    /// and this pins the difference rather than leaving it implicit.
    ///
    /// `Carbonara di Nola` is the worked example: its interior point falls on
    /// the wrong side of a 1000 m-simplified boundary, so the COORDINATE path
    /// answers with the neighbouring collegio `150204` — measured and
    /// disclosed by Phase 30, and unchanged here. The NAME path answers
    /// `150106`, which is what ISTAT publishes for that comune. Neither is a
    /// bug in the other: one says "which collegio contains this point in our
    /// simplified geometry", the other "which collegio does the publisher
    /// assign this comune to".
    func testCoordinatePathAndPublishedAssignmentAreDeliberatelyDistinct() {
        guard case .one(let comune) = comuni.match(name: "Carbonara di Nola") else {
            return XCTFail("Carbonara di Nola non trovata nella tabella comuni")
        }

        // Coordinate path — unchanged from Phase 30, including its artefact.
        XCTAssertEqual(districts.district(for: comune.coordinate, chamber: .camera)?.id, "150204")

        // Name path — the published assignment.
        XCTAssertEqual(districts.districts(assignedTo: comune)[.camera]?.map(\.id), ["150106"])

        // Isole Tremiti: the coordinate path has no answer at all (its island
        // is dropped by the simplification) and honestly returns nil, while
        // the published assignment does have one. The nil is not patched.
        guard case .one(let tremiti) = comuni.match(name: "Isole Tremiti") else {
            return XCTFail("Isole Tremiti non trovata nella tabella comuni")
        }
        XCTAssertNil(districts.district(for: tremiti.coordinate, chamber: .camera))
        XCTAssertEqual(districts.districts(assignedTo: tremiti)[.camera]?.map(\.id), ["160002"])
    }
}
