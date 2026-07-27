//
//  ComuneGeocodingIntegrationTests.swift
//  PoliticiTests
//
//  Phase 30 — end-to-end offline geocoding (docs/v4/30-comuni-geocoding.md),
//  test spec 4: a comune name resolves, through the bundled comuni table
//  (ComuneService) and the point-in-polygon path (DistrictService), to its
//  real Camera and Senato uninominale collegio ids.
//
//  Every (comune → collegio id) pair below was verified against the ISTAT
//  source in the report BEFORE being hardcoded here: each comune's shipped
//  comuni.json interior point was resolved against the shipped collegi
//  polygons, and the Camera result cross-checked against the comune's own
//  source CU20_COD (docs/v4/30-comuni-geocoding.md §"Spot verification").
//  Roma/Milano/Napoli/Torino/Genova are split comuni: they resolve to the
//  collegio containing the comune's largest territorial part (documented).
//

import XCTest
@testable import Politici

final class ComuneGeocodingIntegrationTests: XCTestCase {
    private let comuni = ComuneService()
    private let districts = DistrictService()

    /// (comune, expected Camera uninominale id, expected Senato uninominale id).
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

    /// The dual-chamber address-search entry point (`districts(containing:)`)
    /// resolves a comune coordinate to one collegio per chamber, the same path
    /// AddressSearchView uses.
    func testDualChamberResolutionForAComuneCoordinate() {
        guard let firenze = comuni.comuni(matching: "Firenze").first else {
            return XCTFail("Firenze non trovata nella tabella comuni")
        }
        let matches = districts.districts(containing: firenze.coordinate)
        XCTAssertEqual(matches[.camera]?.id, "90007")
        XCTAssertEqual(matches[.senato]?.id, "S90004")
    }
}
