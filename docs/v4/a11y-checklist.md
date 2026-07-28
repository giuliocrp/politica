# V4 Accessibility Checklist (Phase 32A)

New file for the V4 surfaces, and for the **triage of every automated
`performAccessibilityAudit()` finding** the cycle produced. The v2 and v3
passes live in [`docs/v2/a11y-checklist.md`](../v2/a11y-checklist.md) and
[`docs/v3/a11y-checklist.md`](../v3/a11y-checklist.md) — referenced, never
edited (frozen history).

Unlike its two predecessors this checklist is **not** a code-inspection
document. Every per-surface line below was exercised by a running
`XCUITest` on an `iPhone 17 Pro` simulator (iOS 26.5) and every finding was
produced by iOS 17's own accessibility auditor. That closes the "verified
by reading the source" limitation the v3 checklist opened with. It does
**not** close the visual and VoiceOver items: those still need a human, and
the honest list is at the bottom.

---

## 0. What changed about the *method*, and why it matters

Phase 24 introduced `performAccessibilityAudit()` over eight screens and
recorded 62 findings. **That inventory covered each screen's first viewport
only** — the auditor walks what is on screen, and Phase 24's audits never
scrolled. Phase 24 met its spec as written; its acceptance criterion 2 is
properly read as *"each screen's initial viewport passes"*. Neither
[`docs/v4/24-ui-tests.md`](24-ui-tests.md) nor `docs/plan/phase-24.md` is
edited here — they are the historical record.

The Phase 31 closeout proved the consequence by accident: scrolling Home to
its footer surfaced a **pre-existing** contrast failure on the "Informazioni
e fonti" button and four `InitialsAvatar` findings on the featured rows,
none of them among the 62.

Phase 32A therefore rebuilt the audits to page through **whole screens**
(`AccessibilityAuditUITests.audit(_:viewports:)`), and added the screens
Phase 24 never reached at all. The measured effect is in §1.

---

## 1. The rebuilt inventory

### 1.1 What the whole-screen audit measures today

Certifying run (`p32a-final3`, `totalTestCount 230 / 0 failures`), 17 audit
calls over **16 distinct screen states**. `Home — piè di pagina` is a
coverage proof, not a screen: it re-audits one viewport of Home to prove the
paged pass reached the bottom, so its findings are a subset of Home's and it
is excluded from the total.

| Screen state | Findings | `.contrast` | `.dynamicType` | `.textClipped` |
|---|---:|---:|---:|---:|
| Dettaglio del collegio — Camera | 27 | 13 | 14 | 0 |
| Home | 25 | 10 | 11 | 4 |
| Dettaglio del collegio — Senato | 22 | 12 | 10 | 0 |
| Ricerca indirizzo — comune multi-collegio ★ | 22 | 21 | 0 | 1 |
| Votazioni | 19 | 18 | 1 | 0 |
| Profilo del rappresentante — deputato con metrica ★ | 17 | 16 | 1 | 0 |
| Cronologia dei voti | 15 | 15 | 0 | 0 |
| Informazioni e fonti ★ | 14 | 4 | 0 | 10 |
| Elenco dei collegi — Camera, plurinominali ★ | 9 | 5 | 0 | 4 |
| Dettaglio del collegio plurinominale — Camera ★ | 8 | 3 | 5 | 0 |
| Elenco dei collegi — Senato, plurinominali ★ | 7 | 5 | 0 | 2 |
| Profilo del rappresentante — senatrice a vita | 6 | 5 | 1 | 0 |
| Elenco dei collegi — Senato, uninominali | 5 | 5 | 0 | 0 |
| Elenco dei collegi — Camera, uninominali | 3 | 3 | 0 | 0 |
| Preferiti | 1 | 0 | 1 | 0 |
| Dettaglio del collegio plurinominale — Senato ★ | **0** | 0 | 0 | 0 |
| **Total** | **200** | **135** | **44** | **21** |
| *(coverage proof, excluded)* Home — piè di pagina | *15* | *6* | *7* | *2* |

★ = a screen state Phase 24 never audited at all.

### 1.2 The corrected count against 62

| Measurement | Screens | Findings |
|---|---:|---:|
| Phase 24, on the Phase 24 tree, **first viewport only** | 8 (9 calls) | **62** |
| Same eight screens, on **today's** tree, first viewport only | 8 (9 calls) | **63** |
| Same eight screens, on today's tree, **whole screen** | 8 | **123** |
| Every screen state, whole screen | **16** | **200** |

Three things follow, and the middle row is what makes them clean:

1. **62 → 63 is the effect of five phases of new content** on the first
   viewport — essentially nothing. The first-viewport number barely moved
   (Home 17 → 17, the Camera collegio page 6 → 6, Preferiti 1 → 1; the
   Senato collegio page 2 → 7 is Phase 26's new regione section, which is
   real new content above the fold).
2. **63 → 123 is the effect of scrolling alone** — same tree, same eight
   screens, same day. Phase 24's inventory captured **51 %** of what those
   screens raise.
3. **123 → 200** adds the seven screen states nobody had audited: both
   plurinominale collegi lists, both plurinominale collegio pages, a Camera
   deputy's profile (the only one that renders Phase 29's metric), the
   comuni disambiguation screen, and the sources screen.

**Previously untraversed: 200 − 63 = 137 findings** — 60 below the fold of
screens Phase 24 did audit, 77 on screen states it never opened.

### 1.3 The count is a lower bound, and it moves between runs

Stated plainly because it decides how much weight the number can carry.

The merge takes, per distinct `"<description>: <label>"` key, the **maximum**
count seen in any single viewport rather than the sum — otherwise two
overlapping viewports would double-count the elements they share. Findings
the auditor cannot attribute to an element all carry the same label (`—`),
so several distinct ones collapse into one key. The count is therefore a
floor, and under-counting is the conservative direction for a claim that the
previous number was too low.

It is also **not stable run to run**, and the cause is that same collapse:
whether the auditor resolves an element to a label varies with timing. An
earlier run of this same code measured **205** total and **139** on
Phase 24's eight screens — because on the two `List`-backed vote screens it
resolved labels (`"Votazione Ordine del giorno 9/2886/3"`, `"22 aprile
2026"`, …) that the certifying run reported as 15 anonymous `—` entries.
Same defects, different arithmetic. **This is why §2 triages by cause**: the
set of causes is stable across every run, and the instance count is not.

---

## 2. Triage — every finding, by cause

Findings are triaged **by cause**, not one row at a time, because the
instance count is viewport- and run-dependent (§1) while the set of causes
is not: all 200 trace to the six causes in §2.1–§2.6. §2.7 records what the
suite still asserts outright, and §2.8 the one exclusion this phase had to
add and the evidence for it.

### 2.1 FIXED — `.tertiary` on an interactive link

`VoteRow` and `VoteEventRow` rendered their "Fonte" link with
`.foregroundStyle(.tertiary)`. `.tertiary` is the system's hierarchy for
*non-essential decoration*; this is a link to the official record of a
vote. Changed to `.secondary` in both.

**Why this one is fixable headlessly and the rest are not:** raising the
foreground hierarchy strictly increases contrast against whatever the real
background turns out to be, so the fix does not depend on resolving the
auditor's background approximation, and it invents no colour — both values
are system semantic styles. **Reported honestly: the auditor still flags
the link after the change**, which is itself evidence for §2.2.

### 2.2 DEFERRED — `.contrast` over `.regularMaterial` (the bulk)

Row text, captions and section headers rendered over `.regularMaterial`:
`RepresentativeRow`, `CollegioRow`, `VoteRow`/`VoteEventRow`,
`ChamberResultGroup`, `StatCard`, the `DisclosureGroup` title, the Home
footer, `SourceCard`.

**The evidence that this is the auditor's background model, not a
foreground defect, is now much stronger than Phase 24 could state.** The
rebuilt inventory contains contrast failures on **`.primary`** text —
`"Angelo Rossi"`, `"Liliana Segre"`, `"Filiberto Zaratti"`, every
collegio name in the address-search result. `.primary` on a system
background is a pairing Apple guarantees; the only variable left is the
translucent material the auditor approximates as opaque. Changing a colour
on that basis would be guessing.

**Deferred to a device-side measurement in both appearances.** This is
`docs/v3/a11y-checklist.md`'s pending item 3, restated with better
evidence rather than inherited.

### 2.3 NO ACTION — `.dynamicType` on `InitialsAvatar`'s two-letter glyphs

Every `Dynamic Type font sizes are unsupported: XX` finding (`AC`, `PC`,
`AV`, `CD`, `LS`, `RC`, `FI`, `AO`, `EC`, `RG`, …) is `InitialsAvatar`'s
deliberate fixed `.font(.system(size: diameter * 0.38))`.

**This is closed, not pending.** The component's own doc comment already
records why: it is decorative, always `accessibilityHidden(true)` at every
call site, and the person's full name sits beside it as real text — so
VoiceOver never reads it and its `minimumScaleFactor` can lose nothing.
Listed rather than suppressed, because a reader comparing the inventory to
this file should find every line accounted for.

### 2.4 DEFERRED — `.dynamicType` / `.textClipped` on the Home stat grid

`StatCard`'s caption inside a two-column `LazyVGrid`: "Camere del
Parlamento", "Collegi uninominali", "Preferiti", plus the Home address
`TextField`. Whether these clip at the largest accessibility sizes is a
visual judgment — `docs/v3/a11y-checklist.md` pending item 2 — and the
auditor only flags candidates. No `lineLimit` truncates them today; the
question is layout at AX5, which needs eyes on a device.

### 2.5 DEFERRED — `.contrast` on system-default control styling

`"Votazioni in Aula (campione)"` is a `.bordered` button and `"Come
funziona l'elezione"` a `DisclosureGroup` title: both use Apple's own
default foreground on Apple's own default background. Phase 24 named these
"the best candidates for an actual fix"; measured, they are the same
material/approximation question as §2.2, and "fixing" them would mean
overriding a system control style on the strength of an approximation.
Deferred with the rest.

### 2.6 DEFERRED — the unresolvable `—` findings

Some findings carry no resolvable element. They occur on `List`-backed
screens, and whether a given run resolves them varies (§1). Nothing can be
triaged individually about a finding whose element is unknown; they are
inside the same row components as §2.2 and share its disposition.

### 2.7 ASSERTED, ZERO ISSUES — hit regions, element descriptions, traits, parent/child

**Zero issues on every audited screen state, including everything only
scrolling reaches.** The handler never returns `true` for these, so any one
of them fails the suite. This is the real result of the v2/v3 accessibility
work, now verified over whole screens rather than first viewports.

### 2.8 The one structural exclusion Phase 32A had to add — and its evidence

Auditing whole screens surfaced a fifth finding class Phase 24's method
could not see: **`.elementDetection`** — *"This element appears to display
text that should be represented using the accessibility API."* It is a
structural type, and Phase 24 asserted it, so downgrading it needed
evidence rather than convenience. Measured before deciding:

| Screen | viewport 1 | 2 | 3 | 4 |
|---|---:|---:|---:|---:|
| Home | **0** | 1 | 1 | 1 |
| Cronologia dei voti | **0** | 3 | 0 | 1 |
| Votazioni | **0** | 0 | 0 | 0 |

- **Zero in any first viewport** — consistent with Phase 24's three green
  runs and with this phase's own first-viewport baseline, neither of which
  ever saw one.
- **Every single one has `issue.element == nil`**: the auditor cannot
  attribute it to any element in the tree, so there is nothing a developer
  could change.
- The failure screenshots explain it: iOS 26 renders the navigation bar and
  the floating `.searchable` field as **translucent material**, and scrolled
  content passes *under* them. The auditor's text detection sees text pixels
  where no accessibility element sits. The row underneath is exposed,
  labelled and reachable — `Votazioni`, which has no `.searchable` bar,
  raises none at all, which is the control case.

**Decision: an `.elementDetection` issue with no attached element is
recorded; one that names an element still fails the suite.** That is
narrower than adding `.elementDetection` to §2.2's set — an image with
baked-in text, or a custom-drawn label, would still break the build. The
honest limitation is stated in the source: a genuine element-detection
defect that the auditor *also* failed to attribute would be recorded rather
than asserted; nothing observed has that shape, and it would still appear
in the inventory.

**A separate harness defect was found and fixed on the way there, not
folded into this.** The first full-suite run failed an `.elementDetection`
assertion whose screenshot showed Home *mid-scroll*, the map CTA passing
under the status bar: `audit(_:viewports:)` was dispatching the auditor
while an inertial scroll was still in flight, so it described a layout that
never rests. `PoliticiUITestCase.waitForScrollToSettle()` now blocks until
the screen stops moving before every audit. That was a real bug in the new
test helper — it reproduced only under parallel simulator clones, where the
animation runs slower — and fixing it did **not** make the failures above go
away, which is how the two causes were told apart rather than conflated.

---

## 3. Per-surface results — the V4 surfaces

Every row was exercised by a running test, not read.

### Phase 24 — the test surface itself

| Surface | Verified how | Result |
|---|---|---|
| All eight v2/v3 screens under the auditor | 9 audit calls, all structural types asserted | ✓ zero structural issues (first viewport) |

### Phase 25 — plurinominale geography

| Surface | Verified how | Result |
|---|---|---|
| `CollegioTypePicker` (map + collegi list) | `selectCollegioType(_:)` drives it **by identifier**, asserting the pinned per-segment labels "Collegi uninominali" / "Collegi plurinominali" | ✓ — and this is its **first** UI-test coverage of any kind; see §4 |
| Plurinominale collegi list, both chambers | Audited as its own screen state after switching the type filter | ✓ zero structural issues |
| Camera plurinominale collegio page (`CP120101`, 8 deputies) | Navigated by identifier, audited across 3 viewports | ✓ zero structural issues |
| Senato plurinominale collegio page (`SP120001`) | Same, 2 viewports — the honest empty state ("Nessun rappresentante collegato in questa versione del prototipo.") | ✓ **zero findings of any kind**, the only screen in the app with a clean sheet |

### Phase 26 — Senato regione context

| Surface | Verified how | Result |
|---|---|---|
| "Senatori proporzionali della regione {name}" section | Inside the audited Senato collegio page; headline + caption are static `Text`, rows are the already-labelled `RepresentativeRow` | ✓ zero structural issues |
| Profile "Regione: {name}" line | Inside `profile.header`'s combined element, audited on a senator profile | ✓ read as part of the header |

### Phase 27 — stratified votes + loading states

| Surface | Verified how | Result |
|---|---|---|
| Votazioni scope line (two lines since Phase 27) | `votazioni.scope` is one combined element; smoke flow 5 asserts a data-driven N | ✓ |
| 30-event list, whole screen | Audited across 4 viewports (was: 12 events, first viewport) | ✓ zero structural issues |
| **Vote loading states** (`votazioni.loading`, `voteHistory.loading`, `profile.votes.loading`) | **Not audited** — the state is transient and resolves before a test can reliably sample it. Identifiers exist; the copy ("Caricamento votazioni…") is a `ProgressView` label | ⚠ **honest gap**, see §5 |

### Phase 29 — the alignment metric

| Surface | Verified how | Result |
|---|---|---|
| `profile.alignment` (value + caption) | **Newly audited.** Phase 24's profile audit only ever opened a *senator's* profile, which has no metric; Phase 32A audits a Camera deputy's (`p300480`) as a second profile state | ✓ zero structural issues; the long caption raises `.contrast` (§2.2) |
| The metric as one VoiceOver element | `.accessibilityElement(children: .combine)` + an explicit `accessibilityLabel` combining value, denominator and caption | ✓ |

### Phase 30/30B — comuni disambiguation UI

| Surface | Verified how | Result |
|---|---|---|
| Multi-collegio result (Roma: 7 Camera + 3 Senato) | **Newly audited**, 3 viewports | ✓ zero structural issues — **after** the defect below was fixed |
| **Reachability of every listed collegio** | `scrollUntilHittable(el("addressSearch.result.senato.S120004"))` | ✗ → ✓ **A real defect, found here and fixed here.** `AddressSearchView` was a non-scrolling `VStack`; Roma's answer overflows the screen, and the audit found the seven Camera collegi on screen with **none of the three Senato ones anywhere in the accessibility tree**. Listing every assigned collegio is the whole point of Phase 30B's name path, and a collegio the user cannot reach is not listed. Now a `ScrollView` |
| Homonym chooser (`addressSearch.candidate.<province>`) | Combined element per candidate, ≥44 pt, own identifier | ✓ unchanged from Phase 30 |
| Provenance caption (name path vs coordinate path) | `addressSearch.results.source`, static `Text` | ✓ |

### Phase 31 — the staleness footer

| Surface | Verified how | Result |
|---|---|---|
| Home footer data-vintage line | Smoke flow 8 asserts the pinned copy and a well-formed Italian long date; the Home audit reaches it by paging, and a subset assertion proves the paged audit covered it | ✓ zero structural issues; `.contrast` on both lines (§2.2) |

### Phase 32A — the sources screen

| Surface | Verified how | Result |
|---|---|---|
| `FontiEDatiView` | **Newly audited**, 5 viewports — the app's attribution screen and legal anchor had never been under the auditor | ✓ zero structural issues |
| Per-source `notes`, newly rendered | Each `SourceCard` is one combined element with its own `fontiEDati.source.<id>` identifier | ✓ |
| The fictional-fixture card declares itself | `AccessibilityAuditUITests` scrolls to `fontiEDati.source.prototipo-dati-dimostrativi` and asserts its label contains *"Dataset interamente fittizio"* | ✓ — the disclosure cannot be lost silently |

---

## 4. Identifier hygiene — the shadowing survey, re-run

`docs/plan/00-baseline-and-rules.md` carried a standing item: re-run
Phase 30B's container-identifier survey whenever a phase touches these
screens, because an `accessibilityIdentifier` on a plain SwiftUI container
**overrides** the identifiers its children set, silently.

Re-run over `Politici/Views/` — **52 call sites** (up from 30B's 48):

| Class | Count | Shadowing risk |
|---|---:|---|
| Leaf / single control (`Text`, `TextField`, `Button`, `Link`, `ProgressView`, `Picker` segment) | 30 | none — nothing identified underneath |
| Container with `.accessibilityElement(children: .combine)` | 10 | none by construction — the container *is* one element |
| `Button` wrapping a single `.combine` child that carries no identifier of its own (the row/stat-card pattern) | 12 | none — the propagated identifier is exactly what makes the row addressable, and it overrides nothing |
| Plain container with identified descendants | **0** | — |

**The two sites 30B flagged as "theoretically yes, not load-bearing" are
gone, fixed rather than re-recorded.** `ChamberPicker` and
`CollegioTypePicker` each carried one identifier on the `Picker`. A
segmented `Picker` is *not* a single accessibility element, so that
identifier was propagating onto **both** segments: `chamber.picker` matched
"Camera" and "Senato" equally and neither was individually addressable.
Each segment now carries its own (`chamber.picker.camera`,
`chamber.picker.senato`, `collegioType.picker.uninominale`,
`collegioType.picker.plurinominale`) and the container identifiers are
removed rather than kept alongside — keeping them would re-create the
shadowing.

Two things follow, and both are improvements the survey was not expecting:

1. `PoliticiUITestCase.selectChamber` no longer reaches segments through
   `app.segmentedControls.firstMatch` — a **positional** lookup on two
   screens that stack *two* segmented controls, i.e. one that silently
   depended on `ChamberPicker` staying on top. The pinned institutional
   label is now **asserted** rather than used as the lookup key.
2. Phase 25's `CollegioTypePicker` gets its first UI-test coverage, which
   is what made §3's four new plurinominale screen states reachable.

---

## 5. Pending human checks (honest enumeration)

None of these can be done headless. Items 1–4 are the v3 checklist's own,
re-stated with what is now automated struck through rather than silently
inherited.

1. **Full VoiceOver traversal on a real device**: element *order*, whether
   the favourites star's state change is *announced* on toggle, whether the
   stats grid is read in declared order, whether the filter chips'
   selected state is announced inside their scrolling header. *(Automated
   since Phase 24: that the elements exist, are reachable, carry the right
   labels/traits, and that no control is swallowed — zero structural audit
   issues over 16 screen states. Announcement and order remain human.)*
2. **Dynamic Type at the largest accessibility sizes** — §2.4 and §2.3.
   The auditor flags candidates; whether the a-vita badge wraps
   acceptably, whether the stat grid clips, whether the tally row survives
   AX5 is a visual judgment.
3. **Measured contrast in light and dark mode** — §2.2, the largest
   deferred class. The auditor's material approximation makes its verdict
   unusable as a basis for changing a colour; a real measurement is the
   only way to close these.
4. **The composed search + chip filtering flow driven entirely by
   VoiceOver** — flow 6 proves the composition works and the list
   re-filters; whether the update is *announced* is human.
5. **Vote loading states** (§3, Phase 27 row) — transient by nature; a
   human can force them by launching with a cold cache and watching.
6. **The `.accessibilityHidden` decorations** (`InitialsAvatar`, chevrons,
   tally icons) are asserted absent from the tree by the audit's zero
   element-detection issues, but whether hiding them *reads* well in a real
   VoiceOver pass is still a judgment.
7. **MapKit polygon overlays remain undiscoverable by VoiceOver** — a
   platform limitation, explicitly deferred for the whole of V4.
   `CollegiListView`, now covering both chambers **and** both collegio
   types, is the accessible path, and every collegio the tests reach is
   reached through it. Not addressed, not addressable, not hidden.
8. **The v2 checklist's standing device-hardware items** remain pending.

## 6. Standing baseline facts, re-verified

- **Zero custom animations** anywhere in `Politici/Views/`
  (`grep -rE "withAnimation|\.animation\(" Politici/Views/` → no matches),
  so Reduce Motion still has nothing to gate. Unchanged since v3.
- **No colour-only information.** Every vote outcome is icon + Italian word
  + a distinct VoiceOver label; the alignment metric is deliberately
  rendered with no colour at all (Phase 29).
- **≥44×44 pt hit targets** on every control the tests tap, and the audit
  raises zero hit-region issues.
