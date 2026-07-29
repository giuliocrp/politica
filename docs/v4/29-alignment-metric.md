# V4 Phase 29 — Group-Alignment Metric [gate re-measured **6/6**: metric **shipped under gate**]

Ships the first vote-derived metric in the app: a per-deputy
**"Allineamento nel campione di votazioni importate"** — the share of a
deputy's *expressed* positions (favorevole / contrario / astenuto) that match
the majority expressed position of the group they held **on each vote's date**,
over the shipped 30-vote sample. It is a pure function
`GroupAlignment.alignment(events, positions, memberships)` (over an internal
`tally(…)`), rendered **only** on the Camera deputy profile, **only** above a
minimum denominator, **never** on lists, **never** ranked, and **never** colored
as a judgment.

Every number below was produced by a quoted command in this session on
**2026-07-23**. No network act was performed (this phase is fully offline); the
runtime stays strictly local-first.

---

## 1. Preconditions — re-measured, not inherited

### 1.1 Methodology gate — re-measured independently from the shipping files: **6 of 6**

Per the `docs/v3/votes-methodology.md` re-evaluation protocol, the gate was
re-measured **from the then-current `votes.json` + `memberships_camera.json` +
`representatives.json` in this session**, not inherited from Phase 28. The six
lines were recomputed by a standalone script over the raw data files (per-line
before/after in §11):

| # | Requirement | Re-measured this session | Status |
|---|---|---|---|
| 1 | ≥ 30 events | **30 events**, 11,899 positions | ✓ |
| 2 | ≥ 3 distinct sittings | **10** (552, 577, 581, 599, 614, 634, 648, 664, 680, 694) | ✓ |
| 3 | ≥ 6 months span | **272 days ≈ 8.9 months** (2025-10-22 … 2026-07-21) | ✓ |
| 4 | ≥ 2 distinct atti among atto-bearing | **15 atto-bearing events, 9 distinct atti** (1311, 1686, 1805, 1895, 2396, 2423, 2574, 2678, 2682) — manifest slugs verified == `votes.json` event ids | ✓ |
| 5 | `astenuto` its own category | Structural + distribution **Favorevole 4,326 / Assente 4,571 / Contrario 2,541 / Astenuto 461** | ✓ |
| 6 | Group-membership at vote date | **11,899 / 11,899** position rows and **3,967 / 3,967** distinct `(deputy, date)` pairs resolve to **exactly one** interval (0 multi); `memberships_camera.json` = 468 intervals | ✓ |

**6 of 6.** Phase 28 reported 5/6 → 6/6; this session **verified** it against the
repository rather than inheriting the figure — the numbers came out identical.
Under the gate, Phase 29 is a **live phase with GO**. (NOT-RUN would have been a
first-class outcome had any line come back red, or had the available data
supported no defensible metric — see §3.2 for the honesty finding, which does
**not** rise to that.)

### 1.2 Test baseline — measured from the `.xcresult`: **177**

Measured **before** any addition, on the current tip (`fe0038a`):
`xcresulttool get test-results summary` reported `totalTestCount 177,
passedTests 177, failedTests 0`. The from-source occurrence count corroborates
(**not** `sort -u`, per `CLAUDE.md`): 165 `func test…(` + 1 `@Test` (unit) + 11
UI = **177**; the `sort -u` method under-reads because `CircoscrizioneTests` and
`RegioneTests` deliberately share `testGroupingForEsteroNeverReturnsAnyone`.
Baseline confirmed 177 before proceeding, as the phase instruction required.

---

## 2. The user-gated decision (Q7 + presentation) — verbatim + substance

Per the phase's user-gate and the Phase 26 lesson, the metric design was
presented **before implementation** and the user decided three things. The
**verbatim approvals** (the option labels selected, proof-of-ask):

> **Threshold:** "n ≥ 10 (Recommended)"
> **Tie rule:** "Exclude that vote from the denominator (Recommended)"
> **Presentation:** "Integer % with denominator shown (Recommended)"

The **substance** of each decision (what makes it auditable — recorded, not just
the label):

- **Minimum denominator = 10.** Below 10 expressed-and-group-defined votes the
  metric does **not** render; the deputy shows an honest absence (no line),
  never `0%`, a midpoint, or the group's value. The number was chosen against
  the **actual per-deputy denominator distribution** (§3.1), which the user was
  shown: median n = 21, and ≥10 renders 318 of 400 Camera deputies while leaving
  82 as honest unknowns. At n = 10 a single defection swings the value 10 points
  — which is *why* the denominator is shown alongside (below).
- **Group-majority tie → exclude that vote from the member's denominator.** If
  the group had no single majority expressed position there is nothing to align
  to, so the vote is dropped from that member's *n* entirely — neither counted
  as aligned nor as unaligned. The rejected alternatives were recorded in the
  ask: counting a tie as non-aligned would penalize the member for the group's
  own indecision; breaking the tie toward the member's own vote is circular
  (the member helps define the majority they're then scored against). Rare on
  this sample: **9** deputy-vote rows, from a single `(event, group)` tie.
- **Integer percentage, with the denominator shown alongside** (e.g.
  `"96% — su 27 voti espressi"`). The user was shown the honesty finding that
  **93.4 % of renderable deputies sit at exactly 100 %** (§3.2); against that, a
  coarse qualitative band would dump almost everyone into one bucket (*less*
  discriminating) **and** hide the base — so a band is **not** more honest here.
  A point value is defensible **only** with its denominator adjacent, so
  `"90% su 10"` reads visibly weaker than `"96% su 27"`.

Also settled and recorded, **not** asked (the spec + this data settle them):

- **No ranking, no league table, never on a list.** With 93 % of deputies at
  exactly 100 %, ranking would sort people by one or two votes' difference out
  of a coverage-driven sample — turning a sampling artefact into an apparent
  finding about named individuals. Deliberately declined.
- **No color as a judgment.** The value is rendered in the primary text color,
  never a green/amber/red scale.
- **Group-majority includes the member** (the natural reading of "the majority
  position of *their* group"); leave-one-out was considered and not adopted —
  it barely moves large groups and the small-group caveat is disclosed anyway.
- **Gruppo Misto is one group** per Phase 28's documented mapping; its
  heterogeneity is disclosed in the caption, not silently smoothed.

---

## 3. The honesty findings that shaped the design

### 3.1 Per-deputy denominator distribution (shown before choosing a presentation)

Computed over the **399 Camera deputies who cast at least one position** (*n* =
expressed & group-defined & non-tie votes). The 400th Camera deputy, **President
Lorenzo Fontana**, presides and casts **no** roll-call votes, so he has no
positions and is not in this distribution (see §3.3) — the same 399-vs-400
distinction Phase 28 had to correct once, stated here next to each count so no
number reads as an inconsistency:

```
n=0:34  n=1:4  n=2:6  n=3:12  n=4:3  n=5:4  n=6:5  n=7:2  n=8:5  n=9:6
n=10:3  n=11:5 n=12:10 n=13:6 n=14:8 n=15:13 n=16:13 n=17:14 n=18:11 n=19:19
n=20:15 n=21:19 n=22:13 n=23:12 n=24:20 n=25:27 n=26:19 n=27:34 n=28:10 n=29:16 n=30:31
```

(sums to **399**.) min 0 · **median 21** · mean 18.3 · max 30. Threshold
sensitivity **over these 399** (render / unknown): ≥8 → 329 / 70; **≥10 → 318 /
81**; ≥12 → 310 / 89; ≥15 → 286 / 113. **Over all 400** Camera deputies — the
President added as one more below-threshold unknown — ≥10 is **318 / 82** (the
figure the shipping determinism dump in §7 reports, since it iterates every
Camera deputy). So: **81** unknown of the 399 who vote, **82** of all 400.

### 3.2 The metric barely discriminates — stated plainly, not hidden

For the 318 deputies rendering at n ≥ 10: alignment share **min 0.52, mean
0.988**, and **297 of 318 (93.4 %) sit at exactly 100 %**; only 13 fall below
90 %. The sample is a coverage-driven stratified pick that is **~half
procedural** and whose atto-bearing votes are largely consensual, so group
discipline is near-total *on this sample*. This is the reason ranking is
refused, the reason a point estimate must carry its denominator, and the reason
the caption states so prominently. **The metric describes behaviour on this
sample, not in Parliament** — it is not presented as a fact about a person.

### 3.3 No false precision, no fabricated values

Per-deputy *n* is at most 30 minus absences (and minus ties). Below the
threshold the deputy renders **nothing** — never a default, a midpoint, or the
group's value (the Phase 28 nil-not-fallback rule extended to the metric:
inferring a figure about a named politician is fabrication). Senators render
nothing ever (votes are Camera-only; they carry zero positions → n = 0).

---

## 4. The metric — exact definition

For a deputy **D**, over the 30 shipped events:

- **Expressed position** = `Favorevole`, `Contrario`, or `Astenuto`. **`Assente`
  is excluded from the denominator entirely.** The Camera source's
  `"Non ha votato"` conflates *absent / in missione / present-but-not-voting*
  into the single `.assente` value (`docs/v2/04-votes-import.md`); it is treated
  as **neither** agreement **nor** disagreement — only excluded. In this sample
  there is **no separate "in missione" value**: it is folded into `.assente` at
  source and drops out with every other absence. (The distribution carries only
  Favorevole/Contrario/Astenuto/Assente — no `.sconosciuto`, no missione.)
- **`Astenuto`** is a first-class expressed category (gate line 5): it counts in
  the denominator, and D is aligned on that vote iff the group's majority
  expressed position is **also** astenuto.
- **G = D's group on the vote's date** (Phase 28 half-open interval; a
  group-switcher is scored per-interval, never against their current group).
- **Group majority** = the mode of the expressed positions of all members of G
  on that date (D included). A **tie** (two expressed positions sharing the top
  count) → the vote is **excluded** from members' denominators.
- **Denominator n(D)** = events where D expressed a position, G is known, and
  G's majority is defined (non-tie). **Numerator** = of those, how many D
  matched. **Value** = numerator / n(D), rendered only if **n(D) ≥ 10**.
- **Senators: never.**

Implemented in `Politici/Models/GroupAlignment.swift` — a caseless namespace (no
stored state), a pure function of its inputs, order-independent by construction
(it counts positions), reusing the one canonical half-open containment rule
(`MembershipService.membership(at:in:)`). **Two levels, deliberately** (the
review follow-up in §14): `tally(…) -> Tally(matched, denominator)` is the raw
arithmetic and testing seam (any denominator); `alignment(…) -> Alignment` is
the threshold-gated **presentable** result the UI holds — `.value(percentage,
denominator)` above the minimum, else `.insufficientData`, which carries **no
number**. A `Tally(0, 0)` (the President — memberships but no roll-call votes)
therefore cannot be formatted as "0 %": the nil-not-fallback rule is enforced by
the type, not by caller discipline.

---

## 5. Pinned Italian strings (this phase's new shipping vocabulary)

Recorded here verbatim because this phase introduces the metric vocabulary
Phase 27 spec 6 verified was previously absent from all app code. All live in
`GroupAlignment.swift` and are pinned by
`GroupAlignmentTests.testPinnedItalianStringsValueFormattingAndRounding`.

- **Label** (`GroupAlignment.metricLabel`, the **single** occurrence of the
  literal in `Politici/`):
  `Allineamento nel campione di votazioni importate`
- **Value line** (`GroupAlignment.valueText(percentage:denominator:)`, integer %
  + denominator): `«N»% — su «D» voti espressi` — e.g. `96% — su 27 voti espressi`
- **Caption** (`GroupAlignment.sampleCaption`, the prominent honesty note —
  **strengthened in the §14 follow-up** so it reads as firmly for a deputy at
  85 %, where the sampling noise concentrates, as for one at 100 %):
  `Quota dei voti espressi (favorevole, contrario o astenuto) che coincidono con la posizione di maggioranza del gruppo di appartenenza alla data di ciascun voto; le assenze sono escluse. Il campione di votazioni importate è scelto per copertura ed è in parte procedurale, quindi la percentuale descrive il comportamento su questo campione, non l'attività complessiva in Parlamento. Le differenze tra deputati dipendono da pochi voti e non vanno sovrainterpretate: un valore più basso riflette il campione limitato, non necessariamente una tendenza generale. Nei gruppi molto piccoli, incluso il Gruppo Misto, l'allineamento è quasi automatico.`
- **VoiceOver** (`GroupAlignment.accessibilityText(percentage:denominator:)`):
  `Allineamento nel campione di votazioni importate: «N» percento, su «D» voti espressi.`

The caption deliberately carries **no hardcoded sample size** (to stay
non-stale across refetch); the per-deputy denominator, the honest base, is shown
in the value line and is derived.

---

## 6. Hand-computed fixture matrix (written before implementation)

Per the verify-expectations-independently rule, each expected value below was
computed **by hand** and encoded into `GroupAlignmentTests` before the
implementation was run. `Tally(m, d)` = matched m of denominator d; `.value` /
`.insufficientData` are the `alignment(…)` cases.

| Fixture (test) | Setup | Hand-computed expectation | Rule proven |
|---|---|---|---|
| `testUnanimousGroupAllAlignedIncludingAstenuto` | G={r1,r2,r3}; E1 all Fav, E2 all Astenuto | r1 → `Tally(2,2)` | basic + astenuto aligned |
| `testSplitGroupDissenterUnalignedFollowerAligned` | E1: r1 Contr vs r2..r5 Fav (maj Fav) | r1 → `Tally(0,1)`; r2 → `Tally(1,1)` | plurality; dissenter vs follower |
| `testGroupMajorityTieExcludesThatVoteFromDenominator` | E1: 2 Fav / 2 Contr (tie); E2 all Fav | r1 → `Tally(1,1)` — **not** 2 in denom | **tie-exclusion** |
| `testAbsenceExcludedNotCountedAsDisagreement` | E1: r1 Assente, r2/r3 Fav; E2 all Fav | r1 → `Tally(1,1)` (not 0/2, not 1/2); r2 → `Tally(2,2)` | **absence excluded** |
| `testAstenutoIsItsOwnCategoryForMajorityAndMatch` | E1: 3 Astenuto / 2 Fav (maj Astenuto) | abstainer → `Tally(1,1)`; Fav-voter → `Tally(0,1)` | **astenuto ≠ favorevole** |
| `testThresholdBoundaryNineIsInsufficientTenRenders` | 10 events; r1 expresses 9 then 10 | n=9 → `alignment == .insufficientData`; n=10 → `.value(100,10)` | **threshold boundary 9 vs 10** |
| `testGroupSwitcherAlignmentDiffersByInterval` | r1 G1→G2 @2026-03-01; E1 2/1 G1, E2 3/15 G2 | with switch `Tally(2,2)`; if never-switched `Tally(1,2)` — **differ** | **group-switcher by interval** |
| `testDeputyWithMembershipButNoVotesIsInsufficientNotZero` | membership, zero votes (President shape) | `Tally(0,0)` → `alignment == .insufficientData` (no number) | **non-representable zero** (§14) |
| `testMajorityChoicePluralityTieAndExpressedOnly` | direct majority helper | plurality→choice; 2- and 4-way tie→nil; astenuto wins; absences ignored | majority + tie helper |
| `testPinnedItalianStringsValueFormattingAndRounding` | strings + 11/12 fixture | label/caption/value/a11y verbatim; `alignment` rounds 91.67→`.value(92,12)` | pinned copy + rounding |

Plus two shipping-data tests (§7). The full ask distribution and the shipping
tallies were also reproduced by a standalone Python mirror of the exact rules —
its numbers match the Swift output.

---

## 7. Determinism — proven by diff, not inspection

**Artifact diff.** A faithful mirror of the Swift rules computed every Camera
deputy's `matched/denominator` over the shipping data, serialized sorted by id,
**run twice**: `diff` empty, both files SHA-256
`9f898449dfab4ad6b1c46892d07b26bb5b6538da234e0fff13756c0561eaa73b`. The dump
carries 400 Camera deputies → 318 render / 82 unknown / 297 exactly 100 %.

**In the shipped code.** `testShippingTalliesAreDeterministic` computes every
Camera deputy's tally **twice** over the identical input, serializes both to a
canonical string, and asserts byte-identical — the computation is
order-independent by construction (it counts positions), and this is the check
that it stays so, not an assertion by inspection.

**Bounds & Camera-only.** `testShippingTalliesAreWithinBoundsAndCameraOnly`
asserts every Camera tally is in bounds (0 ≤ matched ≤ denominator ≤ 30), that a
substantial number of deputies render (≥ 100; actually 318), and that every
senator tallies `Tally(0,0)` **and** resolves to `.insufficientData`, so the
metric never appears for them. No exact per-deputy percentage is pinned — those
shift with the sample, like `votes.json`'s count, and pinning one would be
brittle re-pin bait.

---

## 8. UI — profile-only, Camera-only, above-threshold-only

`RepresentativeProfileView.alignmentSection(for:)` renders the metric between
the committees and recent-votes sections. It is present **only** when
`representative.chamber == .camera`, the vote data is `.loaded`, and
`GroupAlignment.alignment(…)` pattern-matches `.value(percentage, denominator)`
(i.e. n ≥ 10). Below threshold, for senators, or before the votes load, the
result is `.insufficientData` and the whole section is **absent** — an honest
silence, with no formattable number in reach of the view. The value uses the primary text color (no judgment coloring), the
denominator is shown in the same line, and the honesty caption sits beneath it.
The section is one combined accessibility element
(`accessibilityIdentifier("profile.alignment")`) reading the VoiceOver value +
caption. **Build: `** BUILD SUCCEEDED **`, zero warnings/errors.**

---

## 9. Data-visibility (rule 9)

The metric is a **new place a datum is visible**, so the old explanatory copy
was checked for staleness:

- **`README.md`** — three regions corrected: the votes feature bullet ("No
  derived metric of any kind ships" → the alignment metric now ships behind the
  gate), the methodology bullet ("No vote-derived metric ships — browsing only"
  → "Exactly one vote-derived metric ships, strictly behind the gate", with the
  definition, exclusions, and the never-listed/ranked/colored constraints), and
  the roadmap (a new "Shipped in v4" bullet; the metric removed from "Open (V4
  candidates)").
- **`docs/v3/votes-methodology.md`** — the gate conclusion updated to record the
  Phase 29 outcome (re-measured 6/6, metric shipped under gate), and the stale
  pinned-label rule ("grep-verified absent from all app code as of Phase 20")
  corrected: the label now ships as `GroupAlignment.metricLabel`, exactly once
  in `Politici/`.
- **`HomeView` "Come funziona l'elezione"** — **decision not to touch**: it
  explains election/collegio geography only, never profile contents or vote
  methodology, so nothing it says became inaccurate.
- **`docs/DATA_SOURCES.md` / "Informazioni e fonti"** — **decision not to
  touch**: the metric introduces **no new bundled data source** (it is computed
  over `votes.json` + `memberships_camera.json`, both already disclosed), and
  neither file carried a "no metric" claim to invalidate. The metric's own
  prominent caption is its in-app disclosure.

---

## 10. Tests — 177 → 189 (+12, all deliberate)

| Test | Covers (spec) |
|---|---|
| `testMajorityChoicePluralityTieAndExpressedOnly` | majority + tie helper (#2) |
| `testUnanimousGroupAllAlignedIncludingAstenuto` | unanimous + astenuto (#2) |
| `testSplitGroupDissenterUnalignedFollowerAligned` | split group (#2) |
| `testGroupMajorityTieExcludesThatVoteFromDenominator` | tie-exclusion (#2) |
| `testAbsenceExcludedNotCountedAsDisagreement` | absence-exclusion (#2) |
| `testAstenutoIsItsOwnCategoryForMajorityAndMatch` | astenuto own category (#2) |
| `testThresholdBoundaryNineIsInsufficientTenRenders` | threshold boundary 9 vs 10 (#2) |
| `testGroupSwitcherAlignmentDiffersByInterval` | group-switcher by interval (#2) |
| `testDeputyWithMembershipButNoVotesIsInsufficientNotZero` | senator/President → `.insufficientData` (#2/#3, §14) |
| `testPinnedItalianStringsValueFormattingAndRounding` | pinned label/caption/value + rounding; Italian (#3) |
| `testShippingTalliesAreDeterministic` | determinism by diff (#5) |
| `testShippingTalliesAreWithinBoundsAndCameraOnly` | bounds + Camera-only + some render (#5) |

**`.xcresult`: `totalTestCount 189`** — 177 baseline + 12. Two full-suite runs
were needed, and both are reported honestly:

- **Commit 1's run: `passedTests 188, failedTests 1`.** The single failure was
  `AccessibilityAuditUITests.testAccessibilityAuditDistrictDetailBothChambers`
  (**131 s** vs. its ~65 s siblings), the **documented simulator-clone UI flake**.
  Diagnosed, not assumed: that test navigates **District Detail only** (Camera
  120101, Senato S120001), never a profile, so it cannot render the Camera-only
  alignment section; `testAccessibilityAuditProfileAndPreferiti` (which *does*
  audit a profile) passed, as did all 12 new tests. An isolated re-run passed —
  but, per the caveat now in `CLAUDE.md`, running the test alone removes the
  clone parallelism that triggers the flake, so that is **weaker** evidence than
  a clean full suite.
- **Commit 2's run (this tree, after the follow-up refactor): `totalTestCount
  189, passedTests 189, failedTests 0`, result Passed** — a clean full-suite
  green, no flake, which is what actually settles it.

"Zero regressions" now means 189 plus documented deliberate additions. The
re-derived occurrence count is collision-safe: 165 (unit `func test`) + 1
(`@Test`) + 11 (UI) = 177 prior, now 177 + 12 = **189** declared.

**Grep — the pinned label appears exactly once in `Politici/`:**
`grep -rn "Allineamento nel campione di votazioni importate" Politici/` → the
single `GroupAlignment.metricLabel` constant (the UI and tests reference the
constant, and the test-target literal is outside `Politici/`).

---

## 11. Methodology gate re-measured (same commit) — per-line before/after

`votes.json` and `memberships_camera.json` are **unchanged** since Phase 28, so
the six lines are numerically identical to Phase 28's — but re-measured, not
inherited (§1.1):

| # | Requirement | Phase 27 | Phase 28 | Phase 29 (re-measured) |
|---|---|---|---|---|
| 1 | ≥ 30 events | ✓ | ✓ | ✓ (30 / 11,899) |
| 2 | ≥ 3 distinct sittings | ✓ | ✓ | ✓ (10) |
| 3 | ≥ 6 months span | ✓ | ✓ | ✓ (272 d) |
| 4 | ≥ 2 distinct atti | ✓ | ✓ | ✓ (15 / 9) |
| 5 | `astenuto` own category | ✓ | ✓ | ✓ (461) |
| 6 | group membership at vote date | ✗ | ✓ | ✓ (11,899/11,899 · 3,967/3,967) |

**6 of 6 — the metric ships under the gate.** Post-phase declared test count
stated explicitly: **189**.

---

## 12. Acceptance criteria (from `phase-29.md`)

| # | Criterion | Outcome |
|---|---|---|
| 1 | Six-line gate re-verified and quoted; NOT-RUN if any red | **Met** — §1.1: re-measured 6/6 independently; GO |
| 2 | Pure-function tests vs pre-recorded hand-computed values (unanimous; split; tie-exclusion; absence-exclusion; astenuto; threshold 9 vs 10; switcher by interval) | **Met** — §6 fixture matrix + §10; all seven rules + helper covered |
| 3 | UI: metric absent for senators & below-threshold; caption pinned; Italian throughout | **Met** — §8 (Camera-only, above-threshold-only), §5 pinned strings, `testDeputyWithMembershipButNoVotesIsInsufficientNotZero`, `testPinnedItalianStringsValueFormattingAndRounding` |
| 4 | Grep: pinned label exactly once in `Politici/`, nowhere else | **Met** — §10 grep |
| 5 | Suite green vs baseline + documented additions | **Met** — §10: 177 → 189, all pass |

**Additional requirements (authorized by the user, in scope):**

| Requirement | Outcome |
|---|---|
| Re-measure the methodology gate yourself (don't inherit 5/6→6/6) | **Met** — §1.1, standalone script over the raw files |
| Baseline 177 measured from `.xcresult` (occurrence rule), stop if not 177 | **Met** — §1.2: `.xcresult` 177/177/0; occurrence 165+1+11 |
| Present metric design for approval (definition, denominator, absence/missione/astenuto, Q7 tie + threshold) | **Met** — §2, §4; approved 2026-07-23 |
| Record the *substance* of the decision, not just the label | **Met** — §2 |
| State the sample limitation prominently (report + copy) | **Met** — §3.2, §5 caption |
| No false precision; show per-deputy n distribution before choosing presentation | **Met** — §3.1, then integer % **with denominator shown** |
| Decide deliberately on ranking; record reasoning | **Met** — §2: **no ranking**, reasoning recorded |
| Below-threshold → unknown, never default/midpoint/group value | **Met** — §3.3, §8 |
| Prove determinism by diff (run twice, byte-identical) | **Met** — §7: diff empty, SHA `9f8984…`, + in-code determinism test |
| Pin every new Italian string in the report | **Met** — §5 |
| Re-measure the gate per-line before/after in the same commit; state post-phase count | **Met** — §11; post-phase count **189** |

**Deviations, stated plainly:**
1. **The originally-shipped `Score(0,0)` type carried a latent named-person
   misrender** — a `Score` with `denominator == 0` (the Camera President, who
   holds memberships but casts no roll-call votes) *could* be formatted as
   "0 % aligned" by any future surface that skipped the threshold check.
   Behaviourally inert at the time (0 < 10 → nothing rendered), but the type
   allowed the fabrication rather than preventing it. **Resolved in the review
   follow-up (§14):** the public result is now the `Alignment` enum, whose
   `.insufficientData` case carries no number, so the misrender is
   non-representable — enforced by the type, not by caller discipline.
2. **The one honesty finding worth flagging** (§3.2): the metric barely
   discriminates on this sample (93.4 % at exactly 100 %). This does **not**
   make the metric indefensible — it is defensible *as a description of this
   sample* with the denominator shown and no ranking — but it is why ranking is
   refused and why the caption is emphatic. Surfaced, not buried.

---

## 13. Diff scope

**Commit 1 — `feat(v4): phase 29 …` (`744d045`, pushed):**

```
Politici/Models/GroupAlignment.swift          (new — pure metric namespace + constants)
Politici/Views/RepresentativeProfileView.swift (alignmentSection — Camera-only, above-threshold-only, no color)
PoliticiTests/GroupAlignmentTests.swift        (new — 12 tests: hand-computed fixtures + shipping/determinism)
docs/v3/votes-methodology.md                   (gate conclusion: metric shipped under gate; stale label rule fixed)
README.md                                      (3 regions: votes bullet, methodology bullet, roadmap — metric now ships)
docs/plan/00-baseline-and-rules.md             (Q7 marked RESOLVED)
docs/v4/29-alignment-metric.md                 (new — this report)
docs/plan/README.md                            (Phase 29 status row: pending -> done)
```

**Commit 2 — `chore(v4): phase 29 review follow-ups …` (this commit; see §14):**

```
Politici/Models/GroupAlignment.swift          (Score -> Tally + Alignment enum; caption strengthened)
Politici/Views/RepresentativeProfileView.swift (switch on Alignment; no formattable zero in reach)
PoliticiTests/GroupAlignmentTests.swift        (tally()/alignment() split; President-shape test; rounding)
CLAUDE.md                                      (UI-flake running tally + isolated-re-run caveat)
docs/plan/phase-30.md                          (user guidance: measure-vs-reality, licence NO-GO, state file+source)
docs/v4/29-alignment-metric.md                 (report updated: universe 81/82, Tally/Alignment, §14)
```

No generated data file changed (no pipeline ran); no network act; no new
bundled data source. Remote actions are the user's. Not run here:

```
git push origin v4
```

---

## 14. Review follow-ups (2026-07-23, after commit 1 was pushed)

Five points from the user's review of commit 1, all in scope, all in commit 2:

1. **`Score(0,0)`'s named-person failure mode made non-representable (the real
   fix).** Commit 1 returned a `Score(matched, denominator)` for every deputy;
   `Score(0, 0)` — Lorenzo Fontana's exact shape (memberships, zero roll-call
   votes) — could be formatted as "0 %" by any future surface that skipped the
   threshold, the precise fabrication the nil-not-fallback rule forbids,
   prevented only by caller discipline. Commit 2 splits the API: `tally(…) ->
   Tally` (raw arithmetic, internal/testing) and `alignment(…) -> Alignment`
   with `.value(percentage, denominator)` **or** `.insufficientData` (no
   number). The UI holds only `Alignment` and pattern-matches `.value`, so the
   misrender is not representable — enforced by the type. New test
   `testDeputyWithMembershipButNoVotesIsInsufficientNotZero` pins the President
   shape → `.insufficientData`.
2. **Report universe stated next to each count (§3.1).** The n-distribution sums
   to **399** (deputies who cast ≥1 position); the 400th, President Fontana,
   casts none. So unknown is **81 of the 399 who vote**, **82 of all 400** Camera
   deputies — the same 399-vs-400 distinction Phase 28 corrected once, now
   labelled at every count so neither reads as an inconsistency.
3. **Flake honesty + CLAUDE.md running tally.** The isolated re-run of commit 1's
   flake is weaker evidence than it looks — running the test alone removes the
   simulator-*clone* parallelism that triggers it — so the honest state of
   commit 1 was "one full-suite run at 188/189 with a diagnosed environmental
   failure." A **second full-suite run on commit 2's tree** settles it (§10),
   and the sighting is now recorded in `CLAUDE.md` as a running tally
   (three-plus occurrences) with the re-run caveat, alongside the log-truncation
   count.
4. **Caption strengthened for the low-alignment outlier (§5).** With 93.4 % of
   renderable deputies at exactly 100 %, the metric's only discriminating output
   is the ~13 below 90 %, where one or two defections out of ~27 coverage-picked
   votes move the number — i.e. its signal lands where the sampling noise is
   worst. Refusing ranking helps but doesn't cover it, so the caption now adds
   *"Le differenze tra deputati dipendono da pochi voti e non vanno
   sovrainterpretate: un valore più basso riflette il campione limitato, non
   necessariamente una tendenza generale"* — reading as firmly at 85 % as at
   100 %.
5. **Phase 30 guidance recorded (`docs/plan/phase-30.md`).** For the next phase,
   per the handoff: gate size against the **measured ~5.50 MiB** `Data/` reality
   (this report's own measurement; the spec predates Phases 25/27/28), treat an
   **unverifiable licence as a NO-GO, not a footnote**, and — acquisition being
   user-gated and manual — have the session **state the exact file and official
   source URL for approval before it downloads anything**.
