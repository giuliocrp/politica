//
//  AccessibilityAuditUITests.swift
//  PoliticiUITests
//
//  iOS 17 `performAccessibilityAudit()` runs over every screen the app can
//  reach without a map tap (Phase 24 — docs/v4/24-ui-tests.md). These
//  automate the mechanically checkable part of docs/v3/a11y-checklist.md;
//  the checklist's remaining human items (real-device VoiceOver traversal,
//  Dynamic Type visual judgment, measured contrast) stay human, and the
//  report says so rather than implying this file replaced them.
//

import XCTest

final class AccessibilityAuditUITests: PoliticiUITestCase {

    /// The three audit types this suite records instead of failing on.
    ///
    /// **They are not claimed to be false positives.** A discovery run with
    /// the handler wide open (documented finding-by-finding in
    /// docs/v4/24-ui-tests.md §5) showed that on every screen audited here
    /// the app raises issues of *only* these three types, and that all of
    /// them land on exactly the questions docs/v3/a11y-checklist.md already
    /// records as still needing a human:
    ///
    /// * `.contrast` — measured contrast in light and dark mode was never
    ///   done on-device in v3 (checklist pending item 3). Most of the hits
    ///   are `.secondary`/`.tertiary` text over `.regularMaterial`, which the
    ///   auditor evaluates against an opaque approximation of a translucent
    ///   background; deciding each one needs a real measurement, and acting
    ///   on it needs foreground-style edits that Phase 24's identifier-only
    ///   diff scope excludes.
    /// * `.dynamicType` and `.textClipped` — "Dynamic Type at the largest
    ///   accessibility sizes" is checklist pending item 2, a visual judgment.
    ///   The `.dynamicType` hits on two-letter avatar glyphs are the
    ///   deliberate fixed `.font(.system(size:))` in `InitialsAvatar`, whose
    ///   own doc comment explains why that is safe (it is decorative and
    ///   `accessibilityHidden`, and the name is real text beside it).
    ///
    /// Every other audit type — element detection, hit regions, element
    /// descriptions, traits, parent/child relationships — is asserted, and
    /// the app raises zero issues of any of them on every screen below. This
    /// is a per-type exclusion with a written cause, not a blanket ignore:
    /// the handler never returns `true` for anything outside this set.
    ///
    /// The full inventory of what the three recorded types currently flag is
    /// in the phase report and is handed to Phase 32A (docs, a11y, release).
    private static let recordedForHumanJudgment: XCUIAccessibilityAuditType =
        [.contrast, .dynamicType, .textClipped]

    /// Runs the audit on whatever is currently on screen.
    ///
    /// The auditor has its own internal time budget and reports
    /// `accessibilityAudit` error `-56` ("Audit failed to complete in time")
    /// on the densest screen here — the Camera collegio page, which carries
    /// one uninominale row plus fifteen plurinominale rows. That single,
    /// narrow case is retried **once**: the retry is for the auditor failing
    /// to finish, never for an audit that finished and found something. A
    /// second timeout fails the test, and no other error is retried. This is
    /// the only retry policy in the suite and it is recorded in
    /// docs/v4/24-ui-tests.md rather than applied silently.
    private func audit(_ screen: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTContext.runActivity(named: "Audit di accessibilità — \(screen)") { activity in
            var recorded: [String] = []
            let handler: (XCUIAccessibilityAuditIssue) -> Bool = { issue in
                guard Self.recordedForHumanJudgment.contains(issue.auditType) else { return false }
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
            // Kept even on success: this attachment *is* the inventory of
            // what the three recorded types currently flag, and the phase
            // report quotes it. `.deleteOnSuccess` (the default) would throw
            // away the evidence exactly when the suite is green.
            let attachment = XCTAttachment(string: recorded.isEmpty ? "(nessun rilievo)" : recorded.joined(separator: "\n"))
            attachment.name = "audit-\(screen)"
            attachment.lifetime = .keepAlways
            activity.add(attachment)
        }
    }

    @MainActor
    func testAccessibilityAuditHomeAndCollegiList() throws {
        audit("Home")

        // Phase 31 closeout: Home is a `ScrollView` and its footer — which now
        // carries the data-vintage line — sits below the fold, so the audit
        // above has never traversed it (not before this phase either). Scroll
        // it into view and audit again, so the recorded inventory covers the
        // whole screen rather than only its first viewport. The relaunch puts
        // Home back at the top for the rest of the flow; this test touches no
        // favorites, so wiping the ephemeral suite is harmless here.
        scrollUntilHittable(button("home.footer.fonti"))
        audit("Home — piè di pagina")
        relaunch()

        openCollegiList()
        audit("Elenco dei collegi — Camera")
        selectChamber("Senato della Repubblica")
        audit("Elenco dei collegi — Senato")
    }

    @MainActor
    func testAccessibilityAuditDistrictDetailBothChambers() throws {
        let search = openCollegiList()
        type("Lazio 1 - U01", into: search)
        tapButton("collegio.row.120101", waitingFor: el("district.section.plurinominale"), "Pagina del collegio Camera non aperta")
        audit("Dettaglio del collegio — Camera")

        relaunch()

        let senatoSearch = openCollegiList()
        selectChamber("Senato della Repubblica")
        type("Lazio - U01", into: senatoSearch)
        tapButton("collegio.row.S120001", waitingFor: el("district.header"), "Pagina del collegio Senato non aperta")
        audit("Dettaglio del collegio — Senato")
    }

    @MainActor
    func testAccessibilityAuditProfileAndPreferiti() throws {
        // A life senator's profile, so the audit sees the long a-vita badge
        // the v3 checklist flagged as the riskiest element on this screen.
        let nameSearch = openRepresentativeList()
        type("Segre", into: nameSearch)
        tapButton("representative.row.s32435", waitingFor: el("profile.header"), "Profilo del rappresentante non aperto")
        audit("Profilo del rappresentante")

        relaunch()

        // Preferiti needs a starred representative, and the star must survive
        // the trip back to Home — so this half goes through Home's featured
        // list, keeping the stack free of `.searchable` screens (see
        // `goBack`).
        tapButton("representative.row.p200291", waitingFor: button("profile.favorite"), "Profilo del rappresentante in evidenza non aperto")
        tapButton("profile.favorite", "Stella dei preferiti non trovata")
        goBackToHome()
        tapButton("home.stat.preferiti", waitingFor: el("representative.row.p200291"), "Elenco dei preferiti non aperto")
        audit("Preferiti")
    }

    @MainActor
    func testAccessibilityAuditVotazioniAndVoteHistory() throws {
        tapButton("home.cta.votazioni", waitingFor: el("votazioni.scope"), "Elenco delle votazioni non aperto")
        audit("Votazioni")

        goBackToHome()

        let nameSearch = openRepresentativeList()
        type("Giachetti", into: nameSearch)
        tapButton("representative.row.p300480", waitingFor: button("profile.cta.voteHistory"), "Profilo del deputato non aperto")
        tapButton("profile.cta.voteHistory", waitingFor: button("voteHistory.chip.tutte"), "Cronologia dei voti non aperta")
        audit("Cronologia dei voti")
    }
}
