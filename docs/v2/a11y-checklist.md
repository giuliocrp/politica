# v2 Phase 11 — Accessibility Pass

## Audit (before any change)

Inspected every view under `Politici/Views/` for existing accessibility
support (`grep -rn "accessibility" Politici/Views/`):

| View | Accessibility present before this phase |
|---|---|
| `HomeView` | One `.accessibilityLabel` (the info toolbar button). Nothing else. |
| `MapView` | **None at all.** District selection is a raw `SpatialTapGesture` on the `MapReader`/`Map` — there is no way to discover or select a collegio's polygon with VoiceOver; MapKit overlays aren't exposed as individually swipeable accessibility elements this way. This is the single biggest gap in the app and the reason `CollegiListView` (step 4) exists. |
| `AddressSearchView` | None. |
| `DistrictDetailView` / `RepresentativeRow` | None. |
| `RepresentativeProfileView` | None. |
| `VoteHistoryView` / `VoteRow` / `VoteBadge` | None. `VoteBadge` is text-only (the choice's Italian word, e.g. "Favorevole", color-coded) — the word itself already conveys the vote to a sighted reader, but there's no icon for at-a-glance/colorblind-friendly recognition, and no distinct accessibility label from the visible text. |
| `RepresentativeListView` | None (this view is new as of Phase 10). |
| `FontiEDatiView` | None. |
| `ContentView` / `AppRoute` | N/A — pure navigation plumbing. |

**Reusable components found** (relevant because fixing them once fixes every
call site): `RepresentativeRow` + `InitialsAvatar` (`DistrictDetailView.swift`,
reused by `HomeView`, `RepresentativeListView`, and `DistrictDetailView`
itself), `VoteRow` + `VoteBadge` (`VoteHistoryView.swift`, reused by
`RepresentativeProfileView`), `BulletRow` (`FontiEDatiView.swift`, reused by
`HomeView`).

**No `CollegiListView` or any map alternative existed.** Confirmed via
`grep -rln "CollegiListView\|Sfoglia come elenco" Politici/` (no matches)
before this phase.

**No custom animations exist anywhere in `Politici/Views/`**
(`grep -rn "withAnimation\|\.animation(" Politici/Views/` — no matches), so
there was nothing to gate behind Reduce Motion. Noted rather than invented.

**Dynamic Type**: `grep -rn "lineLimit\|truncationMode\|minimumScaleFactor"
Politici/Views/` found exactly one hit —
`InitialsAvatar`'s `.minimumScaleFactor(0.7)` on its 2-letter initials text.
No `.lineLimit()` truncation exists anywhere, so no text was actually being
cut off before this phase; the avatar's fixed-size circle was the one place
fighting Dynamic Type instead of deferring to it.

## What was fixed

### Vote badges — non-color-only (step 2)

`VoteBadge` (`VoteHistoryView.swift`) now renders an SF Symbol + the
existing Italian word via `Label`, and carries an explicit
`accessibilityLabel` distinct from what's visually printed:

| `VoteChoice` | symbol | visible text (unchanged) | `accessibilityLabel` |
|---|---|---|---|
| `.favorevole` | `checkmark` | "Favorevole" | "Voto favorevole" |
| `.contrario` | `xmark` | "Contrario" | "Voto contrario" |
| `.astenuto` | `minus` | "Astenuto" | "Astenuto" |
| `.assente` | `slash.circle` | "Assente" | "Assente" |
| `.sconosciuto` | `questionmark` | "Sconosciuto" | "Esito non disponibile" |

The vote's pass/fail outcome (`VoteResult`, a separate concept from the
per-deputy `VoteChoice` badge) already paired its checkmark/xmark icon with
literal text ("Esito: Approvato"/"Esito: Respinto"), so it wasn't
color-only either — its icon is now marked `.accessibilityHidden(true)`
since the adjacent text fully conveys the same information and doubling it
up would be noise for VoiceOver, not missing information.

### VoiceOver (step 3)

- `RepresentativeRow`: whole row now `.accessibilityElement(children:
  .combine)` (reads as one "Nome, PartitoBreve" block instead of two
  separate swipe stops), `InitialsAvatar` and the trailing chevron marked
  `.accessibilityHidden(true)` (purely decorative once the row has a real
  label), and an `.accessibilityHint("Apre il profilo del rappresentante")`
  on the combined element — inherited by every Button that wraps a
  `RepresentativeRow` (Home's featured list, `RepresentativeListView`,
  `DistrictDetailView`'s representative section) without repeating the hint
  string three times.
- `VoteRow`: the static info block (title/date/badge/esito) is one combined
  element; the "Fonte" `Link`, when present, is deliberately **left outside
  the combine** as its own element — combining a container that has a
  nested interactive control (a `Link`/`Button`) would swallow that
  control's own tap target from VoiceOver's swipe navigation, not just
  merge its text. Gave it an explicit `accessibilityLabel("Fonte
  ufficiale")` and `accessibilityHint("Apre la scheda della votazione sul
  sito della Camera dei Deputati")` so it doesn't just read the terse
  visible "Fonte".
- `DistrictDetailView`'s header (collegio name + chamber label) and
  `RepresentativeProfileView`'s header (name, party, group, provenance,
  attendance, chamber — none of which are individually interactive)
  combined into one coherent block each, instead of 4–7 separate swipe
  stops for what's read together as a summary anyway.
- `HomeView`'s `StatCard` combined (`"147, Collegi campione"` etc. as one
  element instead of two).
- `RepresentativeListView`'s `PartyFilterChip` gets a proper selection-state
  label: `.accessibilityLabel("Filtra per \(label)")` +
  `.accessibilityAddTraits(isSelected ? .isSelected : [])`, so VoiceOver
  announces which filter is currently active, not just the bare party name.
- `AddressSearchView`'s autocomplete suggestion rows combined
  (title+subtitle as one block); the search field and icon-only submit
  button both got explicit labels/hints; the error banner's warning icon
  hidden (decorative, the text already states the problem).
- `FontiEDatiView`'s `SourceCard` combined (name/license/date as one block);
  its "Apri la fonte" link and the shared `Link` pattern in `VoteRow` both
  got a hint clarifying they leave the app.
- `MapView`'s legend dots marked `.accessibilityHidden(true)` (the adjacent
  text already names the chamber; the dot is pure color coding with no
  independent meaning to state).
- Every previously icon-only interactive control (the search field's
  trailing arrow button, `HomeView`'s and `MapView`'s toolbar/utility
  buttons) now has an explicit Italian `accessibilityLabel`.

### Map alternative — `CollegiListView` (step 4)

New `Views/CollegiListView.swift`: a searchable list of all 147 shipping
Camera collegi (search matches college name or circoscrizione, same
accent/case-insensitive folding pattern as `RepresentativeListView`), each
row showing the collegio name and its circoscrizione, navigating to the
existing `DistrictDetailView` on tap — the same destination `MapView`'s tap
gesture already routes to, so nothing about *what* the app maps changed,
only how a non-map-interaction user reaches the same detail screen.

Entry points added:
- `MapView` gained a `.toolbar` (it had none) with a trailing "Sfoglia come
  elenco" button, always visible regardless of map state.
- `HomeView`'s "Collegi campione" stat card is now tappable too (mirroring
  the existing "Rappresentanti" stat card's navigation to the full list),
  so both of Home's two main datasets are one tap away from a fully
  VoiceOver-navigable list, not just the representatives one.

### Dynamic Type (step 5)

- `InitialsAvatar` marked `.accessibilityHidden(true)` everywhere it's used
  (see "VoiceOver" above) — its `minimumScaleFactor(0.7)` is now purely a
  *visual* fallback for a 2-letter glyph inside a fixed decorative circle
  that VoiceOver never reads from directly; the actual name is always
  available as real, unscaled, wrapping text in the same row/header. No
  information is lost to scaling at any text size.
- Every row/header `Text` in the touched views already had no `lineLimit`
  and wraps by default (confirmed by the audit grep above) — verified this
  stays true after the accessibility edits (no new `lineLimit`/truncation
  introduced).
- Verified visually via `xcrun simctl launch ... -UIPreferredContentSizeCategoryName
  UICTContentSizeCategoryAccessibilityXXXL` (the largest accessibility text
  size) and `...AccessibilityM` (a moderate one, to see more of the screen
  at once) — a real, standard Apple-documented launch-argument override, not
  a guess. At XXXL, `HomeView`'s header text reflows across many lines with
  no truncation or clipping. At the M size, the exact layout flagged as
  higher-risk in the audit — `HomeView`'s 3-card stats `HStack`
  ("Rappresentanti" hyphenates to "Rappresen-tanti", "Camere del
  Parlamento" wraps to two lines) — confirmed wrapping correctly with all
  three values (147/601/2) and full labels legible, nothing truncated or
  cut off.

### Hit targets (step 6)

Audited every custom (non-stock-`Button`-style) tappable control for a
< 44×44pt frame:

| Control | Before | Fix |
|---|---|---|
| `PartyFilterChip` (`RepresentativeListView`) | ~31pt tall (caption text + 8pt vertical padding) | `.frame(minHeight: 44)` + `.contentShape(Rectangle())` on the button — keeps the compact visual capsule, expands the hit-testable area |
| Home/AddressSearch search-field trailing icon button | icon glyph only, no padding | same `.frame(minHeight: 44).contentShape(Rectangle())` treatment |
| `HomeView`'s footer "Informazioni e fonti" link | ~24pt (text + 4pt top padding only) | added bottom padding to reach 44pt |
| `VoteRow`'s "Fonte" link / `FontiEDatiView`'s "Apri la fonte" link | caption-sized text only | same frame+contentShape treatment |
| Sample-city quick buttons (`AddressSearchView`, `.controlSize(.small)`) | below 44pt by design of the control size | same frame+contentShape treatment, visual size unchanged |

Stock `.borderedProminent`/`.bordered` full-width buttons (map CTA, address
search submit, "Vedi dettagli del collegio", "Cronologia completa") and the
navigation-bar toolbar buttons were left as-is — they're already
HIG-compliant by construction (system button styles size their own hit
area beyond the visible glyph), so touching them further wasn't
"practical" (task's own qualifier) — it would just be a no-op.

### Reduce Motion (step 7)

No custom animation exists anywhere in the codebase (see audit). Nothing to
gate; nothing invented for this pass to gate.

### Tests added

`VoteChoice.symbolName`/`.accessibilityLabel` (the mapping `VoteBadge`
renders from) were extracted from private view-local computed properties
into testable properties directly on the `VoteChoice` model
(`Politici/Models/Vote.swift`), and `PoliticiTests/VoteChoiceAccessibilityTests.swift`
asserts every case has a non-empty, mutually distinct symbol and label
(catching, for instance, two cases accidentally sharing a symbol — a
regression that would silently reintroduce color-only distinguishability
for that pair) and pins the exact Italian copy from the task spec.
`PoliticiTests/InitialsTests.swift` already covered `Initials.from(_:)`
(added in Phase 10) — unaffected by this phase's
`.accessibilityHidden(true)` change, since that's a view-level modifier,
not a change to the initials logic itself.

## Remaining limitations (disclosed, not silently dropped)

- **VoiceOver itself cannot be driven from this environment.** There is no
  UI-tap/VoiceOver-gesture automation available in any phase of this
  session (see every prior phase's manual-check section) — everything
  above was implemented from direct SwiftUI Accessibility API knowledge and
  verified by reading the resulting view code, not by actually turning
  VoiceOver on in the simulator and swiping through. The "Manual checks"
  list below is what still needs a human pass.
- `MapView`'s map itself remains fundamentally non-VoiceOver-navigable —
  that's inherent to rendering a `MKPolygon`-based `Map` this way, not
  something fixable within this phase's scope. `CollegiListView` is the
  accessible *alternative path* the task asked for, not a fix to the map
  control itself.
- Dynamic Type was checked visually via a launch-argument override
  (screenshot-based) at two accessibility sizes (M and XXXL) on `HomeView`
  only — I have no swipe/scroll automation in this environment, so I
  couldn't screenshot the rest of `HomeView` below the fold or navigate
  into `RepresentativeListView`/`DistrictDetailView`/
  `RepresentativeProfileView`/`VoteHistoryView`/`FontiEDatiView` to check
  them the same way. Those five are covered by code review only (no
  `lineLimit`, `.frame(width:)`, or other fixed-size constraint on their
  text — see the audit table above), not an actual rendered screenshot.
  This is the same category of gap as VoiceOver below, not a stronger
  claim than what was actually checked.
- Hit-target sizes were computed from the SwiftUI layout code (padding +
  font metrics), not measured pixel-for-pixel in a running instance with
  Accessibility Inspector's target-size overlay.

## Manual checks to perform in Simulator / Accessibility Inspector

1. Enable VoiceOver (Settings → Accessibility → VoiceOver, or Accessibility
   Shortcut) and walk: Home → representative list → profile → vote history;
   Home → map → "Sfoglia come elenco" → district → representative; Fonti e
   dati — confirm every stop reads a complete, sensible Italian phrase and
   that no interactive control (search field, filter chip, Fonte link,
   buttons) is skipped or unreachable.
2. Open Accessibility Inspector, target the running simulator, and run its
   automatic audit on each of the 9 screens (Home, Mappa, Collegi, Cerca
   Indirizzo, Rappresentanti, Dettaglio Collegio, Profilo, Cronologia Voti,
   Fonti e Dati) — it will flag anything missed here (contrast, missing
   labels, hit-target overlays) more precisely than static code review can.
3. Settings → Accessibility → Display & Text Size → Larger Text: drag to
   the maximum accessibility size and re-walk the same flows — confirm
   nothing is clipped or overlapping, especially `HomeView`'s 3-card stats
   row and `RepresentativeListView`'s party filter chips.
4. Settings → Accessibility → Motion → Reduce Motion: toggle on and confirm
   no navigation transition feels different (expected — there's no custom
   animation to differ).
5. Try VoiceOver's rotor "Headings"/"Links" navigation specifically on
   `VoteHistoryView` and `FontiEDatiView` to confirm the "Fonte"/"Apri la
   fonte" links surface correctly as links, separate from their row's
   combined text.
