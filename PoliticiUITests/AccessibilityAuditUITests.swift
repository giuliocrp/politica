//
//  AccessibilityAuditUITests.swift
//  PoliticiUITests
//
//  iOS 17 `performAccessibilityAudit()` over every screen the app can reach
//  without a map tap. Introduced by Phase 24 (docs/v4/24-ui-tests.md) as a
//  first-viewport pass; **rebuilt by Phase 32A to audit whole screens**
//  (docs/v4/32a-release.md §2) after the Phase 31 closeout proved the
//  viewport limit was hiding real findings below the fold.
//
//  These automate the mechanically checkable part of docs/v3/a11y-checklist.md
//  and docs/v4/a11y-checklist.md; the checklists' remaining human items
//  (real-device VoiceOver traversal, Dynamic Type visual judgment, measured
//  contrast) stay human, and the reports say so rather than implying this file
//  replaced them.
//

import XCTest

final class AccessibilityAuditUITests: PoliticiUITestCase {

    /// The three audit types this suite records instead of failing on.
    ///
    /// **They are not claimed to be false positives.** A discovery run with
    /// the handler wide open (documented finding-by-finding in
    /// docs/v4/24-ui-tests.md §5, re-measured screen-complete in
    /// docs/v4/32a-release.md §2) showed that on every screen audited here the
    /// app raises issues of *only* these three types, and that all of them
    /// land on exactly the questions docs/v3/a11y-checklist.md already records
    /// as still needing a human:
    ///
    /// * `.contrast` — measured contrast in light and dark mode was never
    ///   done on-device in v3 (checklist pending item 3). Most of the hits
    ///   are `.secondary`/`.tertiary` text over `.regularMaterial`, which the
    ///   auditor evaluates against an opaque approximation of a translucent
    ///   background; deciding each one needs a real measurement.
    /// * `.dynamicType` and `.textClipped` — "Dynamic Type at the largest
    ///   accessibility sizes" is checklist pending item 2, a visual judgment.
    ///   The `.dynamicType` hits on two-letter avatar glyphs are the
    ///   deliberate fixed `.font(.system(size:))` in `InitialsAvatar`, whose
    ///   own doc comment explains why that is safe (it is decorative and
    ///   `accessibilityHidden`, and the name is real text beside it).
    ///
    /// Every other audit type — element detection, hit regions, element
    /// descriptions, traits, parent/child relationships — is asserted, and
    /// the app raises zero issues of any of them on every screen below,
    /// **including the parts that only scrolling reaches**. This is a
    /// per-type exclusion with a written cause, not a blanket ignore: the
    /// handler never returns `true` for anything outside this set.
    private static let recordedForHumanJudgment: XCUIAccessibilityAuditType =
        [.contrast, .dynamicType, .textClipped]

    /// The one further exclusion Phase 32A had to add, stated precisely
    /// because it touches a **structural** audit type that Phase 24 asserted.
    ///
    /// Auditing whole screens surfaced `.elementDetection` issues ("This
    /// element appears to display text that should be represented using the
    /// accessibility API") that Phase 24's first-viewport method could never
    /// see. Measured, before deciding anything:
    ///
    /// * **Zero** of them occur in any screen's first viewport — they appear
    ///   only after scrolling (Home 0/1/1/1 across four viewports, VoteHistory
    ///   0/3/0/1, Votazioni 0/0/0/0).
    /// * **Every one of them has `issue.element == nil`** — the auditor cannot
    ///   attribute it to any element in the tree.
    /// * The failure screenshots show why: iOS 26 draws the navigation bar and
    ///   the floating search field as translucent material, and scrolled
    ///   content passes *under* them. The auditor's text detection sees text
    ///   pixels where no accessibility element sits, which is a property of
    ///   the system chrome's blur, not of this app's element tree — the row
    ///   underneath is exposed, labelled and reachable.
    ///
    /// So the exclusion is scoped to exactly that measured class: an
    /// `.elementDetection` issue **with no element attached**. One that names
    /// an element — an image with baked-in text, a custom-drawn label — still
    /// fails the suite, which is what makes this narrower than adding
    /// `.elementDetection` to the set above. **The honest limitation:** a
    /// genuine element-detection defect that the auditor also failed to
    /// attribute would be recorded rather than asserted. Nothing observed so
    /// far has that shape, and the recorded inventory would still show it.
    private static func isUnattributableTextDetection(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
        issue.auditType == .elementDetection && issue.element == nil
    }

    // MARK: - The audit primitive

    /// Runs one `performAccessibilityAudit` over whatever is currently
    /// visible and returns the recorded (non-asserted) findings.
    ///
    /// The auditor has its own internal time budget and reports
    /// `accessibilityAudit` error `-56` ("Audit failed to complete in time")
    /// on the densest screens here. That single, narrow case is retried
    /// **once**: the retry is for the auditor failing to finish, never for an
    /// audit that finished and found something. A second timeout fails the
    /// test, and no other error is retried. Recorded in
    /// docs/v4/24-ui-tests.md §6.4 rather than applied silently.
    private func runAudit(_ screen: String, file: StaticString, line: UInt) -> [String] {
        var recorded: [String] = []
        let handler: (XCUIAccessibilityAuditIssue) -> Bool = { issue in
            guard Self.recordedForHumanJudgment.contains(issue.auditType)
                    || Self.isUnattributableTextDetection(issue) else { return false }
            recorded.append("\(issue.compactDescription): \(issue.element?.label ?? "—")")
            return true
        }
        do {
            do {
                try app.performAccessibilityAudit(for: .all, handler)
            } catch let error as NSError where error.code == -56 {
                recorded.removeAll()
                try app.performAccessibilityAudit(for: .all, handler)
            }
        } catch {
            XCTFail("Audit di accessibilità non eseguibile su \(screen): \(error)", file: file, line: line)
        }
        return recorded
    }

    /// Audits `screen` across `viewports` successive viewports, scrolling
    /// between them, and attaches the merged inventory.
    ///
    /// **Why this exists.** `performAccessibilityAudit` only ever sees what is
    /// on screen. Phase 24 audited each screen once, at its initial scroll
    /// position, and its 62-finding inventory was therefore an undercount of
    /// unknown size — proven by the Phase 31 closeout, where simply scrolling
    /// Home to its footer surfaced a *pre-existing* contrast failure on the
    /// "Informazioni e fonti" button plus four `InitialsAvatar` findings on
    /// the featured rows, none of them among the 62
    /// (docs/v4/31-live-refresh-adr.md §13). Phase 24 met its spec as written;
    /// its criterion 2 is properly read as "each screen's initial viewport
    /// passes".
    ///
    /// **Scrolling** is a `swipeUp()` sent to the screen's main scrollable
    /// element (`mainScrollable()`), the same coordinate-free mechanism as
    /// `scrollUntilHittable` — never a screen coordinate. Over-swiping a
    /// screen that has already reached its bottom is harmless: the extra
    /// audit repeats findings the merge collapses, so `viewports` may be an
    /// over-estimate without affecting the result.
    ///
    /// **Merge rule, stated because it decides the number this reports.**
    /// Each viewport yields a multiset of findings; the merged inventory
    /// takes, per distinct `"<description>: <label>"` key, the **maximum**
    /// count seen in any single viewport — not the sum, which would
    /// double-count the elements two overlapping viewports share. It is
    /// therefore a **lower bound**: two genuinely distinct findings with the
    /// same description and label (the unresolvable `—` rows on list screens
    /// are the real case) collapse into one if they never appear in the same
    /// viewport. Under-counting is the conservative direction for a claim
    /// that the previous count was too low.
    ///
    /// **Long lists are bounded, deliberately.** `CollegiListView` has 147
    /// rows; auditing to its end would be ~40 audits of the same
    /// `CollegioRow` component. Where the caller passes a `viewports` value
    /// that cannot reach the end of a homogeneous list, the inventory is
    /// complete *by cause* — one more identical row adds instances, not a new
    /// finding — and the phase report says which screens those are.
    @discardableResult
    private func audit(
        _ screen: String,
        viewports: Int = 1,
        file: StaticString = #filePath, line: UInt = #line
    ) -> [String: Int] {
        var merged: [String: Int] = [:]
        var dumps: [String] = []

        for index in 0..<max(1, viewports) {
            if index > 0 {
                guard let scrollable = mainScrollable() else { break }
                scrollable.swipeUp()
            }
            // Never audit a moving screen: an in-flight inertial scroll makes
            // the auditor describe a layout that never rests, and it raised a
            // spurious `.elementDetection` issue exactly that way during this
            // phase (see `waitForScrollToSettle`).
            waitForScrollToSettle()
            let recorded = runAudit(screen, file: file, line: line)
            var counts: [String: Int] = [:]
            for finding in recorded { counts[finding, default: 0] += 1 }
            for (key, count) in counts { merged[key] = max(merged[key] ?? 0, count) }
            dumps.append(
                "--- riquadro \(index + 1)/\(max(1, viewports)) ---\n"
                + (recorded.isEmpty ? "(nessun rilievo)" : recorded.joined(separator: "\n"))
            )
        }

        let total = merged.values.reduce(0, +)
        let inventory = merged.keys.sorted().map { "\(merged[$0]!) × \($0)" }.joined(separator: "\n")
        let body = """
        ===== \(screen) — \(total) rilievi (inventario unificato, max per riquadro) =====
        \(total == 0 ? "(nessun rilievo)" : inventory)

        \(dumps.joined(separator: "\n\n"))
        """

        // Kept even on success: this attachment *is* the inventory the phase
        // reports quote. `.deleteOnSuccess` (the default) would throw away the
        // evidence exactly when the suite is green.
        let attachment = XCTAttachment(string: body)
        attachment.name = "audit-\(screen)"
        attachment.lifetime = .keepAlways
        XCTContext.runActivity(named: "Audit di accessibilità — \(screen)") { $0.add(attachment) }
        return merged
    }

    // MARK: - Home

    @MainActor
    func testAccessibilityAuditHome() throws {
        let whole = audit("Home", viewports: 4)

        // Proof that the paged audit above actually reached the bottom of the
        // page, rather than `viewports: 4` being an unverified guess: scroll
        // deliberately to the footer (Home's last control) and audit that one
        // viewport, then assert its findings are a **subset** of the paged
        // inventory. Stated as a subset rather than as "the footer raised
        // finding X" so the assertion keeps holding if a future fix removes a
        // finding — it tests coverage, not the presence of a defect.
        scrollUntilHittable(button("home.footer.fonti"))
        let footer = audit("Home — piè di pagina")
        for (finding, count) in footer {
            XCTAssertGreaterThanOrEqual(
                whole[finding] ?? 0, count,
                "L'audit paginato della Home non ha coperto il piè di pagina: manca '\(finding)'"
            )
        }
    }

    // MARK: - Collegi list — both chambers, both collegio types

    /// Covers Phase 25's collegio-type filter, which no UI test addressed
    /// before Phase 32A, on both chambers.
    ///
    /// Bounded at 3 (uninominale) / 2 (plurinominale) viewports: the lists are
    /// 147 / 74 / 49 / 26 rows of one homogeneous `CollegioRow`, so scrolling
    /// further adds instances of an already-recorded finding, not new causes.
    @MainActor
    func testAccessibilityAuditCollegiListBothChambersAndTypes() throws {
        openCollegiList()
        audit("Elenco dei collegi — Camera, uninominali", viewports: 3)

        selectCollegioType("Collegi plurinominali")
        audit("Elenco dei collegi — Camera, plurinominali", viewports: 2)

        selectChamber("Senato della Repubblica")
        audit("Elenco dei collegi — Senato, plurinominali", viewports: 2)

        selectCollegioType("Collegi uninominali")
        audit("Elenco dei collegi — Senato, uninominali", viewports: 3)
    }

    // MARK: - Collegio detail — uninominale, both chambers

    @MainActor
    func testAccessibilityAuditDistrictDetailBothChambers() throws {
        let search = openCollegiList()
        type("Lazio 1 - U01", into: search)
        tapButton("collegio.row.120101", waitingFor: el("district.section.plurinominale"), "Pagina del collegio Camera non aperta")
        audit("Dettaglio del collegio — Camera", viewports: 4)

        relaunch()

        let senatoSearch = openCollegiList()
        selectChamber("Senato della Repubblica")
        type("Lazio - U01", into: senatoSearch)
        tapButton("collegio.row.S120001", waitingFor: el("district.header"), "Pagina del collegio Senato non aperta")
        audit("Dettaglio del collegio — Senato", viewports: 4)
    }

    // MARK: - Collegio detail — plurinominale (Phase 25 surface)

    /// The plurinominale collegio page: a Camera one (which lists the deputies
    /// elected there) and a Senato one (geography only, honest empty state).
    /// Neither had ever been audited.
    @MainActor
    func testAccessibilityAuditPlurinominaleCollegioPages() throws {
        // Verified in Politici/Data/districts_plurinominali_camera.geojson:
        // id CP120101, name "Lazio 1 - P01" (plurinominale ids carry the
        // "CP"/"SP" prefix, so they never collide with the uninominale ones);
        // 8 deputies carry `collegioPlurinominale: "CP120101"` in
        // representatives.json, so the page renders rows rather than its
        // empty state.
        let search = openCollegiList()
        selectCollegioType("Collegi plurinominali")
        type("Lazio 1 - P01", into: search)
        tapButton(
            "collegio.row.CP120101",
            waitingFor: el("district.section.plurinominaleCollegio"),
            "Pagina del collegio plurinominale Camera non aperta"
        )
        audit("Dettaglio del collegio plurinominale — Camera", viewports: 3)

        relaunch()

        // Verified in Politici/Data/districts_plurinominali_senato.geojson:
        // id SP120001, name "Lazio - P01". No senator is linked to a
        // plurinominale collegio in this prototype, so this page is the
        // honest empty state — which is exactly what deserves an audit.
        let senatoSearch = openCollegiList()
        selectChamber("Senato della Repubblica")
        selectCollegioType("Collegi plurinominali")
        type("Lazio - P01", into: senatoSearch)
        tapButton(
            "collegio.row.SP120001",
            waitingFor: el("district.section.plurinominaleCollegio"),
            "Pagina del collegio plurinominale Senato non aperta"
        )
        audit("Dettaglio del collegio plurinominale — Senato", viewports: 2)
    }

    // MARK: - Profiles + Preferiti

    /// Two profiles, because they are structurally different screens: a life
    /// senator's carries the long a-vita badge and the Senato "Regione:" line,
    /// a Camera deputy's carries the "Circoscrizione:" line and the
    /// plurinominale-elected shape. Phase 24 audited only a senator's, so the
    /// deputy state was unaudited until Phase 32A.
    ///
    /// Until the post-v4 tidy the deputy half waited on `profile.alignment`,
    /// Phase 29's metric section — the reason this second profile was added.
    /// That section no longer renders (see `GroupAlignment`), so the wait is on
    /// the header, and the deputy profile is audited for what it still is: the
    /// Camera-shaped profile, distinct from the senator one above.
    @MainActor
    func testAccessibilityAuditProfilesAndPreferiti() throws {
        let nameSearch = openRepresentativeList()
        type("Segre", into: nameSearch)
        tapButton("representative.row.s32435", waitingFor: el("profile.header"), "Profilo del senatore a vita non aperto")
        audit("Profilo del rappresentante — senatrice a vita", viewports: 3)

        relaunch()

        let deputySearch = openRepresentativeList()
        type("Giachetti", into: deputySearch)
        tapButton("representative.row.p300480", waitingFor: el("profile.header"), "Profilo del deputato non aperto")
        // The metric section is gone, so this screen is shorter than it was;
        // `viewports` may over-estimate without affecting the merged inventory
        // (see `audit(_:viewports:)`), and 3 still reaches its bottom.
        audit("Profilo del rappresentante — deputato", viewports: 3)

        relaunch()

        // Preferiti needs a starred representative, and the star must survive
        // the trip back to Home — so this half goes through Home's featured
        // list, keeping the stack free of `.searchable` screens (see
        // `goBack`).
        tapButton("representative.row.p200291", waitingFor: button("profile.favorite"), "Profilo del rappresentante in evidenza non aperto")
        tapButton("profile.favorite", "Stella dei preferiti non trovata")
        goBackToHome()
        tapButton("home.stat.preferiti", waitingFor: el("representative.row.p200291"), "Elenco dei preferiti non aperto")
        // One starred row cannot overflow the screen, so one viewport is the
        // whole screen here.
        audit("Preferiti", viewports: 1)
    }

    // MARK: - Votazioni + cronologia

    @MainActor
    func testAccessibilityAuditVotazioniAndVoteHistory() throws {
        tapButton("home.cta.votazioni", waitingFor: el("votazioni.scope"), "Elenco delle votazioni non aperto")
        audit("Votazioni", viewports: 4)

        goBackToHome()

        let nameSearch = openRepresentativeList()
        type("Giachetti", into: nameSearch)
        tapButton("representative.row.p300480", waitingFor: button("profile.cta.voteHistory"), "Profilo del deputato non aperto")
        tapButton("profile.cta.voteHistory", waitingFor: button("voteHistory.chip.tutte"), "Cronologia dei voti non aperta")
        audit("Cronologia dei voti", viewports: 4)
    }

    // MARK: - Address search + Informazioni e fonti

    /// The two remaining user-reachable screens, neither of them audited
    /// before Phase 32A:
    ///
    /// * `AddressSearchView` with **Roma**, i.e. Phase 30B's multi-collegio
    ///   answer — seven Camera collegi and three Senato ones listed at once,
    ///   the tallest state this screen has.
    /// * `FontiEDatiView`, the app's attribution screen and its legal anchor.
    @MainActor
    func testAccessibilityAuditAddressSearchAndFontiEDati() throws {
        let field = assertExists("home.search.field", "Campo indirizzo in Home non trovato")
        type("Roma", into: field)
        tapButton("home.search.submit", waitingFor: el("addressSearch.field"), "Schermata di ricerca indirizzo non aperta")
        XCTAssertTrue(
            el("addressSearch.results.header").waitForExistence(timeout: Self.timeout),
            "Sezione dei risultati non comparsa"
        )
        audit("Ricerca indirizzo — comune multi-collegio", viewports: 3)

        // Every one of Roma's collegi must be *reachable*, not merely present
        // in the accessibility tree: listing all seven is Phase 30B's whole
        // point, and a result the user cannot scroll to is not listed. The
        // last Senato row is the bottom-most element of the results section.
        let lastSenatoCollegio = el("addressSearch.result.senato.S120004")
        scrollUntilHittable(lastSenatoCollegio)

        relaunch()

        // The footer button is Home's bottom-most control, so it has to be
        // scrolled to before it can be tapped.
        scrollUntilHittable(button("home.footer.fonti"))
        // Waits on the manifest's **first** source card: `FontiEDatiView` is a
        // `List`, which is lazy, so a card below the fold is not in the
        // accessibility tree at all until it is scrolled to.
        tapButton(
            "home.footer.fonti",
            waitingFor: el("fontiEDati.source.camera-dei-deputati-adesioni-gruppi-xix-legislatura"),
            "Schermata Informazioni e fonti non aperta"
        )
        // Bounded at 5 viewports: the screen is nine instances of one
        // `SourceCard`, so further scrolling adds card instances rather than
        // new causes.
        audit("Informazioni e fonti", viewports: 5)

        // The fictional fixture's card used to be asserted here — reachable,
        // and declaring itself invented via the manifest's own `notes`. That
        // row is retired (`tools/make_manifest.py`'s `RETIRED_SOURCE_IDS`), so
        // the assertion has no subject; its replacement is
        // `SchemaV2Tests.testShippingManifestListsNoFictionalSource`, which
        // pins the same guarantee against the manifest the screen renders.
        //
        // What is still worth asserting *here* is that the list ends where the
        // manifest says it does. `senato-…` sorts last of the nine, and the
        // retired id sorts immediately before it, so reaching the last card
        // puts the position the fixture would occupy on screen — which is the
        // only scroll offset where a lazy `List` makes its absence meaningful.
        // Anywhere else, a card below the fold is out of the accessibility
        // tree whether or not it exists, and the check would pass for the
        // wrong reason.
        let lastCard = el("fontiEDati.source.senato-della-repubblica-xix-legislatura")
        scrollUntilHittable(lastCard, maxSwipes: 25)
        XCTAssertFalse(
            el("fontiEDati.source.prototipo-dati-dimostrativi").exists,
            "La scheda della fonte fittizia è ancora elencata in 'Informazioni e fonti'"
        )
    }
}
