//
//  ComuniSchemaVersionTests.swift
//  PoliticiTests
//
//  Phase 30B — the schema bump crosses importer, validator, model and service
//  (docs/v4/30b-comuni-assignment.md), and the failure mode to design against
//  is a mismatched pair that degrades QUIETLY. Test spec 6: an unexpected
//  `schemaVersion` fails loudly, and there is no silent degradation path — a
//  table that cannot be loaded answers nothing at all rather than something
//  plausible.
//

import XCTest
@testable import Politici

final class ComuniSchemaVersionTests: XCTestCase {

    private func decode(_ json: String) throws -> ComuniFile {
        try JSONDecoder().decode(ComuniFile.self, from: Data(json.utf8))
    }

    private let validRecord = """
    {"name":"Firenze","province":"Firenze","lat":43.78082,"lon":11.24465,"camera":["90007"],"senato":["S90004"]}
    """

    func testCurrentSchemaVersionDecodes() throws {
        let file = try decode(#"{"schemaVersion":2,"comuni":[\#(validRecord)]}"#)
        XCTAssertEqual(file.schemaVersion, ComuniFile.expectedSchemaVersion)
        XCTAssertEqual(file.comuni.first?.camera, ["90007"])
    }

    /// The Phase 30 file. Its records have no published assignment at all, so
    /// reading it with this build could only invent one — it must fail first.
    func testPreviousSchemaVersionFailsLoudly() {
        let json = """
        {"schemaVersion":1,"comuni":[{"name":"Firenze","province":"Firenze","lat":43.78082,"lon":11.24465}]}
        """
        XCTAssertThrowsError(try decode(json)) { error in
            XCTAssertEqual(
                error as? ComuniFileError,
                .unsupportedSchemaVersion(found: 1, expected: 2)
            )
        }
    }

    /// A future file is refused just as firmly as an old one — the check is
    /// equality, not a floor, so a v3 file cannot be read as if it were v2.
    func testFutureSchemaVersionFailsLoudly() {
        XCTAssertThrowsError(try decode(#"{"schemaVersion":3,"comuni":[\#(validRecord)]}"#)) { error in
            XCTAssertEqual(
                error as? ComuniFileError,
                .unsupportedSchemaVersion(found: 3, expected: 2)
            )
        }
    }

    /// The assignment fields are non-optional, so even a correctly-versioned
    /// file that lost them fails to decode instead of yielding comuni with an
    /// empty assignment (which the UI would render as "not covered" — a wrong
    /// answer wearing an honest one's clothes).
    func testMissingAssignmentFieldsFailToDecode() {
        let json = """
        {"schemaVersion":2,"comuni":[{"name":"Firenze","province":"Firenze","lat":43.78082,"lon":11.24465}]}
        """
        XCTAssertThrowsError(try decode(json))
    }

    /// The service's half of the contract: when the table cannot be loaded at
    /// all, it reports the error and answers `none` to everything — it never
    /// degrades to a partial or approximate table.
    func testUnloadableTableAnswersNothingRatherThanSomething() {
        let service = ComuneService(resource: "comuni.nonexistent")
        XCTAssertNotNil(service.loadError)
        XCTAssertTrue(service.comuni.isEmpty)
        XCTAssertEqual(service.match(name: "Roma"), ComuneNameMatch.none)
        XCTAssertEqual(service.match(name: "Firenze"), ComuneNameMatch.none)
    }
}
