# V4 Phase 31 — ADR: Live Data Refresh, and Staleness Disclosure

**Status: decided — live refresh stays DEFERRED; a one-line staleness
disclosure ships on Home.** No network act was performed (this phase is
fully offline); the runtime stays strictly local-first.

Every number below was produced by a quoted command in this session on
**2026-07-28**, against the tip `b5b73a7` (Phase 30B closeout). The
deferral is **re-derived from the shipped artifacts**, not inherited from
`docs/plan/phase-31.md`'s prose — see §1.

---

## 0. Scope, and where it departs from `phase-31.md`

The user's additional requirements for this phase are authorized and in
scope, and where they conflict with the phase file they win (stated here
per their instruction):

| Requirement | Where discharged |
|---|---|
| Re-derive the deferral; treat "remains deferred" as a hypothesis, not a conclusion | §1–§3 — reasoned from the four artifacts Phases 27/28/29/30B actually shipped, with measured rates |
| Classify staleness by **consequence**, not by artifact; name the class that silently misstates a named person | §2, and it is the **same nil-not-fallback family** as Phases 28, 29 and 30B — §2.4 |
| Answer the disclosure question explicitly, including *where*; rule 9 applies | §6–§7, §10 |
| If deferring, pin the trigger conditions | §5 |
| Decision document; **stop and ask** before writing code or touching generated data | Asked before any edit; both answers quoted in §6 |
| Pin any new Italian strings | §7 |
| Measure the baseline from the `.xcresult` if anything code-side changes | §9 — **219 → 225**, measured |

**One deviation from the phase file, stated plainly**: the footer wording.
`phase-31.md` §2 specifies the literal `"Dati aggiornati al {date}"`. The
shipped line is **`"Ultimo aggiornamento dei dati: {date}"`** — reasoning
in §7. `CLAUDE.md` constraint #4 and plan rule 7 govern: the phase file's
wording asserts more than the manifest supports, so reality wins and the
deviation is documented rather than shipped silently.

**One in-scope defect fix**, found because this phase ships a date and
verified rather than assumed: `DateFormatting`'s display formatters read
dates in the *device's* timezone while every parser in the project
produces them at **midnight Europe/Rome**, so dates rendered one day early
everywhere west of Rome. §8.

---

## 1. What actually goes stale — re-derived from the shipped artifacts

The plan's roadmap entry ("Possible live data refresh — still deferred
pending the 'is that compatible with local-first at all' decision") is
three phases old and predates every artifact that could change the answer.
So the question was re-opened from the data, not the prose.

### 1.1 The bundle, split by whether a refresh could change it

Measured over `Politici/Data/`, excluding the three `*.sample.*` fixtures
(14,765 B, test-only):

| Class | Files | Bytes | Share |
|---|---|---|---|
| **A — cannot change within the legislature** | `districts.geojson`, `districts_senato.geojson`, both plurinominale files, `comuni.json`, `votes.json` | **6,065,907** | **90.99 %** |
| **C — ages silently, about named people** | `representatives.json`, `memberships_camera.json` | **591,687** | **8.88 %** |
| **B — provenance dates** | `sources.json` | 7,337 | 0.11 % |
| — | `parties.json` (styling vocabulary) | 1,620 | 0.02 % |
| **Total (real)** | | **6,666,551 B = 6.36 MiB** | |

**91 % of what ships is data a live refresh could not change**, because it
is either fixed by law for the legislature or a record of something that
already happened. That is the single most important input to the decision,
and it is a *measurement*, not an argument.

### 1.2 Artifact by artifact — the four the additional requirements name

**Phase 27 — the 30-vote stratified sample (fetched 2026-07-22).** The
selection is explicitly *not* stable across refetches
([`27-votes-stratified.md`](27-votes-stratified.md) §4), which sounds like
a staleness problem and is not one. The 30 events span **2025-10-22 …
2026-07-21** and record how 399 named deputies voted on days that have
happened. Those facts are immutable; a refetch would return the same
positions for the same URIs. What ages is **coverage**: the newest vote in
the app recedes at one day per day. That is visible (every vote carries its
date, rendered in `VotazioniListView` and `VoteHistoryView`) and it
misstates nothing.

**Phase 28 — membership intervals with open ends.** This is the artifact
the requirements correctly single out. 468 intervals: **400 open** (one per
deputy, `end: null`) + 68 closed. An open end asserts "still in this group,
indefinitely" — the only shipped claim that is *about the present* and can
therefore become false while sitting still. Measured switch rate, from the
shipped file:

| Window (ending at the 2026-07-22 fetch) | Switch events | Distinct deputies |
|---|---|---|
| Whole legislature (2022-10-18 →), 1,373 d | 68 | 52 of 400 |
| Trailing 12 months | **19** | **14** |
| Trailing 6 months | 13 | — |

By year: 2022 → 21, 2023 → 11, 2024 → 12, 2025 → 8, 2026 → 16 (through
2026-07-09). The most recent switch is **2026-07-09 — thirteen days before
the fetch**. This is not a dormant risk; it is a live one at roughly
**1.6 switch events per month**.

**Phase 29 — the alignment metric.** The requirements list it as
downstream of the open-ended intervals. Checked rather than assumed:
`GroupAlignment` resolves membership **at each vote's date**, every vote
date is **≤ 2026-07-21**, and the latest interval start in the file is
**2026-07-09**. Any switch occurring after the snapshot falls strictly
after every date the metric queries, so `membership(at: voteDate)` is
unreachable by it. **The metric is frozen-correct: its staleness exposure
is zero, now and for as long as the sample stays fixed.** Its caption
already says the alignment is measured against "il gruppo di appartenenza
alla data di ciascun voto", which is vintage-independent copy. The metric
inherits the problem only indirectly — it renders on the same profile
screen that displays the deputy's *current* group (§2.3).

**Phase 30/30B — comuni tied to the 2020 collegi vintage.** The
`CU20_COD`/`SU20_COD` assignment is **published by the source and fixed by
D.Lgs. 177/2020**. Comuni do merge and get renamed in reality, so the
7,904-row table diverges from the current comune list over time — but
Phase 30 designed the failure to be an **honest absence**: a post-2020 name
returns nothing rather than a wrong collegio
([`30-comuni-geocoding.md`](30-comuni-geocoding.md) §2(b)). And the
decisive point for *this* ADR: **refreshing this table would be actively
wrong.** A current-vintage ISTAT comuni product no longer carries the 2020
collegio assignment, so it would not join to the collegi the app ships.
Here refresh is not merely unnecessary — it is the defect.

---

## 2. Classification by consequence

### 2.1 Class A — cannot go stale within the legislature

Collegi boundaries (147 Camera + 74 Senato uninominali, 49 + 26
plurinominali), the comune→collegio assignment, closed membership
intervals, and every recorded vote. Fixed by law until redistricting, or a
record of a past event. **Consequence of never refreshing: none.** 91 % of
the bundle.

### 2.2 Class B — ages visibly and harmlessly

`retrievedAt` (10 rows) and `generatedAt`. They age at exactly one day per
day and are *already the disclosure*: the number the user reads is the
thing that is aging. **Consequence: none beyond the user seeing an older
date**, which is the intended behaviour, not a failure.

### 2.3 Class C — ages **silently** and misstates a **named person**

This is the class that matters, and the only one that justifies any action.

Three shipped claims are about the present tense and about individuals:

1. **Who is serving.** `representatives.json` carries 601 people (400
   Camera + 201 Senato). Measured turnover, from the raw vote cache: the
   30 events involve **404 distinct deputies**, of whom **5 are absent from
   the 2026-07-18 deputies snapshot** — `p302824`, `p307304`, `p307571`,
   `p308883`, `p32460`, whose last recorded votes fall between 2025-12-03
   and 2026-02-12 (47 dropped position rows, Phase 27 §5). So **at least
   5 of 400 Camera seats changed occupant inside the 9-month vote window**
   — a lower bound, since a departure-and-replacement fully inside the
   window is invisible to this method. Consequence when stale: a former
   deputy is shown as serving, on their collegio page and in the
   representatives list, and their **replacement is absent from the app
   entirely**.
2. **Which group a named person belongs to.** `representatives.json`'s
   `party` / `parliamentaryGroup` are rendered for named individuals at
   `RepresentativeProfileView.swift:79` and `:83`, and as a coloured party
   chip in `DistrictDetailView` and `RepresentativeListView`. Measured
   rate: **19 switch events across 14 deputies in the trailing 12 months**
   (§1.2).
3. **The open end of each membership interval** — the same fact in another
   shape, for the 400 Camera deputies.

**Why it is silent, precisely.** `representatives.json` (2026-07-18) and
`memberships_camera.json` (2026-07-22) drift **in the same direction
together**: when a deputy switches group after the snapshot, both files
keep asserting the old group, so they remain *mutually consistent* while
both are wrong. Consequently:

- `validate_data.py`'s cross-file reconciliation stays green — it compares
  the two artifacts to each other, not to the world.
- `MembershipTests.testEveryVotingDeputyGroupAtTodayMatchesShippedGroup`
  ([`MembershipTests.swift:105`](../../PoliticiTests/MembershipTests.swift:105))
  compares `membershipAt(today)` against the shipped `party` — **both
  sides come from the same snapshot**, so it is tautologically green
  forever and **cannot** detect real-world drift. That is not a defect in
  the test (it guards the internal invariant it was written for); it is
  the reason no automated signal exists.
- The app itself has no clock-based check and, being local-first, no way
  to acquire one.

**Rate and consequence together.** Extrapolating the measured rates, a year
without a pipeline refresh yields roughly **14 deputies shown under the
wrong parliamentary group** and **≥7 seats whose occupant is wrong** — on
the order of **20 of 601 named individuals misstated, silently**. The
Senato side carries the same exposure with *less* instrumentation: there is
no `ocd:aderisce` equivalent imported for its 201 senators, so its group
switching rate is **unmeasured** and no interval file exists at all.

### 2.4 This is the same family as Phases 28, 29 and 30B — stated explicitly

The requirements ask for this connection by name, and it holds exactly:

| Phase | The rule it established |
|---|---|
| 28 | `membershipAt` returns **nil** for an uncovered date — a caller must render unknown, **never** the last-known or current group ([`28-membership-history.md`](28-membership-history.md) §5.6) |
| 29 | `Alignment.insufficientData` **carries no number**, so a `Tally(0,0)` cannot be formatted as "0 %" — the misrender is non-representable, enforced by the type ([`29-alignment-metric.md`](29-alignment-metric.md) §14.1) |
| 30B | A comune split across collegi shows **every** assigned collegio, never one; a post-2020 name returns **nothing**, never a guess |

Each refuses to substitute a plausible value for an unknown one. Class C is
the same failure mode displaced in **time** rather than in coverage: the
app substitutes *the group as of 2026-07-22* for *the group now*, without
saying so. The difference is that Phases 28–30B could make the substitution
non-representable in the type system, and this one cannot — an offline app
has no way to know the present. **What is available instead is
disclosure**, which is why §6 concludes disclosure is the deliverable and
refresh is not.

### 2.5 Class D — frozen-correct, diverges from reality, degrades to absence

The 7,904-comune table (§1.2). Distinct from Class C because the failure is
a **failed lookup, not a wrong answer**, and because refreshing it would
break the legally-pinned join. The magnitude — how many comuni have merged
or been renamed since 2020 — is **not measurable offline from the bundled
data**, and measuring it needs a network act outside this phase's scope. It
is deliberately left unquantified rather than estimated (constraint #4).

---

## 3. The decision on live refresh: **DEFERRED**

Re-derived from §1–§2, not inherited.

**3.1 It is not this document's decision to reverse.** `CLAUDE.md`
constraint #3 makes local-first-at-runtime a **standing constraint**, and
plan rule 7 makes `CLAUDE.md` win over any phase file. Shipping live
refresh would require the user to amend constraint #3 first. This ADR can
recommend; it cannot authorize.

**3.2 The measured case against, on current state.**

1. **91 % of the bundle cannot change** (§1.1). A refresh mechanism would
   carry the network stack, the failure modes, the partial-state handling
   and the privacy surface of an online app in order to reach **8.88 %** of
   the data.
2. **For Class D it is worse than useless** — refreshing `comuni.json`
   against a current ISTAT product would break the D.Lgs. 177/2020 join
   (§1.2). Any live-refresh design would have to carve it out explicitly.
3. **Phase 29's metric gains nothing** — its staleness exposure is
   measurably zero (§1.2).
4. **The 8.88 % that does age already has a refresh path**: `make refresh`
   → the refetch protocol → the generated-data change protocol, where every
   diff in every generated file is inspected and explained before commit.
   That protocol has caught two real defects (a silently-advancing
   `retrievedAt` in Phase 14; a byte-identity break from a `"regione": null`
   key in Phase 16). A runtime refresh would **bypass** human review of
   exactly the data that is about named people — replacing a reviewed
   update with an unreviewed one, on the highest-consequence class.
5. **Nothing in Phases 27–30B created a new argument for it.** The
   requirements' premise — that the data underneath the decision changed
   materially — is correct, and re-examining it changed the *supporting
   reasoning* substantially (the exposure is narrower and better
   characterized than "the data is a snapshot"), but it moved the
   conclusion in the direction of **more** deferral, not less.

**3.3 What re-deriving *did* change.** The old roadmap framing treated
refresh as the open question and disclosure as an afterthought. The
measurement inverts that: the real, live, measured problem is a **silent
misstatement about named people at ~1.6 group switches per month**, and the
available remedy for an offline app is disclosure, not refresh. That is why
this phase ships a disclosure line and no refresh machinery.

**3.4 The shape it would have to take if ever revisited.** Recorded so a
future session inherits a design constraint, not a blank page: an
**explicit, user-initiated, clearly-labelled exception** — never background
or automatic; scoped to Class C only (`representatives.json` +
`memberships_camera.json`), never Class A or D; failing to an unchanged
bundle rather than a partial one; disclosing what it fetched and when; and
preceded by a user amendment to `CLAUDE.md` constraint #3. Anything
automatic, background, or whole-bundle is out of scope by construction.

---

## 4. What is *not* decided here

- **Senato votes** and **push notifications** stay on the deferred list in
  [`00-baseline-and-rules.md`](../plan/00-baseline-and-rules.md) for their
  own recorded reasons; neither is touched by this ADR.
- **A Senato membership-history import** is *not* proposed here. §2.3 notes
  the Senato's unmeasured exposure as a fact; deciding whether to close it
  is a scoped data phase with its own gate, not a line in a staleness ADR.

---

## 5. Trigger conditions — what would change the answer

Pinned so this is not re-litigated from scratch. Any **one** of these
re-opens §3; none of them is a countdown, and none is rendered in the app.

1. **A legislature event.** Dissolution, a new legislature, or a
   redistricting decree superseding D.Lgs. 177/2020. This invalidates
   Class A itself — the 91 % that "cannot change" is scoped *to legislature
   XIX*, and the refetch protocol's standing currency re-verify
   (`probe_senato_legislature_currency.rq`) is the existing detector.
2. **Distribution beyond a prototype.** The measured Class-C misstatement
   rate (~20 named individuals per year) is defensible for a local,
   self-built prototype whose Home screen states its own vintage. It is not
   obviously defensible for an app installed by people who did not build
   it and cannot run `make refresh`. Shipping to anyone else re-opens this
   as a **release** question, not a technical one.
3. **A measured divergence the pipeline cannot close.** If a refetch ever
   shows the reconciliation in `validate_data.py` failing structurally —
   e.g. group entities that no longer reconcile, or a deputy count that
   moves off 400 — the offline path itself is under strain and the trade-off
   changes.
4. **A user-visible error class that disclosure cannot cover.** Today the
   failure is "a stale but plausible group label". If a future feature makes
   staleness produce something a caption cannot honestly qualify — a
   computed figure attached to a named person that depends on *current*
   affiliation, unlike Phase 29's metric which depends only on past ones —
   the disclosure remedy stops being sufficient.
5. **The elapsed-time trigger, stated as a review not a threshold.**
   Because Class C degrades continuously rather than at a cliff, no month
   count is defensible and none is invented. The honest trigger is
   procedural: **any phase that refetches any source re-reads §2.3's rates
   and confirms they still hold.** Phase 32A carries this forward as part
   of release prep.

**Explicitly not a trigger:** the mere passage of time with the app
unchanged. That is the condition this ADR already priced in.

---

## 6. The disclosure decision — answered explicitly

Asked before any code was written, per the phase's scoping. Both answers
**quoted verbatim**:

> **Footer:** "Ship the footer (Recommended)"
> **Profile line:** "No — footer only, pin a trigger (Recommended)"

### 6.1 "Already adequate via the existing sources screen" — rejected, with reasoning

Stated as a decision rather than by omission, as the requirements ask.
Before this phase the app disclosed vintage in exactly two places, both on
`FontiEDatiView`, reached by tapping an info button:

- a per-source `"Dati aggiornati al: {date}"` line on each of 10 cards;
- an *Avvertenze* bullet, `"I dati mostrati sono uno snapshot e potrebbero
  non essere aggiornati."`

Both are accurate and neither is removed. They are **not adequate on their
own**, for one specific reason: the Class-C misstatement appears on a
**named person's profile**, and the only statement of vintage sat on a
different screen the user must choose to visit. A user can read every
screen that names a politician and never encounter the fact that the app is
a snapshot. Raising one factual line to the primary screen closes that gap
at the cost of one sentence.

### 6.2 Where, and why not further

**Shipped: the Home footer**, inside the existing "Informazioni e fonti"
button. Deliberate: the footer states one fact — the last retrieval across
all sources — and the per-source breakdown that qualifies it is then **one
tap away**, in the same control. It is a plain statement in secondary text
with **no threshold, no relative phrasing ("2 mesi fa"), and no warning
colour** — inventing an "outdated after N months" rule is expressly out of
scope, and the app has no basis for such a judgment.

**Declined for now: a vintage line on the representative profile**, i.e. at
the exact point of the Class-C misstatement. It is the strictly more honest
placement and the reasoning for declining is not that it is unnecessary:

- it means new Italian copy rendered on 601 named-person screens, where a
  date sitting beside a person's name and party risks reading as a claim
  about *that person* rather than about the data;
- the phase's declared deliverable is one Home line, and the wording of a
  per-profile qualifier is a design decision that deserves its own ask;
- Phase 32A already owns release prep and the accessibility reconciliation
  for these screens.

Recorded as trigger 2 in §5: **if the app is ever distributed to people who
cannot run `make refresh`, the per-profile disclosure is re-opened**, and
that is the specific condition that would flip it.

**Not changed, deliberately:** the `FontiEDatiView` *Avvertenze* bullet
(still accurate, and now complemented rather than replaced) and the
per-source date lines (they are the breakdown the footer's max summarizes).

---

## 7. Pinned Italian strings (the phase's new shipping vocabulary)

One new string, pinned verbatim here and by
`DataVintageTests.testDataVintageTextIsPinnedItalianAndAbsentWhenManifestFailsToLoad`.

- **`ManifestService.dataVintageText(for:)`** —
  `Ultimo aggiornamento dei dati: «data»`
  On the current manifest: **`Ultimo aggiornamento dei dati: 22 luglio 2026`**
  (max `retrievedAt` = 2026-07-22, formatted by the existing
  `DateFormatting.longString` Italian-locale helper).

**Why not the phase file's `"Dati aggiornati al {date}"`.** The value is a
**max**, and the manifest carries a spread: 2026-07-22 (votazioni,
adesioni), 2026-07-21 (Senato), 2026-07-18 (Camera deputati + the five
ISTAT rows), 2026-07-17 (the sample fixture). "Dati aggiornati al 22 luglio"
asserts that everything is current to the 22nd, which is false for six of
the ten rows. Worse, the gap is **structural and widening by design**:
minimal-scope refetches are the repo's *preferred* practice under the
refetch protocol, and Phases 27 and 28 each advanced a single source alone,
which moves the max while leaving the rest untouched. "Ultimo aggiornamento
dei dati" states the last retrieval, which is exactly what the max is.
Constraint #4 (never a plausible-sounding value the source does not
support) and plan rule 7 (reality wins over the phase file) both point the
same way.

**No accessibility identifier is set on the line.** It sits inside a
`Button` label, so the button is the single accessibility element and a
child identifier would be silently unreachable — the container-shadowing
trap `CLAUDE.md` records from Phase 30B. The identifier went on the button
instead (`home.footer.fonti`), where it works. VoiceOver reads the button
as its two lines combined.

### 7.1 The sample-fixture rule — decided, no exclusion

`phase-31.md` leaves open whether to exclude the fixture row
(`prototipo-dati-dimostrativi`) from the max "if a rule is needed".
**Decision: no exclusion**, for three reasons:

1. It changes nothing today — 2026-07-17 is the **oldest** of the ten
   dates, not the newest.
2. `make_manifest.py` **never advances it**: only `real_sources(...)` rows
   get a fresh `retrievedAt`; the fixture row is carried forward verbatim
   from the committed manifest. It cannot become the max from a normal
   pipeline run.
3. The max is the only value that makes the rendered sentence true
   ("nothing here was retrieved after this date"). If the fixture row ever
   *did* become the max, that would be a pipeline defect worth surfacing —
   an id-keyed exclusion would hide precisely the condition worth seeing.

Pinned by `testLatestRetrievedAtIncludesTheSampleFixtureEntryByDesign`, so
the choice is deliberate rather than accidental.

---

## 8. A real defect found and fixed: display dates were off by one west of Rome

Found because this phase ships a date, and **verified rather than assumed**.

Every `Date` this app renders is parsed from a bare `yyyy-MM-dd` at
**midnight Europe/Rome** — `DateFormatting.parseISODate` and
`Vote.dateFormatter` both pin that zone. But `DateFormatting.longDateFormatter`
and `shortDateFormatter` set only a locale, leaving them on the **device's**
timezone. Midnight in Rome is the previous calendar day anywhere west of
it. Measured with a standalone Foundation harness over the exact shipped
formatter configuration, on `2026-07-22`:

```
Europe/Rome          -> 22 luglio 2026
UTC                  -> 21 luglio 2026
America/New_York     -> 21 luglio 2026
America/Los_Angeles  -> 21 luglio 2026
Asia/Tokyo           -> 22 luglio 2026
```

**Blast radius (pre-existing, not introduced here):** every vote date in
`VotazioniListView` and `VoteHistoryView`, and every `"Dati aggiornati al:"`
line on `FontiEDatiView` — silently one day early for any user west of
Rome. And the new footer line would have inherited it.

**Why the suite never caught it.** `DateFormattingTests` builds its
fixtures at **noon** Europe/Rome, with a comment stating that this is "to
avoid any timezone-boundary flakiness when the formatter renders using the
system default timezone" — the test sidesteps exactly the condition the app
hits, since real data is always midnight.

**Fix:** pin both display formatters to `Europe/Rome`, with a comment
recording why they must not be relaxed to the device zone (these are Rome
calendar days — sitting dates, retrieval dates — not instants to localize).
This can only correct output, never regress it: there is no call site whose
`Date` came from anywhere but a Rome-pinned parser.

**Two regression tests, and an honest note on what each proves.**
`testDisplayFormattersReadDatesInTheZoneTheParsersProduceThem` asserts
parse and format agree on the zone — structural, and meaningful on **any**
runner. `testLongStringRoundTripsAMidnightRomeISODate` asserts the
user-visible round trip — behavioural, but it only *bites* on a non-Rome
runner, and this session's verification ran on a **CEST (UTC+2)** host, so
on this machine it passed both before and after the fix. The structural
test is the real guard; the behavioural one is stated as conditional rather
than presented as proof.

---

## 9. Tests — 219 → 225 (+6, all deliberate)

Baseline **measured from the `.xcresult`** on the Phase 30B tip, per the
additional requirements: `totalTestCount 219, passedTests 219, failedTests 0`
([`30b-comuni-assignment.md`](30b-comuni-assignment.md) §"Spec 9").

| Test | Covers |
|---|---|
| `DataVintageTests.testLatestRetrievedAtIsMaxOverFixtureSourcesSkippingUnparseable` | spec 2 — max over a hand-verified fixture (2025-12-31 / 2026-03-14 / 2026-01-05 → **2026-03-14**); unparseable row skipped; empty → nil |
| `DataVintageTests.testLatestRetrievedAtIncludesTheSampleFixtureEntryByDesign` | §7.1 — the no-exclusion decision, pinned |
| `DataVintageTests.testDataVintageTextIsPinnedItalianAndAbsentWhenManifestFailsToLoad` | spec 2 + spec 3 — the pinned Italian string, and the `loadError` path yielding **nil**, never a placeholder |
| `DataVintageTests.testShippingVintageMatchesIndependentlyComputedMaxRetrievedAt` | the shipping manifest, expected value computed independently (ISO strings sort lexicographically, so a plain string `max` on the decoded JSON) — **no date pinned**, so a refetch keeps it green with no re-pin |
| `DateFormattingTests.testDisplayFormattersReadDatesInTheZoneTheParsersProduceThem` | §8 — structural guard, meaningful on any runner |
| `DateFormattingTests.testLongStringRoundTripsAMidnightRomeISODate` | §8 — behavioural round trip (conditional on a non-Rome runner) |

**Final `.xcresult`: `totalTestCount 225, passedTests 225, failedTests 0`,
result `Passed`.** No flake, no truncation ambiguity: the collision-safe
occurrence count corroborates exactly — 213 unit `func test…(` + 1 `@Test`
+ 11 UI = **225**, and the `.xcresult` carries 225 Test Case nodes. "Zero
regressions" now means **225** plus documented deliberate additions.

**Build:** `** BUILD SUCCEEDED **`, zero warnings, zero errors. (One
warning was raised and fixed rather than shipped: `Optional.map` takes a
nonisolated closure, so passing a reference to the MainActor-isolated
`dataVintageText(for:)` warned under
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`; the property is written out
instead.)

**Accessibility audit — measured, not assumed.** The `audit-Home`
attachment from this run is **identical** to the inventory Phase 24
recorded (6 `contrast`, 8 `dynamicType`, 3 `textClipped`, same elements):
the footer adds **zero** recorded findings. Honest caveat: `Home` is a
`ScrollView` and the footer sits below the fold, so the audit — which
covers the visible screen — did not cover it before this change either.
Noted for Phase 32A rather than claimed as clearance.

---

## 10. Data-visibility (baseline rule 9 — declared scope)

This phase makes a datum (the max `retrievedAt`) visible somewhere new, so
the copy describing the old visibility was checked:

- **`README.md` — updated, three regions.** (a) The "All data is a
  snapshot" limitation said "the app has no way to know it's stale beyond
  the displayed date", which was written when the only displayed date was
  on the sources screen; it now names the Home line and points at this ADR.
  (b) The roadmap's "Possible live data refresh — still deferred pending
  the 'is that compatible with local-first at all' decision" is now
  **decided**, not pending, and links here. (c) A **stale API name**
  unrelated to this phase but false in the shipped tree: the roadmap
  described the metric as `GroupAlignment.score(…)`, which Phase 29's
  commit 2 replaced with `tally(…)` / `alignment(…)`
  ([`29-alignment-metric.md`](29-alignment-metric.md) §14.1) without
  updating this line. Corrected here rather than left to rot.
- **`FontiEDatiView` — deliberately not changed.** Its *Avvertenze*
  snapshot bullet and its per-source `"Dati aggiornati al: {date}"` lines
  are both still accurate; the footer summarizes them rather than
  superseding them, and the button carries the user straight to the
  breakdown. (Its rendered dates *do* change on non-Rome devices — that is
  §8's correction, not a copy change.)
- **`docs/DATA_SOURCES.md` — deliberately not changed.** No new bundled
  source, no changed provenance, no coverage claim invalidated; the
  per-source `retrievedAt` table it mirrors from `sources.json` is
  unchanged.
- **`HomeView` "Come funziona l'elezione" — deliberately not changed.** It
  explains the electoral system only; nothing in it became inaccurate.
- **No generated data was touched.** No pipeline ran, so the
  generated-data change protocol has an empty diff to explain, and
  `make manifest` was deliberately **not** run (it would rewrite
  `generatedAt` to today for no reason).

---

## 11. Acceptance criteria (from `phase-31.md`)

| # | Criterion | Outcome |
|---|---|---|
| 1 | ADR committed with the decision and pinned revisit criteria | **Met** — §3 (decision, re-derived), §5 (five pinned triggers + one explicit non-trigger) |
| 2 | Unit test: footer string derives from a fixture manifest's max `retrievedAt` (value verified independently); absent when the manifest fails to load | **Met** — §9: hand-verified fixture max, plus the shipping test whose expected value is computed independently by string `max`; `loadError` path asserts nil at both levels |
| 3 | String pinned in the report, Italian | **Met** — §7 |
| 4 | Suite green vs the current baseline plus documented additions | **Met** — §9: `.xcresult` 219 → **225**, 0 failures, occurrence count corroborates |

**Validation strategy (phase file):** "ADR reviewed against the standing
constraints (it must not soften local-first)" — §3.1 states the opposite of
softening: constraint #3 is treated as binding and unamendable by this
document, and §3.2 finds the measured case for refresh *weaker* than the
roadmap's framing implied. "Footer verified against a manifest fixture" —
§9.

**Deviations, stated plainly:**
1. **Footer wording** — `"Ultimo aggiornamento dei dati: {date}"` instead
   of the phase file's `"Dati aggiornati al {date}"`, because the value is
   a max over a spread of dates and the phase's wording asserts more than
   the manifest supports (§7). Under plan rule 7.
2. **A `DateFormatting` fix outside the phase's nominal diff scope** (§8) —
   a pre-existing one-day error in every rendered date, found because this
   phase ships a date. Fixed with two regression tests rather than shipped
   on top of; the behavioural test's conditionality is disclosed rather
   than glossed.
3. **One `README.md` correction unrelated to staleness** (§10c) — a stale
   `GroupAlignment.score(…)` API name left by Phase 29's own follow-up
   commit. Corrected in passing, recorded here so it is not mistaken for
   Phase 31 work.
4. **The per-profile disclosure is declined, not deferred silently** (§6.2)
   — the reasoning and the specific condition that would flip it are
   recorded.

---

## 12. Diff scope for this commit

```
Politici/Services/ManifestService.swift    (latestRetrievedAt + dataVintageText; stale "no UI consumes this" comment corrected)
Politici/Models/SourcesManifest.swift      (stale "no UI in v2 yet" doc comment corrected)
Politici/Utilities/DateFormatting.swift    (display formatters pinned to Europe/Rome — §8)
Politici/Views/HomeView.swift              (footer: the data-vintage line, inside the existing button)
PoliticiTests/DataVintageTests.swift       (new — 4 tests)
PoliticiTests/DateFormattingTests.swift    (+2 regression tests — §8)
README.md                                  (rule 9: snapshot limitation, roadmap decision, stale API name)
docs/v4/31-live-refresh-adr.md             (new — this ADR/report)
docs/plan/README.md                        (Phase 31 status row: pending -> done)
```

No generated data file changed; no pipeline ran; no network act; no new
bundled data source.

Remote actions are the user's. Not run here:

```
git push origin v4
```
