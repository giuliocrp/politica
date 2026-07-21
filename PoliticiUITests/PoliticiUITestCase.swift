//
//  PoliticiUITestCase.swift
//  PoliticiUITests
//
//  Shared launch + navigation plumbing for the Phase 24 UI tests
//  (docs/v4/24-ui-tests.md). Navigation happens exclusively through
//  accessibility identifiers and the app's pinned Italian accessibility
//  labels — never through screen coordinates and never through map polygon
//  taps (MapKit overlays have no accessible representation; CollegiListView
//  is the accessible path, which is exactly what these tests exercise).
//

import XCTest

class PoliticiUITestCase: XCTestCase {

    /// Deliberately generous. These tests run on shared simulator-clone
    /// infrastructure that flaked twice during v3 (Phases 17/18), and a slow
    /// cold launch or a slow first list layout is not a defect. No retry
    /// policy is in place: a failing test is reported as a failure.
    static let timeout: TimeInterval = 30

    /// The ephemeral `UserDefaults` suite the app is asked to keep favorites
    /// in while under UI test (see `UserDefaultsFavoritesStore.uiTestSuite`).
    /// It is wiped by the app at every launch, so each test starts with zero
    /// favorites and none of them can touch a real user's data.
    static let favoritesSuiteName = "PoliticiUITestsFavorites"

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-favoritesSuite", Self.favoritesSuiteName]
        app.launch()
        XCTAssertTrue(
            app.staticTexts["home.title"].waitForExistence(timeout: Self.timeout),
            "La schermata Home non è comparsa dopo il lancio"
        )
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Element lookup

    /// Identifier lookup that doesn't presume the element type SwiftUI
    /// produced: a combined `.accessibilityElement(children: .combine)`
    /// container is an `other`, a `Button` is a `button`, a bare `Text` is a
    /// `staticText`, and which one a given view yields is an implementation
    /// detail these tests should not encode. `firstMatch` because SwiftUI
    /// mirrors one identifier onto both a wrapper element and the control
    /// inside it (observed on the profile's toolbar star), and the two carry
    /// the same label — so reading either is equivalent, while an exact
    /// single-element query would fail as ambiguous. Use `button(_:)` for
    /// anything that gets tapped.
    func el(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Buttons are looked up in the `.button` query specifically: SwiftUI
    /// mirrors an identifier onto both a wrapper element and the control
    /// inside it, and only the control is reliably hittable.
    func button(_ identifier: String) -> XCUIElement {
        app.buttons.matching(identifier: identifier).firstMatch
    }

    @discardableResult
    func assertExists(_ identifier: String, _ message: String, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let element = el(identifier)
        XCTAssertTrue(element.waitForExistence(timeout: Self.timeout), message, file: file, line: line)
        return element
    }

    /// Waits for a button to exist *and* become hittable, then taps it.
    /// Existence alone is not enough: a button can be in the tree while the
    /// screen is still laying out, and a tap dispatched then is silently
    /// dropped (observed as a lost first navigation tap).
    func tapButton(_ identifier: String, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        let element = button(identifier)
        XCTAssertTrue(element.waitForExistence(timeout: Self.timeout), message, file: file, line: line)
        let deadline = Date().addingTimeInterval(5)
        while !element.isHittable && Date() < deadline { _ = element.waitForExistence(timeout: 0.5) }
        element.tap()
    }

    /// Taps a button that is expected to push a screen, and waits for
    /// something on that screen.
    ///
    /// The tap is re-issued **once** if nothing was pushed and the button is
    /// still on screen. This retries a lost navigation tap, never a failed
    /// assertion — no assertion in this suite is retried, and a second lost
    /// tap fails the test. It exists because SwiftUI drops a tap dispatched
    /// while the source screen is still laying out; both retry policies in
    /// this suite are recorded in docs/v4/24-ui-tests.md rather than applied
    /// silently.
    func tapButton(
        _ identifier: String,
        waitingFor target: XCUIElement,
        _ message: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        tapButton(identifier, "\(message) (pulsante '\(identifier)' non trovato)", file: file, line: line)
        if !target.waitForExistence(timeout: 10), button(identifier).exists {
            button(identifier).tap()
        }
        XCTAssertTrue(target.waitForExistence(timeout: Self.timeout), message, file: file, line: line)
    }

    /// The inline navigation-bar title currently displayed.
    var navigationTitle: String {
        app.navigationBars.staticTexts.firstMatch.label
    }

    // MARK: - Navigation

    /// The system back button. Addressed by its stable `BackButton`
    /// identifier rather than by position: on a screen whose `.searchable`
    /// field is active the navigation bar carries other buttons too, and
    /// "the first one" is then not the back button.
    var backButton: XCUIElement {
        app.navigationBars.buttons["BackButton"].firstMatch
    }

    /// Pops one level.
    ///
    /// Only ever called from a screen that has no `.searchable` field in the
    /// stack below it. On iOS 26 a `.searchable` list that has been searched
    /// re-enters search mode when it is popped back to — the field takes
    /// keyboard focus, moves to the bottom of the screen, and the navigation
    /// bar (back button included) disappears from the accessibility tree
    /// entirely. Rather than fight that with gestures or coordinates — which
    /// the phase forbids — every flow is arranged so that returning to Home
    /// is either a single pop from a search-free screen or a `relaunch()`.
    /// Documented in docs/v4/24-ui-tests.md.
    func goBack(file: StaticString = #filePath, line: UInt = #line) {
        let back = backButton
        XCTAssertTrue(back.waitForExistence(timeout: Self.timeout), "Pulsante indietro non trovato", file: file, line: line)
        back.tap()
    }

    /// Returns to a clean Home by relaunching. Wipes the ephemeral favorites
    /// suite as a side effect (the app does that at launch), so it is never
    /// used mid-way through the favorites flow.
    func relaunch(file: StaticString = #filePath, line: UInt = #line) {
        app.launch()
        XCTAssertTrue(
            app.staticTexts["home.title"].waitForExistence(timeout: Self.timeout),
            "La Home non è comparsa dopo il rilancio", file: file, line: line
        )
    }

    /// Single pop back to Home, asserting we arrived.
    func goBackToHome(file: StaticString = #filePath, line: UInt = #line) {
        goBack(file: file, line: line)
        XCTAssertTrue(
            app.staticTexts["home.title"].waitForExistence(timeout: Self.timeout),
            "Non è stato possibile tornare alla Home", file: file, line: line
        )
    }

    @discardableResult
    func openCollegiList(file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let search = app.searchFields["Cerca per nome o circoscrizione/regione"]
        tapButton("home.stat.collegi", waitingFor: search, "Campo di ricerca dei collegi non trovato", file: file, line: line)
        return search
    }

    @discardableResult
    func openRepresentativeList(file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let search = app.searchFields["Cerca per nome"]
        tapButton("home.stat.rappresentanti", waitingFor: search, "Campo di ricerca dei rappresentanti non trovato", file: file, line: line)
        return search
    }

    func type(_ text: String, into field: XCUIElement) {
        field.tap()
        field.typeText(text)
    }

    /// Selects a chamber on the shared `ChamberPicker`, addressing the
    /// segment by the full institutional accessibility label pinned in v3
    /// (docs/v3/a11y-checklist.md) rather than by its short visible title.
    func selectChamber(_ label: String) {
        let picker = app.segmentedControls.firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: Self.timeout), "Selettore della camera non trovato")
        let segment = picker.buttons[label]
        XCTAssertTrue(segment.waitForExistence(timeout: Self.timeout), "Segmento '\(label)' non trovato")
        segment.tap()
    }

    /// Opens the profile of the first representative row on the current
    /// screen, whichever representative that is — the flows assert the
    /// screen's structure, not a particular person's identity, except where
    /// the phase spec explicitly requires a named one.
    func openFirstRepresentativeRow(file: StaticString = #filePath, line: UInt = #line) {
        let rows = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "representative.row.")
        )
        let first = rows.element(boundBy: 0)
        XCTAssertTrue(first.waitForExistence(timeout: Self.timeout), "Nessuna riga di rappresentante trovata", file: file, line: line)
        let profile = el("profile.header")
        first.tap()
        if !profile.waitForExistence(timeout: 10), first.exists { first.tap() }
        XCTAssertTrue(profile.waitForExistence(timeout: Self.timeout), "Profilo non aperto dalla riga del rappresentante", file: file, line: line)
    }

    // MARK: - Label parsing

    /// The first integer appearing anywhere in an accessibility label.
    /// Used for the Home stat cards, whose value and caption are merged into
    /// one combined element: neither the join order nor the separator is
    /// part of any contract this test should assert on — only that a number
    /// derived from the data is present, and how it changes.
    static func firstInteger(in label: String) -> Int? {
        guard let range = label.range(of: "[0-9]+", options: .regularExpression) else { return nil }
        return Int(label[range])
    }

    static func matches(_ label: String, pattern: String) -> Bool {
        label.range(of: pattern, options: .regularExpression) != nil
    }
}
