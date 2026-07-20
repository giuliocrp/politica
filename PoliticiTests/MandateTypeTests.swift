//
//  MandateTypeTests.swift
//  PoliticiTests
//

import XCTest
@testable import Politici

/// Coverage for the Phase 17 Senato mandate category (see
/// docs/v3/17-senato-mandates.md): the three verbatim source raw values,
/// the tolerant decode fallback, nil-when-absent (Camera records omit the
/// key entirely), and the a-vita-only profile badge.
final class MandateTypeTests: XCTestCase {
    /// Minimal senator fixture; `mandateLine` is injected verbatim (including
    /// the trailing comma) or omitted entirely to model a Camera record.
    private func decodeRepresentative(mandateLine: String?) throws -> Representative {
        let json = """
        {
          "id": "TEST-SEN-001",
          "name": "Test Persona",
          "chamber": "Senato",
          \(mandateLine ?? "")
          "party": "Test",
          "parliamentaryGroup": "Test",
          "committees": [],
          "photoName": "person.crop.circle.fill"
        }
        """
        return try JSONDecoder().decode(Representative.self, from: Data(json.utf8))
    }

    func testVerbatimMandateRawValuesDecode() throws {
        let elettivo = try decodeRepresentative(mandateLine: #""mandate": "elettivo","#)
        XCTAssertEqual(elettivo.mandate, .elettivo)

        let aVita = try decodeRepresentative(
            mandateLine: #""mandate": "a vita, di nomina del Presidente della Repubblica","#
        )
        XCTAssertEqual(aVita.mandate, .nominaAVita)

        let emerito = try decodeRepresentative(
            mandateLine: #""mandate": "di diritto e a vita, Presidente emerito della Repubblica","#
        )
        XCTAssertEqual(emerito.mandate, .diDirittoEAVita)
    }

    func testUnknownMandateDecodesAsSconosciuto() throws {
        let representative = try decodeRepresentative(
            mandateLine: #""mandate": "categoria inventata mai vista","#
        )
        XCTAssertEqual(representative.mandate, .sconosciuto)
    }

    func testAbsentMandateDecodesAsNil() throws {
        let representative = try decodeRepresentative(mandateLine: nil)
        XCTAssertNil(representative.mandate)
    }

    func testProfileBadgeLabelIsOnlyForNominaAVita() {
        XCTAssertEqual(
            MandateType.nominaAVita.profileBadgeLabel,
            "A vita, di nomina del Presidente della Repubblica"
        )
        XCTAssertNil(MandateType.elettivo.profileBadgeLabel)
        XCTAssertNil(MandateType.diDirittoEAVita.profileBadgeLabel)
        XCTAssertNil(MandateType.sconosciuto.profileBadgeLabel)
    }
}
