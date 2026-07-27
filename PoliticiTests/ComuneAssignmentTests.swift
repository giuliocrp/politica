//
//  ComuneAssignmentTests.swift
//  PoliticiTests
//
//  Phase 30B — the comune-NAME path answers with the collegio assignment
//  ISTAT itself publishes (docs/v4/30b-comuni-assignment.md), test specs 3
//  and 4: the corrected comuni, the previously-unresolved comuni that now
//  answer, a sample of unchanged ones, the multi-collegio comuni that must
//  return every collegio and never one, the homonym chooser, and the unknown
//  name that stays nil.
//
//  Every expected id below was RE-DERIVED FROM THE SOURCE before being
//  hardcoded here — printed by tools/probes/probe_comuni_assignment.py's
//  "test-expectation re-derivation" section straight off UT_Collegi2020's
//  CU20_COD/SU20_COD, and quoted in the report — never read back off the
//  implementation (Phase 25 precedent). Split comuni no longer have a single
//  expected id, which is exactly why the Phase 30 pairs are re-derived as
//  SETS here.
//

import XCTest
@testable import Politici

final class ComuneAssignmentTests: XCTestCase {
    private let comuni = ComuneService()
    private let districts = DistrictService()

    /// (comune, published Camera ids, published Senato ids) — the same 14
    /// comuni Phase 30 verified, now carrying the source's full assignment
    /// rather than a single largest-part result.
    private let verifiedAssignments: [(name: String, camera: [String], senato: [String])] = [
        ("Roma", ["120101", "120102", "120103", "120104", "120105", "120106", "120107"],
         ["S120002", "S120003", "S120004"]),
        ("Milano", ["30107", "30108", "30109"], ["S30003", "S30004"]),
        ("Napoli", ["150102", "150103"], ["S150004"]),
        ("Torino", ["10101", "10102"], ["S10001"]),
        ("Firenze", ["90007"], ["S90004"]),
        ("Bologna", ["80006"], ["S80003"]),
        ("Bari", ["160005"], ["S160003"]),
        ("Genova", ["70002", "70003"], ["S70001", "S70002"]),
        ("Venezia", ["50101"], ["S50001"]),
        ("Aosta", ["20001"], ["S20001"]),
        ("Trento", ["40001"], ["S40001"]),
        ("Cagliari", ["200001"], ["S200001"]),
        ("Bolzano", ["40003"], ["S40004"]),
        ("Perugia", ["100002"], ["S100001"]),
    ]

    private func comune(_ name: String, file: StaticString = #filePath, line: UInt = #line) -> Comune? {
        guard case .one(let comune) = comuni.match(name: name) else {
            XCTFail("\(name): atteso un solo comune", file: file, line: line)
            return nil
        }
        return comune
    }

    // MARK: - The published assignment resolves end-to-end

    func testVerifiedComuneAssignmentsResolveToShippedCollegi() {
        XCTAssertNil(comuni.loadError)
        XCTAssertNil(districts.loadError)
        XCTAssertGreaterThanOrEqual(verifiedAssignments.count, 10)

        for expected in verifiedAssignments {
            guard let comune = comune(expected.name) else { continue }
            XCTAssertEqual(comune.camera, expected.camera, "\(expected.name) → Camera")
            XCTAssertEqual(comune.senato, expected.senato, "\(expected.name) → Senato")

            // …and every published id is a collegio the app can actually open.
            let resolved = districts.districts(assignedTo: comune)
            XCTAssertEqual(resolved[.camera]?.map(\.id), expected.camera, "\(expected.name) → Camera districts")
            XCTAssertEqual(resolved[.senato]?.map(\.id), expected.senato, "\(expected.name) → Senato districts")
        }
    }

    // MARK: - Named regressions the assignment path fixes

    /// The two comuni whose interior point fell on the wrong side of a
    /// simplified boundary and so resolved to a NEIGHBOURING collegio
    /// (Phase 30 §2(c) disclosed them as a measured inaccuracy). Reading the
    /// source's own row makes them correct by construction.
    func testCorrectedComuniNowCiteTheSource() {
        let corrections: [(name: String, chamber: Chamber, expected: String)] = [
            ("Carbonara di Nola", .camera, "150106"),
            ("Torre de' Roveri", .camera, "30301"),
            ("Carbonara di Nola", .senato, "S150007"),
            ("Pieve di Cento", .senato, "S80003"),
        ]
        for correction in corrections {
            guard let comune = comune(correction.name) else { continue }
            XCTAssertEqual(
                comune.collegioIds(for: correction.chamber), [correction.expected],
                "\(correction.name) → \(correction.chamber)"
            )
        }
    }

    /// Every comune whose interior point fell OUTSIDE all shipped polygons —
    /// islands and border comuni dropped by the 1000 m simplification — and
    /// therefore had no answer at all. The source has one for each.
    func testPreviouslyUnresolvedComuniNowAnswer() {
        let gaps: [(name: String, chamber: Chamber, expected: String)] = [
            ("Isole Tremiti", .camera, "160002"),
            ("Correzzana", .camera, "30102"),
            ("Pognana Lario", .camera, "30203"),
            ("Porto Recanati", .camera, "110002"),
            ("Ronzone", .camera, "40001"),
            ("Isole Tremiti", .senato, "S160001"),
            ("Tropea", .senato, "S180002"),
        ]
        for gap in gaps {
            guard let comune = comune(gap.name) else { continue }
            XCTAssertEqual(comune.collegioIds(for: gap.chamber), [gap.expected], "\(gap.name) → \(gap.chamber)")
            let resolved = districts.districts(assignedTo: comune)
            XCTAssertEqual(resolved[gap.chamber]?.map(\.id), [gap.expected], "\(gap.name) → district")
        }
    }

    // MARK: - Multi-collegio comuni

    /// The six comuni the source assigns to more than one uninominale
    /// collegio (GO-ASSIGN condition (c)). The set is pinned: a seventh
    /// appearing, or one of these losing its multiplicity, means the source's
    /// assignment moved and must be examined, not absorbed.
    func testMultiCollegioComuniAreExactlyTheSixMeasured() {
        let multi = comuni.comuni.filter(\.spansMultipleCollegi)
        XCTAssertEqual(
            multi.map(\.name).sorted(),
            ["Genova", "Milano", "Napoli", "Palermo", "Roma", "Torino"]
        )
    }

    /// Roma spans SEVEN Camera collegi. All seven are returned; none of them
    /// is "the" collegio of Roma.
    func testMultiCollegioComuneReturnsEveryCollegioNeverOne() {
        guard let roma = comune("Roma") else { return }
        XCTAssertEqual(roma.camera.count, 7)
        XCTAssertEqual(roma.senato.count, 3)

        let resolved = districts.districts(assignedTo: roma)
        XCTAssertEqual(resolved[.camera]?.count, 7)
        XCTAssertEqual(resolved[.senato]?.count, 3)
        XCTAssertEqual(
            resolved[.camera]?.map(\.id),
            ["120101", "120102", "120103", "120104", "120105", "120106", "120107"]
        )

        // The Phase 30 largest-part answer is one MEMBER of the set, not the
        // set — the difference this phase exists to make expressible.
        XCTAssertTrue(resolved[.camera]?.map(\.id).contains("120105") == true)
        XCTAssertNotEqual(resolved[.camera]?.map(\.id), ["120105"])
    }

    /// For every one of the six, the chamber that is multi-valued resolves to
    /// more than one district — no path reduces it to a single answer.
    func testNoMultiCollegioComuneEverResolvesToASingleAnswer() {
        for comune in comuni.comuni where comune.spansMultipleCollegi {
            let resolved = districts.districts(assignedTo: comune)
            for chamber in Chamber.allCases where comune.collegioIds(for: chamber).count > 1 {
                XCTAssertEqual(
                    resolved[chamber]?.count, comune.collegioIds(for: chamber).count,
                    "\(comune.name) → \(chamber): il set pubblicato deve arrivare intero alla UI"
                )
            }
        }
    }

    // MARK: - one / many / none

    /// The homonym chooser path: the name alone is not an answer, and each
    /// candidate carries its OWN assignment — so choosing the province is a
    /// real choice, not a cosmetic one.
    func testHomonymNameIsAmbiguousAndEachCandidateHasItsOwnAssignment() {
        guard case .ambiguous(let candidates) = comuni.match(name: "Castro") else {
            return XCTFail("Castro: attesi più candidati (Bergamo e Lecce)")
        }
        XCTAssertEqual(candidates.map(\.province), ["Bergamo", "Lecce"])
        XCTAssertEqual(candidates[0].camera, ["30302"])
        XCTAssertEqual(candidates[1].camera, ["160010"])
        XCTAssertEqual(candidates[0].senato, ["S30007"])
        XCTAssertEqual(candidates[1].senato, ["S160005"])
    }

    /// An unknown name resolves to nothing — never a nearest neighbour, never
    /// a default (the Phase 28 / Phase 29 nil-not-fallback family).
    func testUnknownComuneIsNoneNeverAFallback() {
        XCTAssertEqual(comuni.match(name: "Nowhereville"), ComuneNameMatch.none)
        XCTAssertEqual(comuni.match(name: ""), ComuneNameMatch.none)
        XCTAssertEqual(comuni.match(name: "Bozen"), ComuneNameMatch.none)
    }

    // MARK: - Whole-table invariants

    /// The in-app half of GO-ASSIGN conditions (a) and (b): every shipped
    /// comune carries a published assignment in both chambers, and every one
    /// of those ids resolves to a shipped uninominale collegio. The validator
    /// enforces the same thing on the artifact; this proves the app agrees.
    func testEveryComuneCarriesAResolvablePublishedAssignment() {
        XCTAssertEqual(comuni.comuni.count, 7904)
        var cameraIds = Set<String>()
        var senatoIds = Set<String>()
        for comune in comuni.comuni {
            XCTAssertFalse(comune.camera.isEmpty, "\(comune.id): assegnazione Camera mancante")
            XCTAssertFalse(comune.senato.isEmpty, "\(comune.id): assegnazione Senato mancante")
            cameraIds.formUnion(comune.camera)
            senatoIds.formUnion(comune.senato)
        }
        XCTAssertEqual(cameraIds.count, 147)
        XCTAssertEqual(senatoIds.count, 74)
        XCTAssertTrue(cameraIds.allSatisfy { districts.district(withId: $0)?.chamber == .camera })
        XCTAssertTrue(senatoIds.allSatisfy { districts.district(withId: $0)?.chamber == .senato })
    }
}
