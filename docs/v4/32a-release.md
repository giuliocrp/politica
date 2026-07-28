# V4 Phase 32A — Documentation, Accessibility Checklist, Release Prep

Release preparation for `v4.0-prototype`. **No tag was created, nothing was
pushed, no GitHub call was made** — the pending-decisions block at the end
(§14) is this phase's terminal output, and Phase 32B acts on it only after
explicit approval.

**Network acts: none.** Everything below was measured locally on
**2026-07-28** against Xcode 26.6 and the `iPhone 17 Pro` simulator
(iOS 26.5). No pipeline script that writes was run, `make manifest` was
deliberately **not** run, and `Politici/Data/` is byte-identical to its
Phase 30B state.

---

## 0. Scope, and where it departs from `phase-32a.md`

The user's additional requirements for this phase are authorized and in
scope, and where they conflict with the phase file they win (stated here per
their instruction):

| Requirement | Where discharged |
|---|---|
| **A** — rebuild the accessibility inventory with scrolling before triaging; report the corrected count against 62; reconcile Phase 24 rather than rewriting it | §2, and [`docs/v4/a11y-checklist.md`](a11y-checklist.md) §0–§1 |
| **B** — verify the full Q1–Q7 ledger; each resolved-with-pointer or explicitly deferred with a named owner | §6 |
| **C** — do the rebuilt triage, the `MapView` picker identifiers, the comuni disambiguation UI, the documentation reconciliation; **decide** the `CLGeocoder` timeout, the per-profile vintage line and sample-fixture visibility; confirm eight items recorded as deferred | §2–§5, §6.2, §7 |
| **D** — baseline 227 measured from the `.xcresult`; post-32A `Data/` total in B/MiB/%; rule 9 sweep; every new or changed Italian string pinned | §1, §9, §8, §10 |

**Two deviations from the phase file, stated plainly:**

1. **The report is `docs/v4/32a-release.md`, not `docs/v4/32-release.md`.**
   The phase file pins the latter (and its acceptance criterion 6 names it);
   the user's instruction for this session pins `docs/v4/32a-<slug>.md`,
   which is also what `docs/plan/README.md`'s per-session prompt template
   produces for a lettered phase and what Phase 30B's `30b-…` report
   established as the convention. The user's instruction wins.
   **`phase-32b.md` says its addendum appends to "`docs/v4/32-release.md`" —
   it means this file**, which the status table links.
2. **Two code changes outside a documentation phase's nominal scope**, both
   defects found *because* this phase audited whole screens and built in
   Release: `AddressSearchView` did not scroll (§4) and `NameFolding` warned
   under Release concurrency checking (§10.4). Both are fixed here rather
   than recorded and left, with the reasoning in place.

---

## 1. Preconditions, and the report set

| Precondition | Verified how | Result |
|---|---|---|
| Every executed phase has a committed report | `ls docs/v4/` — 23, 24, 25, 25a, 26, 27, 28, 29, 30, 30b, 31 all present | **met** — see the table below |
| Working tree clean at start | `git status --porcelain` → empty | **met** |
| Branch / tip | `v4` = `origin/v4` = `f2ab6f2` (Phase 31 closeout) | **met** |
| Tags untouched | `git tag -l` → `v1.0.0`, `v2.0-prototype`, `v3.0-prototype` | **met** — unchanged, and no new tag created |
| Frozen dirs unmodified | `git diff HEAD -- docs/v2 docs/v3 docs/history` → empty | **met** (re-checked at commit, §12) |

### Report-set verification (objective 1)

| Phase | Status in `docs/plan/README.md` | Report | Outcome recorded |
|---|---|---|---|
| 23 | done | `23-baseline-audit.md` | baseline re-verified; **4 hygiene findings, none fixed** (none met the "trivially safe" bar) |
| 24 | done | `24-ui-tests.md` | 7 flows + 4 audits; baseline redefined 136/139 → 144/144 |
| 25 | done | `25-plurinominale-geography.md` | **GO-PLURI: GO** |
| — | side task | `25a-doc-sync.md` | stale-base session's diff **discarded** and re-applied by hand |
| 26 | done | `26-senato-regione.md` | **GO-REG: GO**; `electionType` decision taken with user approval |
| 27 | done | `27-votes-stratified.md` | user-gated network act; **Q3 answered** |
| 28 | done | `28-membership-history.md` | **GO-STORICO: GO**, user-gated network act; **Q4 answered** |
| 29 | done | `29-alignment-metric.md` | gate 6/6; metric ships under explicit user sign-off (**Q7**) |
| 30 | done | `30-comuni-geocoding.md` | **GO-COMUNI: GO**, user-gated acquisition — **no download occurred**; **Q5 answered** |
| 30B | done | `30b-comuni-assignment.md` | **GO-ASSIGN: GO** |
| 31 | done | `31-live-refresh-adr.md` | **live refresh DEFERRED**, decided on measured grounds |

**No gaps.** Every phase in the plan's status table is terminal and links a
committed report; there is no NOT-RUN or NO-GO phase in V4 (Phase 29's
plan-time possibility of NOT RUN did not materialize because Phases 27 and
28 both landed).

### The test baseline, measured from the `.xcresult`

Per requirement D, the 227 baseline was **measured, not inherited**, on the
untouched `f2ab6f2` tree before anything was written:

```
$ xcrun xcresulttool get test-results summary --path p32a-baseline.xcresult
{'result': 'Passed', 'totalTestCount': 227, 'passedTests': 227,
 'failedTests': 0, 'skippedTests': 0, 'expectedFailures': 0}
statistics: []
```

Corroborated from source with the collision-safe occurrence rule: 214 unit
`func test…(` + 1 `@Test` + 12 UI = **227**.

That run also produced **two fresh sightings of the log-truncation quirk**
(230 → §10.1 covers the final numbers; the baseline run showed 227 `Test
case` lines but only 225 ending in `passed`), and one of them widened the
known pattern: the interleaving diagnostic is **not always**
`IDELaunchParametersSnapshot`.

```
Test case 'VoteChoiceAccessi2026-07-28 14:51:04.248 xcodebuild[…]  iOSSimulator: B8DC…: Failed to launch app with identifier: com.giuliocrp.Politici …
Test case 'SmokeFlowUITests.testVoteHistoryOutcomeChipAndTitleSe2026-07-28 14:55:29.612 xcodebuild[…] IDETestOperationsObserverDebug: 361.518 elapsed …
```

Both cut **mid-name**, both tests passed in the `.xcresult`.

**`CLAUDE.md` stops counting sightings, and says why.** Across this phase's
ten `xcodebuild test` runs, **all five full-suite runs truncated a line and
none of the five short single-test runs did** — 8 truncated lines in total,
every one mid-name, every one on a test the `.xcresult` reported as passed:

| run | truncated lines |
|---|---:|
| `p32a-baseline` | 2 |
| `p32a-final` | 1 |
| `p32a-final2` | 2 |
| `p32a-final3` | 2 |
| `p32a-final4` | 1 |
| the five single-test / class-only runs | **0** |

A quirk that fires on every long run is not a rare event to tally; it is a
property of the tool. The rule replaces the count: expect a full run's log
to disagree with the `.xcresult` by one or two lines, don't pattern-match on
the interrupting message, and read the count from the `.xcresult`.

---

## 2. The accessibility inventory, rebuilt (requirement A)

Full detail, per-screen table and per-cause triage are in
[`docs/v4/a11y-checklist.md`](a11y-checklist.md). The headline here.

### 2.1 The premise was correct, and the undercount is measurable

`performAccessibilityAudit()` traverses what is **on screen**. Phase 24
audited each screen once, at its initial scroll position; its 62-finding
inventory is therefore each screen's first viewport, not the screen.

**Phase 24 met its spec as written.** Its acceptance criterion 2 —
"every audited screen passes `performAccessibilityAudit()`" — is properly
read as **"each screen's initial viewport passes"**. Recorded here, as the
requirement directs. **`docs/v4/24-ui-tests.md` and `docs/plan/phase-24.md`
are not edited**: they are the historical record, and the frozen-history
convention says corrections land in living documents.

### 2.2 The corrected count

| Measurement | Screen states | Findings |
|---|---:|---:|
| Phase 24 (its tree, first viewport) | 8 | **62** |
| The same eight screens, today's tree, **first viewport** | 8 | **63** |
| The same eight screens, today's tree, **whole screen** | 8 | **123** |
| **Every screen state, whole screen** | **16** | **200** |

The middle row is the controlled comparison and it is the important one:
**63 → 123 is the effect of scrolling alone**, same tree, same screens, same
day. Phase 24's inventory captured **51 %** of what those eight screens
raise. The 62 → 63 step shows that five phases of new content changed the
first viewport by almost nothing — the growth was all below the fold.

**Previously untraversed: 137 findings** — 60 below the fold of screens
Phase 24 did audit, and 77 on seven screen states it never opened (both
plurinominale collegi lists, both plurinominale collegio pages, a Camera
deputy's profile — the only kind that renders Phase 29's metric — the comuni
disambiguation screen, and the sources screen).

By type across the 16 states: **135 `.contrast`, 44 `.dynamicType`,
21 `.textClipped`**, and **zero** of every other type.

**The number is a lower bound and it moves between runs.** The merge takes
the maximum count per distinct `"description: label"` key across viewports
(summing would double-count what overlapping viewports share), and findings
the auditor cannot attribute all share the label `—`, so distinct ones
collapse. An earlier run of this same code measured **205** / **139**,
because it resolved element labels on the two `List`-backed vote screens
that the certifying run reported as anonymous `—` entries. Same defects,
different arithmetic — which is exactly why the triage is **by cause**.

### 2.3 Triage — the disposition of all 200

| Cause | Disposition |
|---|---|
| `.tertiary` on the "Fonte" link (`VoteRow`, `VoteEventRow`) | **FIXED** → `.secondary`. Raising the hierarchy strictly increases contrast against *any* background, so it needs no measurement; and `.tertiary` is the system's decoration style, not a style for an interactive link |
| `.contrast` on text over `.regularMaterial` (the bulk) | **DEFERRED** to a device-side measurement — with far better evidence than Phase 24 could give: the rebuilt inventory flags **`.primary`** text (`"Angelo Rossi"`, `"Liliana Segre"`, every collegio name in the address result). `.primary` on a system background is a pairing Apple guarantees, so the variable is the auditor's opaque approximation of a translucent material, not the foreground |
| `.dynamicType` on `InitialsAvatar`'s two-letter glyphs | **NO ACTION, closed.** The component is decorative, `accessibilityHidden(true)` at every call site, with the person's name beside it as real text — its own doc comment already settles it. Listed, not suppressed |
| `.dynamicType` / `.textClipped` on the Home stat grid | **DEFERRED** — visual judgment at the largest accessibility sizes (v3 checklist item 2) |
| `.contrast` on system-default control styling (`.bordered` button, `DisclosureGroup` title) | **DEFERRED.** Phase 24 called these the best fix candidates; measured, they are Apple's own foreground on Apple's own background, i.e. the same approximation question |
| Unresolvable `—` findings | **DEFERRED** with the row components they sit in — nothing can be triaged about a finding with no element |

**One fix, five deferrals, one closed** — and the deferrals now carry a
falsifiable reason instead of "needs a human".

### 2.4 A fifth finding class, and the one structural exclusion it forced

Whole-screen auditing surfaced `.elementDetection` issues Phase 24's method
could not see. Because that is a **structural** type Phase 24 asserted,
it was measured before anything was decided:

| Screen | viewport 1 | 2 | 3 | 4 |
|---|---:|---:|---:|---:|
| Home | **0** | 1 | 1 | 1 |
| Cronologia dei voti | **0** | 3 | 0 | 1 |
| Votazioni | **0** | 0 | 0 | 0 |

Zero in any first viewport; **every one has `issue.element == nil`**; and
the failure screenshots show iOS 26's translucent navigation bar and
floating `.searchable` field with scrolled content passing *under* them —
the auditor's text detection seeing text pixels where no element sits.
`Votazioni`, which has no `.searchable` bar, raises none: the control case.

**Decision: an `.elementDetection` issue with no attached element is
recorded; one that names an element still fails the suite.** That is
strictly narrower than adding the type to the recorded set — an image with
baked-in text would still break the build — and the honest limitation (a
genuine unattributable defect would be recorded rather than asserted) is
written into the source. In the certifying run this exclusion recorded
**zero** issues.

**A separate harness defect was found on the way and is not conflated with
it.** The first full-suite run failed an `.elementDetection` assertion whose
screenshot showed Home *mid-scroll*: `audit(_:viewports:)` was dispatching
the auditor while an inertial scroll was still in flight, so it described a
layout that never rests. `waitForScrollToSettle()` now blocks until the
screen stops moving before every audit. Fixing it did **not** make the
`element == nil` findings go away, which is how the two causes were told
apart.

---

## 3. Container-identifier shadowing — survey re-run, and the last two sites fixed

The standing deferred item asked Phase 32A to *re-run* Phase 30B's survey.
It was re-run, and the two sites it had flagged were **fixed rather than
re-recorded**.

52 `accessibilityIdentifier` call sites across `Politici/Views/` (30B: 48):

| Class | Count | Shadowing risk |
|---|---:|---|
| Leaf / single control | 30 | none |
| Container with `.accessibilityElement(children: .combine)` | 10 | none by construction |
| `Button` wrapping one `.combine` child with no identifier of its own | 12 | none — the propagated identifier is what makes the row addressable and overrides nothing |
| **Plain container with identified descendants** | **0** | — |

`ChamberPicker` and `CollegioTypePicker` each carried their identifier on
the `Picker`. **A segmented `Picker` is not a single accessibility
element**, so `chamber.picker` was propagating onto *both* segments: it
matched "Camera" and "Senato" equally and neither was individually
addressable. Each segment now carries its own —
`chamber.picker.camera` / `.senato`,
`collegioType.picker.uninominale` / `.plurinominale` — and the container
identifiers are **removed** rather than kept alongside, since keeping them
would recreate the shadowing. Neither container identifier was referenced by
any test or any other code (verified by grep before removal).

Two consequences, both improvements:

1. `PoliticiUITestCase.selectChamber` no longer reaches segments through
   `app.segmentedControls.firstMatch` — a **positional** lookup on two
   screens that stack *two* segmented controls, which silently depended on
   `ChamberPicker` staying on top. The pinned institutional label
   ("Camera dei Deputati" / "Senato della Repubblica") is now **asserted**
   rather than used as the lookup key, so the v3 accessibility contract is
   still tested.
2. Phase 25's `CollegioTypePicker` — the plurinominale layer filter — gets
   its **first UI-test coverage of any kind**, which is what made the four
   new plurinominale screen states in §2 reachable at all.

---

## 4. A real defect in the comuni disambiguation UI, found and fixed

`AddressSearchView` was a plain `VStack` with no `ScrollView`. Phase 30B
made its tallest state much taller — a comune divided between several
collegi lists **all** of them, and Roma's answer is seven Camera rows plus
three Senato rows under two explanatory paragraphs.

**Measured, not suspected.** The whole-screen audit found Roma's seven
Camera collegi on screen and **none of its three Senato ones anywhere in
the accessibility tree**: `el("addressSearch.result.senato.S120004")`
failed `waitForExistence` outright. The audit's own paging made it worse in
an instructive way — with nothing to scroll, the swipe landed on the
sample-city chips and *changed the search to Napoli*, which is what put the
question beyond doubt.

Phase 30B's flow 7 had passed throughout, because it asserts
`romaCameraCollegi.count > 1` and XCUITest counts tree elements regardless
of reachability — the Camera rows were present, so the assertion held while
the Senato rows were invisible.

**Fixed**: the body is a `ScrollView`, and the audit test now asserts the
**last** Senato collegio is reachable (`scrollUntilHittable`). Listing every
assigned collegio is the whole point of Phase 30B's name path, and a
collegio the user cannot reach is not listed.

`scrollUntilHittable` was generalized as part of this: it re-checks
existence **inside** the scroll loop rather than requiring it up front,
because a `List` is lazy and a row below the fold is not in the tree at all
until scrolling brings it near — which is how `FontiEDatiView`'s later
source cards behave.

---

## 5. Inherited work — every item decided explicitly (requirement C)

### 5.1 Production `CLGeocoder` timeout — **decided: not shipped**

Phase 30B retired UI flow 7's 300 s ceiling test-side with the
`-stubAddressResolver` seam and left the production question here. It is a
real UX trade-off and gets a decision, not an omission.

**Not shipped, for two reasons.**

1. **The measurement that motivates it is a simulator artifact.** The only
   figures on record — ~1 s to >120 s to fail — were measured on a
   **simulator with no route out** (Phase 24 §6.3). No device-side
   measurement of a hang exists. Changing shipping behaviour to fix a
   problem that has only been observed in a test environment is the wrong
   direction, and this session has no device with which to measure one.
2. **A timeout would introduce a silent substitution.** On expiry the query
   falls through to tier 2 (exact comune name) and tier 3 (five-city
   substring), so `"Via del Corso 12, Roma"` would answer with **Roma's
   comune-level point** — and the screen's provenance caption cannot tell
   the two apart: both the address path and the fallback render *"Collegio
   determinato dalla posizione geografica trovata."* That is precisely the
   silent-substitution family Phases 28 (`membershipAt` → nil), 29
   (`insufficientData` carries no number), 30B (every assigned collegio,
   never one) and 31 (disclose the vintage) each refused.

**Re-open together with the disclosure copy** that makes a degraded answer
visible, or on an actual device-side measurement of a hang. Recorded in
`docs/plan/00-baseline-and-rules.md`'s deferred table with that trigger.

### 5.2 Per-profile data-vintage line — **decided: still declined**

Phase 31 §6.2 declined it and pinned it to ADR trigger 2 — *distribution to
people who cannot run `make refresh`*. Re-examined here rather than
inherited: nothing changed the reasoning, and one thing strengthened it —
the profile screen has since gained Phase 29's long alignment caption, so
the clutter cost of a date beside a person's name went **up**. A local
prototype tag does not trip trigger 2. Still declined, still pinned.

### 5.3 Sample-fixture visibility — **decided: made unambiguous**

The manifest's **minimum** `retrievedAt` (2026-07-17) belongs to
`prototipo-dati-dimostrativi`, the fictional v1 fixture — which is exactly
why Phase 31 §7.1 reports the *max*. Confirmed: that entry does have a card
on the user-visible "Informazioni e fonti" screen.

**It was not unambiguously labelled, so it was made so.** The card rendered
only `name`, `Licenza: n/a` and `Dati aggiornati al: 17 luglio 2026` — a
"retrieval" date for a dataset never retrieved from anywhere, with nothing
on screen saying it is invented. The manifest already carries the sentence
that says so, in Italian, maintained by `tools/make_manifest.py` — it simply
**was never rendered**. `SourceCard` now renders `notes` for every source,
so the fixture's card states, in the source's own committed words:

> Dataset interamente fittizio, scritto a mano per dimostrare l'architettura
> dell'app. Non deriva da alcuna fonte esterna e non rappresenta collegi,
> rappresentanti o votazioni realmente esistenti.

**No new user-facing string was invented** (§8), and
`AccessibilityAuditUITests` asserts that sentence reaches the screen, so the
disclosure cannot be lost silently. Note the side effect, recorded because
it changes a standing assumption: the manifest's `notes` are now
**user-visible copy**, so editing one in `make_manifest.py` edits what a
user reads — stated in `docs/DATA_SOURCES.md`'s preamble.

---

## 6. The Q1–Q7 ledger (requirement B)

Each of the seven was checked against
`docs/plan/00-baseline-and-rules.md` **and** against the report it points
at, not just against the plan's own claim.

| Q | Owner | Status | Verified how |
|---|---|---|---|
| Q1 | Phase 25 | **RESOLVED**, pointer present | `25-plurinominale-geography.md` confirms the placeholder-feature hypothesis from feature attributes → 49 Camera / 26 Senato |
| Q2 | Phase 23 | **RESOLVED**, pointer present | `23-baseline-audit.md` §4 exists and answers it: §4.4 `Circo_Camera_2020`, §4.5 `Regioni_Senato_2020`, §4.6 `UT_Collegi2020` (Feature Count 8213). **The requirement's premise that Q2 "has not surfaced anywhere in v4" is outdated** — it was resolved by Phase 23 and the pointer was added to the plan by commit `b6f70b2`, after the requirement list was drafted. No action needed |
| Q3 | Phase 27 | **RESOLVED**, pointer present | `27-votes-stratified.md` §3 |
| Q4 | Phase 28 | **RESOLVED**, pointer present | `28-membership-history.md` |
| Q5 | Phase 30 | **RESOLVED**, pointer present | `30-comuni-geocoding.md` |
| Q6 | — | **DEFERRED past V4, explicitly, owner: the user** | §6.1 |
| Q7 | Phase 29 | **RESOLVED**, pointer present | `29-alignment-metric.md`, with the user's sign-off quoted there |

**Six resolved with a pointer, one explicitly deferred with a named owner
and a reason.** None silently forgotten.

### 6.1 Q6 — the commissioning brief

Re-ran the same search Phases 13 and 23 ran, on today's tree:

```
$ find . -iname "*commission*" -not -path "./.git/*"
./docs/history/HISTORY_PACK_COMMISSIONING_BRIEF.md
./tools/queries/senato_commissioni.rq
./tools/raw/senato_commissioni_sparql.json
$ find . -iname "*brief*" -not -path "./.git/*"
./docs/history/HISTORY_PACK_COMMISSIONING_BRIEF.md
```

Same result, third time: the only brief in the tree is the historical
documentation pack's, whose own header says it is not a V3/V4 architecture
task. **The reason no phase can close Q6 is that the document has never been
provided**, and nothing may be fabricated in its place (constraint #4). It
is therefore recorded as **deferred with an owner — the user** — in the plan
baseline, and carried into the release actions (§14) as a pending decision
rather than quietly dropped at the end of the cycle.

### 6.2 The eight items confirmed as recorded deferrals

Requirement C's "confirm recorded as deferred — do not implement here"
list, checked one by one against
`docs/plan/00-baseline-and-rules.md`'s deferred table. Four were already
there; **four were not, and are added by this phase**:

| Item | Was recorded? |
|---|---|
| `make_manifest.py` fail-loud on an absent `.fetch_metadata.json` | ✓ already recorded |
| Bilingual Italian/German Alto Adige comune names | ✓ already recorded |
| `import_comuni.py`'s last-row-wins name/province collapse | ✓ already recorded |
| Phase 30B's row-reconciliation measurements not promoted to the probe | ✓ already recorded (same entry) |
| UI flow 6's vote-specific anchors re-pin on any `votes.json` change | **added** — was only in a source comment and Phase 27's report |
| Phase 27's stratified selection is deterministic but not stable across refetches | **added** |
| Address-level resolution has no offline path under local-first | **added** |
| Phase 30 §10's `*.sample.*` byte figure is a mis-sum (13,179 → **14,765 B**) | **added**, and marked *corrected, not deferred* — the correction lives in Phase 30B §8 and Phase 31 §1.1; `30-comuni-geocoding.md` is deliberately **not** edited (frozen-history rule) |

None of the eight was implemented here.

---

## 7. Documentation reconciliation

### 7.1 `README.md` — full refresh + stale-line sweep

The sweep's one **materially false** survivor, and the reason the sweep
matters:

> **"`PoliticiUITests` is still unmodified Xcode template boilerplate"** —
> false since Phase 24 (`4bcd006`), i.e. for nine commits and seven phases.
> The README had been shipping a known-untrue limitation for the whole
> cycle.

Replaced with what is actually true: real smoke flows exist, the audits
cover whole screens, every structural audit type is zero across 16 screen
states, and 200 findings in three types are recorded and triaged — a
limitation stated with its size rather than erased. The template target's
flakiness note was rewritten as what it is (simulator-clone infrastructure,
five-plus sightings) rather than as a property of template tests.

Other stale lines found and fixed:

| Line | Was | Now |
|---|---|---|
| Map feature bullet | "all 221 real collegi uninominali" | 296 collegi, both layers, both pickers (Phase 25) |
| `CollegiListView` bullet | "list of all 221 collegi" | 296, layer-aware |
| Services list | 7 services | 9 — `MembershipService` (28) and `ComuneService` (30) were missing |
| "What's real" table | 8 rows | 12 — plurinominale boundaries, plurinominale linkage, memberships, comuni, `electionType`/`regione` were all shipped and unlisted |
| Data-pipeline block | `boundaries` ×2 | ×4 — the two plurinominale targets existed in the `Makefile` and not in the README |
| "generated artifacts" list | 5 files | every file under `Politici/Data/` |
| Project structure | no `PoliticiUITests/`, `docs/plan/`, `docs/v4/`, `docs/releases/` | all four added |
| Roadmap heading | "Roadmap (post-v3)" | post-v4, with a "Shipped in v4" section covering Phases 24–32A |
| Roadmap open item | "Populating senators' `electionType`" listed as open | **closed** by Phase 26, struck through with its numbers |
| Attribution-screen bullet | name, licence, retrieval date | + the provenance note (§5.3) and the Home footer entry point |
| Accessibility bullet | v2 + v3 checklists | + `docs/v4/a11y-checklist.md` |

**Zero survivors**: the classes re-grepped after editing (`221 collegi`,
`12 votes`, `template boilerplate`, service names, `docs/v3` as the newest
report dir) return either nothing or a correct historical attribution
(e.g. "v3 Phase 16", which is a provenance statement, not a stale claim).

### 7.2 `CLAUDE.md`

New "Durable conventions established in v4" section — the eight conventions
this cycle actually established: `CP`/`SP` plurinominale id prefixes;
senator `electionType` populated with `null` only where the source is
silent; half-open membership intervals with `nil` outside coverage; comuni
provenance (assignment cited, geometry not, vintage deliberately pinned);
metric constants never bare numbers in a view; display formatters pinned to
Europe/Rome; the post-Phase-24 test-baseline definition; whole-screen
audits; and the identifier-placement rule. Plus the truncation tally
(seven) and the flake tally (five-plus), both updated with this session's
sightings.

### 7.3 `CHANGELOG.md` + `docs/releases/v4.0-prototype.md`

A `v4.0-prototype` entry, per phase, with the commit hashes quoted from
`git log` and interstitial fixes distinguished from phase commits:

```
3907689 docs(v4): commit V4 master plan …
4f251a3 chore(v4): phase 23 — baseline audit …
4bcd006 test(v4): phase 24 — real UI smoke flows …
15f3f95 feat(v4): phase 25 — plurinominale collegi geography …
7af1dce fix(tools): correct stale Senato uninominale linkage note   ← interstitial
a7d4c71 fix(tools): correct stale Senato Open Data collegio-linkage note ← interstitial
b6f70b2 docs(v4): sync plan baseline (389), a11y deferral handoff … ← side task (25a)
02750b3 feat(v4): phase 26 …            d0b9910 chore(v4): phase 26 review follow-ups
ff1b71b feat(v4): phase 27 …            aa78bfe chore(v4): phase 27 review follow-ups
fe0038a feat(v4): phase 28 …
744d045 feat(v4): phase 29 …            17cc2a7 chore(v4): phase 29 review follow-ups
0e76a75 feat(v4): phase 30 …            5186a51 docs(v4): phase 30 review follow-ups
2768d8a feat(v4): phase 30b …           b5b73a7 docs(v4): phase 30b closeout
e21a236 feat(v4): phase 31 …            f2ab6f2 chore(v4): phase 31 closeout
```

Non-shipping outcomes get honest one-liners rather than being omitted:
Phase 23's four hygiene findings recorded and **not** fixed; Phase 28
shipping infrastructure with **no metric UI**; Phase 30's user-gated
acquisition where **no download occurred**; Phase 31's decision that live
refresh **stays deferred**. The release note reproduces the entry verbatim
and states that CHANGELOG is canonical and the tag does not yet exist.

### 7.4 `docs/DATA_SOURCES.md` + `tools/SOURCES.md`

All 10 manifest entries compared field-by-field against both files:
**no mismatches**. Two V4-introduced drifts fixed:

- `tools/SOURCES.md`'s ISTAT block still described the comuni layer as
  centroids answering name geocoding — superseded by Phase 30B, where the
  published `CU20_COD`/`SU20_COD` assignment answers a name query and the
  centroid serves the coordinate path.
- `docs/DATA_SOURCES.md`'s preamble said the in-app screen "has no room for"
  the transformation detail — no longer true now that `notes` render (§5.3).

One deliberate non-mismatch is recorded so a future automated diff does not
flag it: the fixture's manifest `license` is the literal `"n/a"` while
`DATA_SOURCES.md` writes "N/A (not a real dataset)". A 2026-07-28
cross-check trailer entry records all of this, plus that **no fetch ran, no
entry was added, no `retrievedAt` moved, and `make manifest` was
deliberately not run** (it would have advanced `generatedAt` for no reason).

---

## 8. Pinned Italian strings

**No new user-facing string was invented by this phase**, and that is a
deliberate outcome rather than a coincidence — §5.3's disclosure is
discharged by rendering copy the manifest already carries.

| Surface | String | Status |
|---|---|---|
| `SourceCard` provenance note | each source's `notes` from `Data/sources.json` | **newly rendered, not newly written.** Generated by `tools/make_manifest.py`, committed, unchanged by this phase |
| The fixture card's note (the one that matters) | `Dataset interamente fittizio, scritto a mano per dimostrare l'architettura dell'app. Non deriva da alcuna fonte esterna e non rappresenta collegi, rappresentanti o votazioni realmente esistenti.` | unchanged text, now visible |
| `ChamberPicker` segments | `Camera` / `Senato`, VoiceOver `Camera dei Deputati` / `Senato della Repubblica` | **unchanged** — only identifiers moved |
| `CollegioTypePicker` segments | `Uninominali` / `Plurinominali`, VoiceOver `Collegi uninominali` / `Collegi plurinominali` | **unchanged** — only identifiers moved |
| `AddressSearchView` | every string | **unchanged** — §4 changed the container, not the copy |

---

## 9. Post-32A bundle figure (for Phase 32B)

`Politici/Data/` is **byte-identical to its Phase 30B/31 state** — this
phase ran no pipeline script and touched no generated file.

| File | Bytes |
|---|---:|
| `votes.json` | 1,767,926 |
| `districts.geojson` | 1,158,457 |
| `comuni.json` | 896,739 |
| `districts_senato.geojson` | 867,362 |
| `districts_plurinominali_camera.geojson` | 766,581 |
| `districts_plurinominali_senato.geojson` | 608,842 |
| `representatives.json` | 482,770 |
| `memberships_camera.json` | 108,917 |
| `sources.json` | 7,337 |
| `parties.json` | 1,620 |
| **Total real** | **6,666,551 B** |

**6,666,551 B = 6.36 MiB = 63.6 % of the ~10 MiB soft ceiling**; headroom
3,819,209 B = 3.64 MiB. The three `*.sample.*` fixtures add **14,765 B**
(on-disk total 6,681,316 B) and sit outside the taxonomy — test-only, never
displayed. Standing gates all clear: `votes.json` 1,767,926 B = 84.3 % of
its 2 MiB gate; no boundaries file within reach of the 3 MB gate.

---

## 10. Verification

### 10.1 Tests — 227 → 230 (+3, all deliberate)

| Test | Why |
|---|---|
| **+** `AccessibilityAuditUITests.testAccessibilityAuditHome` | Home split out of the old combined test so it can page 4 viewports and prove footer coverage |
| **+** `AccessibilityAuditUITests.testAccessibilityAuditPlurinominaleCollegioPages` | Phase 25's two plurinominale collegio pages — never audited |
| **+** `AccessibilityAuditUITests.testAccessibilityAuditAddressSearchAndFontiEDati` | the comuni disambiguation screen and the sources screen — never audited; also the §4 reachability assertion and the §5.3 fixture-disclosure assertion |
| `testAccessibilityAuditCollegiListBothChambersAndTypes` | renamed/extended from the old combined test: now 4 screen states (both chambers × both collegio types) |
| `testAccessibilityAuditProfilesAndPreferiti` | extended: a **second** profile (a Camera deputy, so Phase 29's metric is audited for the first time) |
| `testAccessibilityAuditDistrictDetailBothChambers`, `…VotazioniAndVoteHistory` | unchanged in scope, now multi-viewport |

Arithmetic: **227** (measured, §1) **+ 3 = 230**. Corroborated from source:
214 unit `func test…(` + 1 `@Test` + **15** UI = **230**.

**Certifying run** (`p32a-final4`, on the exact committed tree):

```
$ xcrun xcresulttool get test-results summary --path p32a-final4.xcresult
{'result': 'Passed', 'totalTestCount': 230, 'passedTests': 230,
 'failedTests': 0, 'skippedTests': 0, 'expectedFailures': 0}
statistics: []
```

`** TEST SUCCEEDED **`, exit 0. The log again disagrees by one — 230 `Test
case` lines, 229 ending in `passed`, 0 in `failed`, with
`VoteChoiceAccessibilit…` cut mid-name by an interleaved diagnostic. The
`.xcresult` is the authority and reports 230/230.

### 10.2 Builds

```
$ xcodebuild -scheme Politici -destination 'generic/platform=iOS Simulator' build
** BUILD SUCCEEDED **

$ xcodebuild -scheme Politici -configuration Release -destination 'generic/platform=iOS Simulator' build
** BUILD SUCCEEDED **
```

Both warning-free — after §10.4.

### 10.3 Two failing runs before the green one, both diagnosed, neither hidden

Recorded because the phase's own honesty rules require it, and because a
reader comparing run counts would otherwise wonder.

| Run | Result | Cause | Disposition |
|---|---|---|---|
| `p32a-final` | 229/230, 1 failure | `.elementDetection` on Home, screenshot showed the screen **mid-scroll** | harness defect — `waitForScrollToSettle()` added (§2.4) |
| `p32a-final2` | 228/230, 2 failures | `.elementDetection` on Home **and** VoteHistory, unaffected by the settle fix | different cause — diagnosed by a dedicated instrumented run, then the narrow `element == nil` exclusion (§2.4) |
| `p32a-final3` | **230/230, 0 failures** | — | the inventory in §2 is measured from this run |
| `p32a-final4` | see §10.1 | — | certifies the committed tree after §10.4 |

No assertion was loosened to make a test pass: the settle wait fixes *when*
the audit samples, and the `element == nil` rule is narrower than the type
exclusion it replaces.

### 10.4 A pre-existing Release-build warning, fixed rather than shipped

The **Release** configuration (stricter concurrency checking under
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`) emitted:

```
Politici/Services/ComuneService.swift:98:18: warning: call to main
actor-isolated static method 'fold' in a synchronous nonisolated context
```

Pre-existing since Phase 30 and invisible in Debug, so no earlier phase's
verification would have shown it. `NameFolding` is declared `nonisolated` —
the same annotation `DataProvenance` already uses, and the accurate one:
folding a string touches no actor state. Zero behaviour change; the full
suite was re-run after it (§10.1) rather than relying on the earlier green.

---

## 11. Data-visibility staleness (baseline rule 9 — declared scope)

This phase makes two data visible where they were not, so the copy
describing the old visibility was checked:

- **`source.notes` is now user-visible** (§5.3). → `README.md`'s
  attribution-screen bullet **updated**; `docs/DATA_SOURCES.md`'s preamble
  **updated** (§7.4). `tools/make_manifest.py` is **not** changed — the
  strings were already written as in-app Italian copy; what changed is that
  they arrive.
- **Roma's three Senato collegi are now reachable** (§4). → `README.md`'s
  address-search bullet already claims the divided comuni "are shown with
  **all** of them". **Deliberately not changed**: the claim was the design
  intent all along and the defect was in the view, not the copy. It is now
  true for both chambers, which it was not before.
- **`HomeView`'s "Come funziona l'elezione" — deliberately not changed.** It
  explains the electoral system; nothing in it became inaccurate. Same
  decision Phases 30, 30B and 31 recorded, re-checked rather than inherited.
- **`FontiEDatiView`'s *Avvertenze* bullets — deliberately not changed.**
  "Le sezioni contrassegnate come «Dati dimostrativi» contengono dati fittizi
  a solo scopo di prototipo" is still accurate and is now *corroborated* on
  the same screen by the fixture card's own note rather than standing alone.
- **No generated data was touched**, so the generated-data change protocol
  has an empty diff to explain (`git status` shows nothing under
  `Politici/Data/`).

---

## 12. Frozen directories

```
$ git diff HEAD -- docs/v2 docs/v3 docs/history
(no output)
```

Zero diff, as required. The living v3 documents that *may* be updated
(`docs/v3/votes-methodology.md`) were **not** touched by this phase — Phases
27 and 29 updated the gate status in their own commits, and nothing in
release prep changes it. `docs/v4/24-ui-tests.md` is likewise not edited
(§2.1), and neither is `docs/v4/30-comuni-geocoding.md` (§6.2).

---

## 13. Acceptance criteria (from `phase-32a.md`)

| # | Criterion | Outcome |
|---|---|---|
| 1 | Complete report set verified; gaps closed before commit | **Met** — §1, 11 reports for 11 executed phases plus the side-task record; no gaps to close |
| 2 | `docs/v4/a11y-checklist.md` exists; frozen dirs zero-diff | **Met** — the checklist is committed (and is the substantive deliverable, not a formality: §2); §12 shows zero diff |
| 3 | README / `CLAUDE.md` / CHANGELOG / DATA_SOURCES accurate; hashes correct per `git log`; stale-line sweep documented with zero survivors | **Met** — §7, including one materially false README limitation that had shipped for the whole cycle |
| 4 | Final build + tests green; arithmetic shown | **Met** — §10.1 (227 + 3 = 230, `.xcresult`-measured at both ends), §10.2 (both configurations, warning-free) |
| 5 | `git tag` shows no new tag; nothing pushed; tree clean; the pending-decisions block printed and mirrored in CHANGELOG | **Met** — §14; the CHANGELOG carries the same three items under "Release actions (pending user decisions)" |
| 6 | `docs/v4/32-release.md` + `docs/releases/v4.0-prototype.md` committed in the phase commit | **Met with one naming deviation** — this report is `docs/v4/32a-release.md` (§0, deviation 1); the release note is committed as specified |

### Deviations, stated plainly

1. **Report filename** — `32a-release.md`, not `32-release.md` (§0).
2. **Two code fixes outside a documentation phase's nominal scope** —
   `AddressSearchView`'s missing `ScrollView` (§4) and `NameFolding`'s
   Release-build warning (§10.4). Both were found *by* this phase's own
   verification and both are defects in shipping code; recording them and
   leaving them would have meant tagging a release with a known unreachable
   UI element.
3. **A structural audit type gained a narrow exclusion** (§2.4). It is the
   only assertion this phase weakened, it is scoped to issues the auditor
   cannot attribute to any element, and its evidence and limitation are both
   written down.
4. **The a11y triage produces one fix and five deferrals**, not a cleared
   board. The deferred classes need a measurement no headless session can
   make; the reasoning is now falsifiable (`.primary` text is being flagged)
   rather than "needs a human".

---

## 14. Diff scope for this commit

```
Politici/Views/AddressSearchView.swift     (ScrollView — §4; copy unchanged)
Politici/Views/FontiEDatiView.swift        (renders `notes`; per-source identifier — §5.3)
Politici/Views/MapView.swift               (per-segment picker identifiers — §3)
Politici/Views/VotazioniListView.swift     (Fonte link .tertiary -> .secondary — §2.3)
Politici/Views/VoteHistoryView.swift       (same)
Politici/Utilities/NameFolding.swift       (nonisolated — §10.4)
PoliticiUITests/PoliticiUITestCase.swift   (mainScrollable, waitForScrollToSettle, selectSegment/selectCollegioType, lazy-aware scrollUntilHittable)
PoliticiUITests/AccessibilityAuditUITests.swift (whole-screen audits, 4 -> 7 tests)
README.md                                  (full refresh + stale-line sweep — §7.1)
CLAUDE.md                                  (v4 conventions; truncation + flake tallies — §7.2)
CHANGELOG.md                               (v4.0-prototype entry + release actions — §7.3)
docs/DATA_SOURCES.md                       (preamble, fixture entry, cross-check trailer — §7.4)
tools/SOURCES.md                           (ISTAT block: Phase 30B assignment — §7.4)
docs/releases/v4.0-prototype.md            (new — the release note)
docs/v4/a11y-checklist.md                  (new — the v4 accessibility checklist)
docs/v4/32a-release.md                     (new — this report)
docs/plan/00-baseline-and-rules.md         (Q6 deferral + deferred-table updates — §6)
docs/plan/README.md                        (Phase 32A status row: pending -> done)
```

No file under `Politici/Data/` changed; no pipeline ran; no network act.

---

## 15. PENDING USER DECISIONS

**Phase 32A ends here. No tag exists, nothing was pushed, no GitHub call was
made.** Phase 32B runs only on explicit approval and performs no remote
action either — it prints the push commands for the user to run personally.

1. **Approve the local `v4.0-prototype` tag?** Phase 32B would write the
   decisions addendum, commit it, run the verification trio on that commit,
   and only then create the annotated tag at `HEAD` — so the tag contains
   the complete release record. Existing tags (`v1.0.0`, `v2.0-prototype`,
   `v3.0-prototype`) are never touched.
2. **GitHub release / repository visibility intent?** The v3 record notes
   the release URL was not reachable unauthenticated (HTTP 404, consistent
   with a private repository), so no URL is asserted and the placeholder
   `<github-release-url>` stands. **You perform all remote actions
   personally**; the commands Phase 32B would print are:
   ```
   git push origin v4
   git push origin v4.0-prototype
   ```
3. **The V3/V4 commissioning brief (Q6)** — open since v3 Phase 13 and
   searched for a third time here (§6.1) with the same result: it has never
   been provided, and nothing may be fabricated in its place. If you have
   it, it is archived verbatim under `docs/history/`, labelled
   user-provided. If it does not exist, say so and it is closed as
   *never produced* rather than carried into V5.

Also worth an explicit answer, since it is the only accessibility work this
phase could not do: **the 200 recorded findings need a device-side contrast
and Dynamic Type pass** (§2.3). That is not a blocker for tagging a
prototype, and it is recorded as such — but it is the honest gap in the
release.
