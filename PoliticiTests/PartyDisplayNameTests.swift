//
//  PartyDisplayNameTests.swift
//  PoliticiTests
//

import XCTest
@testable import Politici

/// `PartyDisplayName` is the display-side answer to a **source defect**: the
/// Camera group `dc:title` ships truncated at a parenthesis
/// (docs/v4/28-membership-history.md §5.4), and the data deliberately keeps it
/// that way. These tests run against the real malformed strings, not
/// hand-invented ones — the exact values in `Data/representatives.json`.
final class PartyDisplayNameTests: XCTestCase {

    // MARK: - The real Camera strings (all ten, verbatim from the shipping data)

    func testStripsTheSourceDefectFromEveryRealCameraGroupString() {
        let cases: [(String, String)] = [
            ("ALLEANZA VERDI E SINISTRA (AVS) (27.10.2022",
             "ALLEANZA VERDI E SINISTRA"),
            ("AZIONE-POPOLARI EUROPEISTI RIFORMATORI-RENEW EUROPE (AZ-PER-RE) (18.10.2022",
             "AZIONE-POPOLARI EUROPEISTI RIFORMATORI-RENEW EUROPE"),
            ("FORZA ITALIA - BERLUSCONI PRESIDENTE - PPE (FI-PPE) (18.10.2022",
             "FORZA ITALIA - BERLUSCONI PRESIDENTE - PPE"),
            ("FRATELLI D'ITALIA (FDI) (18.10.2022",
             "FRATELLI D'ITALIA"),
            ("ITALIA VIVA-CASA RIFORMISTA (IV-CR) (20.11.2023",
             "ITALIA VIVA-CASA RIFORMISTA"),
            ("LEGA - SALVINI PREMIER (LEGA) (18.10.2022",
             "LEGA - SALVINI PREMIER"),
            ("MISTO (MISTO) (18.10.2022",
             "MISTO"),
            ("MOVIMENTO 5 STELLE (M5S) (18.10.2022",
             "MOVIMENTO 5 STELLE"),
            // Brackets in *both* the name and the sigla — the case a leftmost
            // regex match would cut at "NOI MODERATI".
            ("NOI MODERATI (NOI CON L'ITALIA, CORAGGIO ITALIA, UDC E ITALIA AL CENTRO)-MAIE-CENTRO POPOLARE (NM(N-C-U-I)M-CP) (27.10.2022",
             "NOI MODERATI (NOI CON L'ITALIA, CORAGGIO ITALIA, UDC E ITALIA AL CENTRO)-MAIE-CENTRO POPOLARE"),
            ("PARTITO DEMOCRATICO - ITALIA DEMOCRATICA E PROGRESSISTA (PD-IDP) (18.10.2022",
             "PARTITO DEMOCRATICO - ITALIA DEMOCRATICA E PROGRESSISTA")
        ]
        for (source, expected) in cases {
            XCTAssertEqual(PartyDisplayName.full(from: source), expected, "for \(source)")
        }
    }

    // MARK: - The real Senato strings (already clean — must pass through)

    /// Senato's `parliamentaryGroup` carries no defect, so nothing may be
    /// removed from it. `"Per le Autonomie (SVP-PATT, Campobase)"` is the
    /// reason the rule is anchored on the truncated date rather than on "the
    /// last parenthetical": that name legitimately *ends* in one.
    func testLeavesEveryRealSenatoGroupStringUntouched() {
        let clean = [
            "Civici d'Italia-UDC-Noi Moderati (Noi con l'Italia, Coraggio Italia, Italia al Centro)-MAIE-Centro Popolare",
            "Forza Italia - Berlusconi Presidente - PPE",
            "Fratelli d'Italia",
            "Italia Viva - Casa Riformista",
            "Lega Salvini Premier - Partito Sardo d'Azione",
            "Misto",
            "MoVimento 5 Stelle",
            "Partito Democratico - Italia Democratica e Progressista",
            "Per le Autonomie (SVP-PATT, Campobase)"
        ]
        for name in clean {
            XCTAssertEqual(PartyDisplayName.full(from: name), name)
        }
    }

    // MARK: - Boundaries of the rule

    func testDoesNotStripAWellFormedTrailingDate() {
        // Closed bracket: a well-formed source string, nothing to repair.
        XCTAssertEqual(
            PartyDisplayName.full(from: "MISTO (MISTO) (18.10.2022)"),
            "MISTO (MISTO) (18.10.2022)"
        )
    }

    func testDoesNotStripWhenTheDateFragmentIsNotADate() {
        XCTAssertEqual(PartyDisplayName.full(from: "GRUPPO (GRP) (data"), "GRUPPO (GRP) (data")
        XCTAssertEqual(PartyDisplayName.full(from: "GRUPPO (GRP) (2022"), "GRUPPO (GRP) (2022")
        XCTAssertEqual(PartyDisplayName.full(from: "GRUPPO (GRP) (18.10.2022 "), "GRUPPO (GRP) (18.10.2022 ")
    }

    func testDoesNotStripWhenTheSiglaBracketIsMissing() {
        XCTAssertEqual(PartyDisplayName.full(from: "GRUPPO SENZA SIGLA (18.10.2022"), "GRUPPO SENZA SIGLA (18.10.2022")
    }

    func testReturnsTheSourceStringWhenNothingWouldBeLeft() {
        // Never render a blank chip: if the defect is all there is, keep it.
        XCTAssertEqual(PartyDisplayName.full(from: " (FDI) (18.10.2022"), " (FDI) (18.10.2022")
    }

    func testEmptyAndOrdinaryStringsPassThrough() {
        XCTAssertEqual(PartyDisplayName.full(from: ""), "")
        XCTAssertEqual(PartyDisplayName.full(from: "Misto"), "Misto")
    }

    func testIsIdempotent() {
        let once = PartyDisplayName.full(from: "FRATELLI D'ITALIA (FDI) (18.10.2022")
        XCTAssertEqual(PartyDisplayName.full(from: once), once)
    }

    // MARK: - Against the shipping data

    /// The guard that matters for the profile screen: for **every** one of the
    /// 601 shipping representatives the derived name is non-empty, carries no
    /// leftover date fragment and no trailing sigla-in-brackets, and is a
    /// literal prefix of the source string — i.e. the rule only ever *removes*
    /// characters, never rewrites or substitutes them.
    func testEveryShippingRepresentativeGetsAnHonestFullName() throws {
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        XCTAssertFalse(representatives.isEmpty)
        for representative in representatives {
            let source = representative.parliamentaryGroup
            let derived = PartyDisplayName.full(from: source)
            XCTAssertFalse(derived.trimmingCharacters(in: .whitespaces).isEmpty, "\(representative.id)")
            XCTAssertTrue(source.hasPrefix(derived), "\(representative.id): \(derived) is not a prefix of \(source)")
            XCTAssertNil(
                derived.range(of: #"\(\d{2}\.\d{2}\.\d{4}$"#, options: .regularExpression),
                "\(representative.id): date fragment survived in \(derived)"
            )
        }
    }

    /// Camera is the chamber with the defect, so assert it is actually gone
    /// there — not just that the function ran. Every Camera deputy's derived
    /// name must be strictly shorter than the source string and must no longer
    /// end in the deputy's own sigla in brackets.
    func testCameraNamesLoseTheSiglaAndDateWhileSenatoNamesAreUnchanged() throws {
        let representatives = try LocalJSONLoader.decode([Representative].self, fromResource: "representatives")
        for representative in representatives {
            let source = representative.parliamentaryGroup
            let derived = PartyDisplayName.full(from: source)
            switch representative.chamber {
            case .camera:
                XCTAssertLessThan(derived.count, source.count, "\(representative.id)")
                XCTAssertFalse(derived.hasSuffix("(\(representative.party))"), "\(representative.id): \(derived)")
            case .senato:
                XCTAssertEqual(derived, source, "\(representative.id)")
            }
        }
    }

    /// The fictional fixture predates the real import and has clean group
    /// names; it must survive untouched, like the Senato values.
    func testSampleFixtureNamesAreUnchanged() throws {
        let representatives = try LocalJSONLoader.decode(
            [Representative].self, fromResource: "representatives.sample"
        )
        XCTAssertFalse(representatives.isEmpty)
        for representative in representatives {
            XCTAssertEqual(
                PartyDisplayName.full(from: representative.parliamentaryGroup),
                representative.parliamentaryGroup
            )
        }
    }
}
