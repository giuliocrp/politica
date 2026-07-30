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

    /// Launch arguments every UI test runs with.
    ///
    /// `-stubAddressResolver 1` swaps `GeocodingService`'s `CLGeocoder` tier
    /// for one that resolves nothing, instantly (Phase 30B —
    /// `GeocodingService.uiTestPrimaryResolver()`). It is what finally bounds
    /// flow 7's wait, open since Phase 24: the live `CLGeocoder` attempt was
    /// measured taking ~1 s to >120 s to fail on a simulator with no route
    /// out, which is why that flow carried a 300 s ceiling. Nothing in this
    /// suite asserts a `CLGeocoder`-derived result, so removing the network
    /// from the tests changes no expectation — only how long they can take.
    /// The seam is DEBUG-only and inert unless passed; no production timeout
    /// was introduced.
    static let launchArguments = [
        "-favoritesSuite", favoritesSuiteName,
        "-stubAddressResolver", "1",
    ]

    var app: XCUIApplication!

    /// The element every "are we on Home?" gate waits for.
    ///
    /// Was `home.title` — Home's `largeTitle` heading — until that
    /// introductory header was removed. The address field replaces it as the
    /// first thing on the screen, and it is just as good a marker: it appears
    /// on Home and on no other screen (`AddressSearchView`'s own field is
    /// `addressSearch.field`). Looked up through `el(_:)` rather than as a
    /// `staticTexts[…]` so the gate doesn't encode which element type SwiftUI
    /// produces for a `TextField`, for the reason `el(_:)` documents below.
    var homeMarker: XCUIElement { el("home.search.field") }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += Self.launchArguments
        app.launch()
        XCTAssertTrue(
            homeMarker.waitForExistence(timeout: Self.timeout),
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

    /// Scrolls the screen's main scrollable container until `element` both
    /// exists and is hittable.
    ///
    /// Needed for content below the fold — `HomeView` is a `ScrollView`, so
    /// its footer exists in the accessibility tree from launch but is not
    /// hittable, and `performAccessibilityAudit` never traverses it, until it
    /// is scrolled into view. `swipeUp()` is a gesture sent to a real,
    /// identified element, so this stays inside the suite's rule against
    /// screen coordinates; it is not a retry of any assertion.
    ///
    /// Existence is re-checked **inside** the loop rather than required up
    /// front (Phase 32A): a `List` is lazy, so a row below the fold is not in
    /// the accessibility tree at all until scrolling brings it near — which is
    /// how `FontiEDatiView`'s later source cards behave. A `ScrollView`'s
    /// children do exist from the start, so both cases go through one loop.
    @discardableResult
    func scrollUntilHittable(
        _ element: XCUIElement,
        maxSwipes: Int = 8,
        file: StaticString = #filePath, line: UInt = #line
    ) -> XCUIElement {
        _ = element.waitForExistence(timeout: 2)
        var swipes = 0
        while !(element.exists && element.isHittable) {
            guard swipes < maxSwipes, let scrollable = mainScrollable() else { break }
            scrollable.swipeUp()
            swipes += 1
            _ = element.waitForExistence(timeout: 1)
        }
        XCTAssertTrue(
            element.exists,
            "Elemento da raggiungere con lo scorrimento non trovato dopo \(swipes) scorrimenti",
            file: file, line: line
        )
        XCTAssertTrue(
            element.isHittable,
            "Elemento ancora non raggiungibile dopo \(swipes) scorrimenti", file: file, line: line
        )
        return element
    }

    /// The screen's **main** scrollable container, or `nil` when nothing on
    /// screen scrolls.
    ///
    /// Chosen by largest frame area across the three container types SwiftUI
    /// actually produces — `ScrollView` → `scrollView`, `List` →
    /// `table`/`collectionView` depending on style and OS — rather than by
    /// picking `app.scrollViews.firstMatch`. Two screens make that necessary:
    /// `VoteHistoryView` puts a *horizontal* chip `ScrollView` inside its list
    /// header, and `AddressSearchView` has one for its sample-city chips.
    /// Swiping up on either does nothing, so "first scroll view" would
    /// silently stop paging. Largest-area picks the full-screen container in
    /// both cases.
    func mainScrollable() -> XCUIElement? {
        var best: XCUIElement?
        var bestArea: CGFloat = 0
        for query in [app.scrollViews, app.tables, app.collectionViews] {
            for element in query.allElementsBoundByIndex where element.exists {
                let frame = element.frame
                let area = frame.width * frame.height
                if area > bestArea {
                    bestArea = area
                    best = element
                }
            }
        }
        return best
    }

    /// Blocks until the screen stops moving, or `timeout` elapses.
    ///
    /// `swipeUp()` returns when the *gesture* ends, not when the inertial
    /// scroll it started has settled — so anything that samples the screen
    /// immediately afterwards can see a layout that never rests. That is not
    /// hypothetical: the Phase 32A full-suite run caught
    /// `performAccessibilityAudit` mid-scroll and raised a real
    /// `.elementDetection` issue ("This element appears to display text that
    /// should be represented using the accessibility API") against Home's map
    /// CTA as it passed under the status bar. The attached screenshot shows
    /// the two overlapping. It reproduced only under parallel simulator
    /// clones, where the animation runs slower — i.e. exactly the conditions
    /// a full run has and a single-test re-run does not.
    ///
    /// Settling is detected by polling a probe element's frame until two
    /// consecutive samples agree. This is a wait, not a retry: no assertion
    /// is re-evaluated, and a screen that never settles simply proceeds after
    /// `timeout` rather than failing here.
    func waitForScrollToSettle(timeout: TimeInterval = 5) {
        guard let scrollable = mainScrollable() else { return }
        let probe = scrollable.descendants(matching: .any).firstMatch
        var previous = CGRect.null
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let current = probe.exists ? probe.frame : .null
            if current == previous && current != .null { return }
            previous = current
            _ = XCTWaiter.wait(for: [XCTestExpectation(description: "assestamento")], timeout: 0.2)
        }
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
            homeMarker.waitForExistence(timeout: Self.timeout),
            "La Home non è comparsa dopo il rilancio", file: file, line: line
        )
    }

    /// Single pop back to Home, asserting we arrived.
    func goBackToHome(file: StaticString = #filePath, line: UInt = #line) {
        goBack(file: file, line: line)
        XCTAssertTrue(
            homeMarker.waitForExistence(timeout: Self.timeout),
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

    /// Taps one segment of a shared segmented picker **by its own
    /// identifier**, and asserts it still carries the pinned institutional
    /// VoiceOver label.
    ///
    /// Until Phase 32A the two pickers carried a single identifier on the
    /// *container* (`chamber.picker` / `collegioType.picker`), which SwiftUI
    /// propagates onto every child — so both segments answered to the same
    /// identifier and neither was individually addressable, and the helper
    /// below had to reach segments through `app.segmentedControls.firstMatch`
    /// plus the label. "First segmented control" is positional, and both
    /// screens that host these pickers show *two* of them stacked, so that
    /// lookup silently depended on `ChamberPicker` staying on top. Addressing
    /// each segment by its own identifier removes both problems; the label is
    /// asserted rather than used for lookup, so the v3 accessibility contract
    /// is still tested.
    func selectSegment(
        _ identifier: String,
        expectedLabel: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let segment = app.buttons.matching(identifier: identifier).firstMatch
        XCTAssertTrue(
            segment.waitForExistence(timeout: Self.timeout),
            "Segmento '\(identifier)' non trovato", file: file, line: line
        )
        XCTAssertEqual(
            segment.label, expectedLabel,
            "Etichetta VoiceOver inattesa sul segmento '\(identifier)'", file: file, line: line
        )
        segment.tap()
    }

    /// Selects a chamber on the shared `ChamberPicker`, keeping the full
    /// institutional label pinned in v3 (docs/v3/a11y-checklist.md) as the
    /// asserted contract rather than as the lookup key.
    func selectChamber(_ label: String, file: StaticString = #filePath, line: UInt = #line) {
        let identifier = label == "Camera dei Deputati"
            ? "chamber.picker.camera"
            : "chamber.picker.senato"
        selectSegment(identifier, expectedLabel: label, file: file, line: line)
    }

    /// Selects a collegio type on the shared `CollegioTypePicker` — Phase 25's
    /// plurinominale layer filter, which no UI test addressed at all before
    /// Phase 32A.
    func selectCollegioType(_ label: String, file: StaticString = #filePath, line: UInt = #line) {
        let identifier = label == "Collegi uninominali"
            ? "collegioType.picker.uninominale"
            : "collegioType.picker.plurinominale"
        selectSegment(identifier, expectedLabel: label, file: file, line: line)
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
