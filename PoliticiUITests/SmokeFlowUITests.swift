//
//  SmokeFlowUITests.swift
//  PoliticiUITests
//
//  The seven Phase 24 smoke flows (docs/v4/24-ui-tests.md). Every asserted
//  string is a string already pinned by a v3 phase report or by
//  docs/v3/a11y-checklist.md — none of the copy here was re-invented for the
//  test. Where a flow pins a piece of real data (a collegio id, a senator, a
//  votazione), the value was verified directly against the shipped
//  Politici/Data/*.json before being hardcoded, per the plan's
//  "verify test expectations independently" rule; a future data refresh that
//  changes it is expected to fail these tests loudly rather than silently.
//

import XCTest

final class SmokeFlowUITests: PoliticiUITestCase {

    // Verified in Politici/Data/districts.geojson: id 120101,
    // name "Lazio 1 - U01", circoscrizione "Lazio 1".
    private let cameraDistrictId = "120101"
    private let cameraDistrictName = "Lazio 1 - U01"
    private let cameraCircoscrizione = "Lazio 1"

    // Verified in Politici/Data/districts_senato.geojson: id S120001,
    // name "Lazio - U01", regione "Lazio"; and in representatives.json,
    // one senator (s33096) carries districtId "S120001".
    private let senatoDistrictId = "S120001"
    private let senatoDistrictName = "Lazio - U01"

    // Verified in Politici/Data/representatives.json: the five serving
    // senators with mandate "a vita, di nomina del Presidente della
    // Repubblica"; s32435 is one of them.
    private let lifeSenatorId = "s32435"
    private let lifeSenatorSearchTerm = "Segre"
    private let lifeSenatorBadge = "A vita, di nomina del Presidente della Repubblica"

    // Verified in Politici/Data/votes.json (Phase 27 stratified sample):
    // deputy p300480 (Giachetti) is Contrario on event vs19_577_001, the
    // final vote on DDL n. 2423 ("...consenso informato..."), and "2423" is a
    // title substring unique to that one vote among his — so the outcome chips
    // compose with the title search in a known, asymmetric way (Contrario
    // keeps it, Favorevole empties the filter).
    //
    // NOTE (Phase 27): these three are vote-specific and WILL break on any
    // future votes.json change (a refetch may legitimately select a different
    // 30 — the selection is deterministic for fixed input but not stable
    // across refetches). Flow 6's compose logic inherently needs one vote with
    // a known position, so it can't be made fully structural like flow 5;
    // a failure here after a data refresh means "re-pin", not "regression".
    private let voterId = "p300480"
    private let voterSearchTerm = "Giachetti"
    private let voteRowId = "vote.row.vd19_577_001_300480"
    private let voteTitleQuery = "2423"

    // Verified in Politici/Data/representatives.json: the first record in
    // file order, i.e. the first of the four `HomeView` shows under
    // "Rappresentanti in evidenza" (`allRepresentatives().prefix(4)`).
    private let featuredRepresentativeId = "p200291"

    // MARK: - Flow 1

    @MainActor
    func testColdLaunchHomeShowsStatCardsWithDataDrivenValues() throws {
        // Home's introductory header (`home.title`) was removed in the post-v4
        // tidy, so this flow's opening assertion took the address field as its
        // new subject — the topmost thing on Home now. Asserted **hittable**,
        // not merely existing: with ~100 pt of heading and tagline gone above
        // it, everything below moved up, and the failure this guards against
        // is the field coming to rest under the translucent navigation bar,
        // where it would still be in the accessibility tree and untappable
        // (the `.exists`-is-not-reachability rule in CLAUDE.md). No scrolling
        // first: at the top of the page it must be reachable on launch.
        let search = assertExists("home.search.field", "Campo indirizzo in Home non trovato")
        XCTAssertTrue(search.isHittable, "Campo indirizzo non raggiungibile all'avvio della Home")

        let expectedCaptions = [
            "home.stat.collegi": "Collegi uninominali",
            "home.stat.rappresentanti": "Rappresentanti",
            "home.stat.camere": "Camere del Parlamento",
            "home.stat.preferiti": "Preferiti"
        ]
        for (identifier, caption) in expectedCaptions {
            let card = assertExists(identifier, "Scheda statistica '\(caption)' non trovata")
            XCTAssertTrue(card.label.contains(caption), "Etichetta inattesa per \(identifier): '\(card.label)'")
            let value = Self.firstInteger(in: card.label)
            XCTAssertNotNil(value, "Nessun valore numerico in \(identifier): '\(card.label)'")
        }

        // The two counts that come from the bundled data must be non-empty,
        // i.e. genuinely read from it rather than a placeholder zero.
        XCTAssertGreaterThan(Self.firstInteger(in: el("home.stat.collegi").label) ?? 0, 0)
        XCTAssertGreaterThan(Self.firstInteger(in: el("home.stat.rappresentanti").label) ?? 0, 0)

        XCTAssertTrue(el("home.cta.map").exists, "CTA della mappa non trovata")
        XCTAssertTrue(el("home.cta.votazioni").exists, "CTA delle votazioni non trovata")
    }

    // MARK: - Flow 2

    @MainActor
    func testCameraCollegioDetailPinnedHeadersAndDeputyProfile() throws {
        let search = openCollegiList()
        XCTAssertTrue(
            Self.matches(navigationTitle, pattern: #"^Collegi \(\d+\)$"#),
            "Titolo inatteso per l'elenco dei collegi: '\(navigationTitle)'"
        )

        // Chamber switch, then back to Camera — the picker drives the list.
        selectChamber("Senato della Repubblica")
        selectChamber("Camera dei Deputati")

        type(cameraDistrictName, into: search)
        let uninominale = el("district.section.uninominale")
        tapButton("collegio.row.\(cameraDistrictId)", waitingFor: uninominale, "Pagina del collegio \(cameraDistrictName) non aperta")
        XCTAssertEqual(uninominale.label, "Eletto nel collegio uninominale")

        let plurinominale = assertExists("district.section.plurinominale", "Intestazione della sezione plurinominale non trovata")
        XCTAssertEqual(
            plurinominale.label,
            "Rappresentanti plurinominali della circoscrizione \(cameraCircoscrizione)"
        )

        openFirstRepresentativeRow()
        XCTAssertTrue(el("profile.favorite").exists, "Stella dei preferiti non trovata sul profilo")
    }

    // MARK: - Flow 3

    @MainActor
    func testSenatoCollegioDetailAndLifeSenatorMandateBadge() throws {
        let search = openCollegiList()
        selectChamber("Senato della Repubblica")
        type(senatoDistrictName, into: search)
        let header = el("district.header")
        tapButton("collegio.row.\(senatoDistrictId)", waitingFor: header, "Pagina del collegio \(senatoDistrictName) non aperta")
        XCTAssertTrue(header.label.contains("Senato della Repubblica"), "Intestazione senza camera: '\(header.label)'")
        XCTAssertTrue(header.label.contains("Regione: Lazio"), "Intestazione senza regione: '\(header.label)'")

        let section = assertExists("district.section.uninominale", "Intestazione della sezione dei rappresentanti non trovata")
        XCTAssertEqual(section.label, "Rappresentanti eletti")
        // The plurinominale section is Camera-only (Phase 18).
        XCTAssertFalse(el("district.section.plurinominale").exists, "Sezione plurinominale mostrata su una pagina del Senato")

        openFirstRepresentativeRow()

        // The a-vita badge, on a known life senator reached through the
        // representative list's search — never through a map tap. The badge
        // lives inside the profile header's combined accessibility element
        // (docs/v3/a11y-checklist.md), so it is asserted on that label.
        relaunch()
        let nameSearch = openRepresentativeList()
        type(lifeSenatorSearchTerm, into: nameSearch)
        let profile = el("profile.header")
        tapButton("representative.row.\(lifeSenatorId)", waitingFor: profile, "Profilo del senatore a vita non aperto")
        XCTAssertTrue(
            profile.label.contains(lifeSenatorBadge),
            "Badge del mandato a vita assente dall'intestazione: '\(profile.label)'"
        )
    }

    // MARK: - Flow 4

    @MainActor
    func testFavoriteToggleUpdatesHomeCountAndPreferitiList() throws {
        let before = Self.firstInteger(in: assertExists("home.stat.preferiti", "Scheda 'Preferiti' non trovata").label)
        XCTAssertEqual(before, 0, "La suite dei preferiti sotto test non è partita vuota")

        // Reached from Home's own "Rappresentanti in evidenza" list rather
        // than through the searchable list, so the single pop back to Home
        // below crosses no `.searchable` screen (see `goBack`).
        let star = button("profile.favorite")
        tapButton("representative.row.\(featuredRepresentativeId)", waitingFor: star, "Profilo del rappresentante in evidenza non aperto")
        XCTAssertEqual(star.label, "Aggiungi ai preferiti")
        star.tap()

        expectation(for: NSPredicate(format: "label == %@", "Rimuovi dai preferiti"), evaluatedWith: star)
        waitForExpectations(timeout: Self.timeout)

        goBackToHome()
        let after = Self.firstInteger(in: el("home.stat.preferiti").label)
        XCTAssertEqual(after, 1, "Il contatore dei preferiti in Home non si è aggiornato")

        tapButton(
            "home.stat.preferiti",
            waitingFor: el("representative.row.\(featuredRepresentativeId)"),
            "Il rappresentante aggiunto non compare nell'elenco dei preferiti"
        )
    }

    // MARK: - Flow 5

    @MainActor
    func testVotazioniListScopeLineTalliesAndSourceLink() throws {
        let scope = el("votazioni.scope")
        tapButton("home.cta.votazioni", waitingFor: scope, "Elenco delle votazioni non aperto")
        // Structural (Phase 27): the scope line names the sample and carries a
        // data-driven N > 0. The exact wording is Phase-27 copy that may
        // evolve (it now describes a stratified, coverage-driven pick), so
        // assert content, not the full string.
        XCTAssertTrue(scope.label.localizedCaseInsensitiveContains("votazioni"),
                      "Riga di ambito inattesa: '\(scope.label)'")
        XCTAssertGreaterThan(Self.firstInteger(in: scope.label) ?? 0, 0, "Ambito senza N letto dai dati")

        // Structural: the first votazione row, whichever event it is — no
        // vote-specific id pinned (those move on any votes.json change). The
        // source-link ids also begin "vote.event." so they're excluded.
        let rows = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND NOT (identifier CONTAINS %@)",
                        "vote.event.", ".source.")
        )
        let firstRow = rows.element(boundBy: 0)
        XCTAssertTrue(firstRow.waitForExistence(timeout: Self.timeout), "Prima riga di votazione non trovata")
        for tally in ["Favorevoli:", "Contrari:", "Astenuti:", "Assenti:"] {
            XCTAssertTrue(firstRow.label.contains(tally), "Conteggio '\(tally)' assente da: '\(firstRow.label)'")
        }
        XCTAssertTrue(firstRow.label.contains("Esito:"), "Esito assente da: '\(firstRow.label)'")

        // Structural: at least one per-row official source link exists
        // (existence only — tapping it would leave the app for Safari).
        let sources = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "vote.event.source.")
        )
        let source = sources.element(boundBy: 0)
        XCTAssertTrue(source.waitForExistence(timeout: Self.timeout), "Link 'Fonte' assente dalla prima riga")
        XCTAssertEqual(source.label, "Fonte ufficiale")
    }

    // MARK: - Flow 6

    @MainActor
    func testVoteHistoryOutcomeChipAndTitleSearchCompose() throws {
        let nameSearch = openRepresentativeList()
        type(voterSearchTerm, into: nameSearch)
        tapButton("representative.row.\(voterId)", waitingFor: button("profile.cta.voteHistory"), "Profilo del deputato non aperto")

        let titleSearch = app.searchFields["Cerca nel titolo"]
        tapButton("profile.cta.voteHistory", waitingFor: titleSearch, "Cronologia dei voti non aperta")
        type(voteTitleQuery, into: titleSearch)

        let row = el(voteRowId)
        XCTAssertTrue(row.waitForExistence(timeout: Self.timeout), "La ricerca per titolo non ha trovato la votazione attesa")

        // Compose: the same votazione is a "Contrario" for this deputy, so
        // the Contrario chip must keep it and the Favorevole chip must not.
        tapButton("voteHistory.chip.Contrario", "Chip 'Contrario' non trovato")
        XCTAssertTrue(row.waitForExistence(timeout: Self.timeout), "Chip Contrario + ricerca hanno escluso una votazione contraria")

        tapButton("voteHistory.chip.Favorevole", "Chip 'Favorevole' non trovato")
        XCTAssertTrue(
            el("voteHistory.emptyFilter").waitForExistence(timeout: Self.timeout),
            "Stato vuoto dei filtri non mostrato"
        )
        XCTAssertFalse(row.exists, "Una votazione contraria è rimasta visibile sotto il filtro Favorevole")

        tapButton("voteHistory.chip.tutte", "Chip 'Tutte' non trovato")
        XCTAssertTrue(row.waitForExistence(timeout: Self.timeout), "Il chip 'Tutte' non ha ripristinato la votazione")
    }

    // MARK: - Flow 7

    @MainActor
    func testAddressSearchRendersDualChamberResultStructure() throws {
        let field = assertExists("home.search.field", "Campo indirizzo in Home non trovato")
        type("Roma", into: field)
        tapButton("home.search.submit", waitingFor: el("addressSearch.field"), "Schermata di ricerca indirizzo non aperta")
        XCTAssertTrue(el("addressSearch.city.Roma").exists, "Città campione 'Roma' non trovata")

        // Bounded at last (Phase 30B). Two independent things now keep this
        // off the network, where Phase 24 had to carry a 300 s ceiling for a
        // live `CLGeocoder` attempt measured at ~1 s to >120 s:
        //   * "Roma" is a comune name, so it is answered from the bundled
        //     published assignment without any geocoding at all, and
        //   * every UI test launches with `-stubAddressResolver 1`, which
        //     stubs the `CLGeocoder` tier out even when the coordinate path
        //     does run (see PoliticiUITestCase.launchArguments).
        // Nothing below asserts *which* collegio resolved, so the assertion
        // holds identically whichever path ran.
        XCTAssertTrue(
            el("addressSearch.results.header").waitForExistence(timeout: Self.timeout),
            "Sezione dei risultati non comparsa"
        )
        XCTAssertTrue(el("addressSearch.result.camera").exists, "Riga del risultato Camera assente")
        XCTAssertTrue(el("addressSearch.result.senato").exists, "Riga del risultato Senato assente")

        // Roma is assigned SEVEN Camera collegi by the source, so the screen
        // must list all of them rather than present one as "the" collegio
        // (Phase 30B — docs/v4/30b-comuni-assignment.md). Each carries its own
        // "addressSearch.result.camera.<id>" identifier.
        let romaCameraCollegi = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "addressSearch.result.camera.")
        )
        XCTAssertGreaterThan(
            romaCameraCollegi.count, 1,
            "Roma è divisa tra più collegi Camera: devono essere elencati tutti, non uno solo"
        )
    }

    // MARK: - Flow 8

    /// Phase 31's only user-facing deliverable is the data-vintage line, and
    /// it sits **below Home's fold** — so until this flow existed, nothing
    /// asserted it reaches the screen at all (`DataVintageTests` proves the
    /// value is derived correctly; the wiring was only checked by reading the
    /// code). See docs/v4/31-live-refresh-adr.md §13.
    ///
    /// Looked up by identifier, per the suite's rule. The identifier is on the
    /// **Button** (`home.footer.fonti`) rather than on the line itself: the
    /// line is inside a `Button` label, so the button is the single
    /// accessibility element and a child identifier would be silently
    /// unreachable — the shadowing trap CLAUDE.md records from Phase 30B. The
    /// content is therefore read off the button's combined label.
    ///
    /// The exact date is deliberately **not** pinned. It is the max
    /// `retrievedAt` across sources.json and advances on any refetch, so
    /// pinning it would be re-pin bait (same reasoning as the Phase 27/28 data
    /// anchors). What is asserted is the pinned copy plus a well-formed
    /// Italian long date, which is what "derived and rendered" means here.
    @MainActor
    func testHomeFooterShowsTheDerivedDataVintageLine() throws {
        let footer = button("home.footer.fonti")
        scrollUntilHittable(footer)

        let label = footer.label
        XCTAssertTrue(
            label.contains("Informazioni e fonti"),
            "Il piè di pagina ha perso il testo del pulsante: '\(label)'"
        )
        XCTAssertTrue(
            label.contains("Ultimo aggiornamento dei dati:"),
            "Riga di aggiornamento dei dati assente dal piè di pagina: '\(label)'"
        )
        XCTAssertTrue(
            Self.matches(
                label,
                pattern: #"Ultimo aggiornamento dei dati: \d{1,2} (gennaio|febbraio|marzo|aprile|maggio|giugno|luglio|agosto|settembre|ottobre|novembre|dicembre) \d{4}"#
            ),
            "Data non formattata come data lunga italiana: '\(label)'"
        )
    }
}
