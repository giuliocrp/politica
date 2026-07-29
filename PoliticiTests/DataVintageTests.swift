//
//  DataVintageTests.swift
//  PoliticiTests
//
//  Phase 31 (docs/v4/31-live-refresh-adr.md) — the Home footer's one-line
//  staleness disclosure: the most recent `retrievedAt` across the manifest,
//  rendered as a fact with no threshold and no judgment, and simply absent
//  when the manifest cannot be loaded.
//

import XCTest
@testable import Politici

final class DataVintageTests: XCTestCase {

    private func source(_ id: String, _ retrievedAt: String) -> DataSource {
        DataSource(
            id: id,
            name: "Fonte \(id)",
            url: "",
            license: "CC BY 4.0",
            retrievedAt: retrievedAt,
            notes: ""
        )
    }

    /// Fixture values verified by hand, not read back off the implementation:
    /// of 2025-12-31, 2026-03-14 and 2026-01-05 the latest is **2026-03-14**,
    /// and the unparseable row contributes nothing rather than crashing or
    /// defaulting to some date.
    func testLatestRetrievedAtIsMaxOverFixtureSourcesSkippingUnparseable() throws {
        let sources = [
            source("b", "2025-12-31"),
            source("a", "2026-03-14"),
            source("d", "non-una-data"),
            source("c", "2026-01-05"),
        ]
        let latest = try XCTUnwrap(ManifestService.latestRetrievedAt(in: sources))
        XCTAssertEqual(latest, DateFormatting.parseISODate("2026-03-14"))

        XCTAssertNil(ManifestService.latestRetrievedAt(in: []))
        XCTAssertNil(ManifestService.latestRetrievedAt(in: [source("x", "31/12/2025")]))
    }

    /// Pins the deliberate **no-exclusion** decision (ADR §6): the max runs
    /// over every entry including the `prototipo-dati-dimostrativi` fixture
    /// row, because the max is the only value that makes the rendered sentence
    /// ("nothing here was retrieved after this date") true. `make_manifest.py`
    /// never advances that row's own `retrievedAt`, so this case cannot arise
    /// from a normal pipeline run — if it ever does, that is a pipeline defect
    /// worth surfacing, and an id-keyed exclusion would hide it.
    func testLatestRetrievedAtIncludesTheSampleFixtureEntryByDesign() throws {
        let sources = [
            source("camera-dei-deputati-xix-legislatura", "2026-03-14"),
            source("prototipo-dati-dimostrativi", "2026-04-01"),
        ]
        let latest = try XCTUnwrap(ManifestService.latestRetrievedAt(in: sources))
        XCTAssertEqual(latest, DateFormatting.parseISODate("2026-04-01"))
    }

    /// The pinned Italian string, and the honest-absence path. The wording
    /// states the **last retrieval**, not that every source is current to that
    /// date — the manifest normally carries a spread of dates because
    /// minimal-scope refetches are the repo's preferred practice.
    func testDataVintageTextIsPinnedItalianAndAbsentWhenManifestFailsToLoad() throws {
        let date = try XCTUnwrap(DateFormatting.parseISODate("2026-03-14"))
        XCTAssertEqual(
            ManifestService.dataVintageText(for: date),
            "Ultimo aggiornamento dei dati: 14 marzo 2026"
        )

        // Existing loadError path: no manifest -> no date -> no line at all,
        // never a placeholder.
        let failed = ManifestService(resource: "questo-file-non-esiste")
        XCTAssertNotNil(failed.loadError)
        XCTAssertNil(failed.manifest)
        XCTAssertNil(failed.latestRetrievedAt)
        XCTAssertNil(failed.dataVintageText)
    }

    /// Over the shipping manifest, computed independently of the
    /// implementation's path: ISO `yyyy-MM-dd` strings sort lexicographically,
    /// so the expected value is a plain string `max` on the decoded JSON —
    /// no exact date is pinned, so a refetch that advances `retrievedAt`
    /// keeps this green rather than needing a re-pin.
    func testShippingVintageMatchesIndependentlyComputedMaxRetrievedAt() throws {
        let manifest = try LocalJSONLoader.decode(SourcesManifest.self, fromResource: "sources")
        let expectedString = try XCTUnwrap(manifest.sources.map(\.retrievedAt).max())
        let expected = try XCTUnwrap(DateFormatting.parseISODate(expectedString))

        let service = ManifestService()
        XCTAssertEqual(service.latestRetrievedAt, expected)
        XCTAssertEqual(
            service.dataVintageText,
            "Ultimo aggiornamento dei dati: \(DateFormatting.longString(from: expected))"
        )
    }
}
