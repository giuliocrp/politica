# V4 Phase 28 — Group-Membership History, Camera [GO-STORICO: **GO**; USER-GATED network: **executed**]

Imports per-deputy parliamentary-group membership **intervals** so the group
a deputy held **on a vote's date** is computable — the last unmet line of the
`docs/v3/votes-methodology.md` gate (line 6). A new generated artifact
`Politici/Data/memberships_camera.json` (468 intervals for the 400 current
Camera deputies), a pure `MembershipService.membershipAt(representativeId:date:)`
lookup, importer + validator interval invariants, and the methodology gate
re-measured in this same commit (**5 of 6 → 6 of 6**). **No UI** — this is
infrastructure for Phase 29 and honest data in its own right. Senato is out
of scope (the imported votes are Camera-only).

The GO-STORICO gate evaluates **GO** on quoted evidence (§4). Every number
below was produced by a quoted command in this session; the network acts and
the import ran **2026-07-22**, and the shape was verified by probe **before**
any importer code (Q4).

---

## 1. Approvals (quoted verbatim)

Two network acts were gated, split exactly as the Phase 27 handoff instructed
(exploration first — show shape + byte projection — then the real fetch
separately).

**Network act #1 — currency re-verify + exploration probe (steps 1 and 2):**

> "Approved for network act #1 — the currency re-verify and the exploration
> probe (steps 1 and 2). Do NOT run the pipeline fetch until I approve it
> separately."

with a paging instruction —

> "For step 2's paging, reuse Phase 27's Q3 finding (OFFSET stable at LIMIT
> 2000, clean page boundaries on dati.camera.it) rather than
> re-characterizing it."

— and six bring-backs before act #2 (coverage arithmetic; within-day
limitation; deliberate display string; import determinism; reconciliation;
editorial rule for unresolvable cases), all discharged in §5.

**Network act #2 — the pipeline fetch:**

> "Approved — run network act #2, the camera_adesioni.rq pipeline fetch only.
> Everything after it is offline."

with the same six fold-ins plus a carried item —

> "Also close the carried item: measure the 167 baseline from the .xcresult
> rather than deriving it from source, before anything ships."

— discharged in §9.

No other network act was performed. No app networking was added: the runtime
stays strictly local-first; all network work is the `tools/` developer
pipeline.

---

## 2. Refetch-protocol checklist

1. **Legislature XIX re-verified current at fetch time, before any other
   network act:** `tools/probes/probe_senato_legislature_currency.rq` via
   `run_probe.py` (the aggregate-free `SELECT DISTINCT` the protocol pins).
   21 distinct `?legislatura`; the highest **integer is 19** with nothing
   beyond it (the two non-integer labels are the historical "Assemblea
   Costituente" / "Consulta Nazionale"). XIX is current.
2. **Minimal-scope fetch:** only `tools/queries/camera_adesioni.rq` was
   fetched (`tools/fetch_camera_adesioni.py`) — the deputies, votes, Senato,
   and ISTAT caches were **not** touched. This is a **new** source, not a
   refresh of an existing one, so no existing source count could drift; the
   new cache is 468 rows.
3. **Manifest + attribution re-synced in this commit:** a new
   `Data/sources.json` entry (`camera-dei-deputati-adesioni-gruppi-xix-legislatura`,
   `retrievedAt` **2026-07-22** from the new `camera_adesioni`
   fetch-metadata key — the deputies `retrievedAt` **stays 2026-07-18**),
   `docs/DATA_SOURCES.md` (new section + cross-check note, now **9 entries**),
   `tools/SOURCES.md`, and the gitignored `tools/raw/SOURCES.txt`.
4. **Probe output quarantined:** every probe response is under
   `tools/probes/output/` (gitignored) — never an import source. The
   committed reproducible artifacts are the pinned queries
   (`tools/queries/camera_adesioni.rq`,
   `tools/probes/probe_camera_adesioni_shape.rq`); the ad-hoc coverage/
   boundary analysis was scratch over that quarantined output, and its
   conclusions are pinned permanently in `tools/validate_data.py` and
   `PoliticiTests/MembershipTests.swift`.

---

## 3. The exploration probe (#1) and Q4 — the shape, verified not assumed

The v2 deputies query proves an `ocd:aderisce` carries `ocd:endDate` (it
MINUS-es adesioni that have one) and a group via `ocd:rif_gruppoParlamentare`
— but it **never SELECTs the start-date predicate or the full adesione
vocabulary**, so those were unknown. Step 1
(`tools/probes/probe_camera_adesioni_shape.rq`, a plain `SELECT DISTINCT ?p`)
enumerated every predicate on XIX deputati's adesione resources:

```
ocd:componente   ocd:endDate   ocd:motivoTermine
ocd:rif_gruppoParlamentare   ocd:startDate   dc:date   rdfs:label
```

**`ocd:startDate` is the discovered start predicate** (mirror of
`ocd:endDate`; `YYYYMMDD`). A single-record dump (De Corato, p200291)
confirmed the concrete shape and one decisive structural fact: **the
`ocd:aderisce` node is a blank node** (`b4084…`), whose label is not stable
across requests — so the artifact id must be composed, never source-minted.

Step 2 (full dump, one `LIMIT 2000` page — **468 rows / 400 persons**, well
under the ceiling Phase 27's Q3 established as stable, so no paging needed)
materialized every interval's `(person, group name/sigla, start, end)`. The
full group vocabulary is the **same 10 clean groups** as the deputies query
(AVS, AZ-PER-RE, FDI, FI-PPE, IV-CR, LEGA, M5S, MISTO, NM(N-C-U-I)M-CP,
PD-IDP); **`MISTO` is a single group entity, not fragmented sub-components** —
the disclosed Gruppo Misto risk did not materialize. `ocd:motivoTermine` is
uniformly `"Cessazione"` on the 68 closed intervals and empty on all 400
open ones.

---

## 4. GO-STORICO gate — decision: **GO**

Each NO-GO condition evaluates **false** on quoted evidence from the 468-row
dump (§3):

| NO-GO condition | Evidence | Triggered? |
|---|---|---|
| Missing start dates | **0** adesioni missing `ocd:startDate` (all 468 parse) | **No** |
| Ambiguous overlapping intervals not resolvable by a documented rule | **0** raw overlaps; the only boundary ambiguity (same-day handoff) is resolved by the documented half-open rule at **100 %** unique resolution (§5.1–5.2) | **No** |
| Group entities that can't be reconciled to shipped names | **400/400** open intervals reconcile (sigla equality + `parliamentaryGroup` prefix-match), 0 mismatches (§5.5) | **No** |

Supporting cleanliness (all enumerated, none smoothed over — §5.3): 0 missing
groups, 0 unparseable dates, 0 intra-person gaps, 0 multiple-open, 0 deputies
without an adesione. **GO.**

---

## 5. The six bring-backs (discharged)

### 5.1 Coverage against the shipped votes — corrected arithmetic
The universe is **not** 399 × 10. Precisely:
- **N = 11,899 position rows** in `votes.json` (30 events × ~396.6 positions).
- **M = 3,967 distinct `(deputy, vote-date)` pairs** — 399 deputies over 10
  distinct sitting dates, but not every deputy on every date: 394 appear on
  all 10, 1 on 9, 1 on 6, 3 on 4 → 394·10 + 9 + 6 + 3·4 = **3,967** (not
  3,990).
- **Resolution rate, half-open rule: 11,899 / 11,899 = 100.0000 %** of rows
  and **3,967 / 3,967 = 100 %** of distinct pairs resolve to **exactly one**
  interval. Zero unresolved, zero multi. **This is what lets line 6 flip.**

**The 399-vs-400 gap** is **Lorenzo Fontana (p307591), President of the
Camera dei Deputati**: he holds a LEGA membership interval like every deputy,
but by convention the President presides and casts no roll-call votes, so he
has **zero positions** in `votes.json`. A membership without positions —
legitimate, not a defect.

### 5.2 Within-day limitation — disclosed, not hidden
Boundary geometry across the 52 switchers: **68 consecutive interval pairs,
all same-day** (old `endDate` == new `startDate`); **0 adjacent, 0 gap, 0
overlap**. The source records only a **date**, not a time, so for a
same-day handoff it **cannot order a vote relative to the switch within that
day** — a genuine limitation. The half-open `[start, end)` rule resolves it
by assigning the switch day to the **new** group (the one the deputy joined),
which is also the only rule that yields unique resolution (the closed rule
double-resolves). This is exercised by **real shipped data**: **p301459
(Laura Ravetto)** switched **LEGA → MISTO on 2026-05-20**, a real vote date
(sitting 664, 3 votes) — half-open puts her in **MISTO** that day, and
`representatives.json` records her current group as **MISTO**, so the rule
matches the shipped gruppo. The closed rule flags exactly this case as the
lone double-resolution.

### 5.3 Messy cases — enumerated
| Pathology | Count |
|---|---|
| Missing `startDate` (NO-GO trigger) | 0 |
| Missing group / name / sigla | 0 |
| Unparseable dates | 0 |
| Intra-person overlaps (raw) | 0 |
| Intra-person gaps (>1 day) | 0 |
| Persons with >1 open interval | 0 |
| Persons with 0 open interval | 0 |
| Camera deputies with no adesione | 0 |

468 = 400 open (one per deputy) + 68 closed = 68 same-day handoffs. All
reconcile.

### 5.4 Display string — decided deliberately
The reconciled group `dc:title` is **malformed at source** — truncated at a
parenthesis, e.g. `"MISTO (MISTO) (18.10.2022"` (unterminated). Decision:
- **`memberships_camera.json` ships both** `groupName` (the `dc:title`,
  preserved **exactly** — never "repaired"; reconstructing the missing suffix
  would be fabrication) **and** `groupSigla` (the clean
  `dcterms:alternative`: `"MISTO"`, `"FDI"`, …).
- **Any UI must render the `groupSigla`** — the canonical, clean identifier.
  `groupName` is kept for provenance/traceability and is documented as
  source-defective in the model, the importer, and the manifest note.

### 5.5 Reconciliation with `representatives.json`
**400 / 400** open intervals reconcile: the open interval's sigla **equals**
the shipped `party`, and its group `dc:title` **prefix-matches** the shipped
`parliamentaryGroup` (identical in fact — both carry the same source
truncation). **0 mismatches.** The 4-day gap between the deputies fetch
(2026-07-18) and this fetch (2026-07-22) produced **no drift**. Both the
importer and `validate_data.py` fail loudly on any mismatch (none occurred).

### 5.6 Editorial rule for unresolvable cases — pinned before implementing
`membershipAt(representativeId:date:)` returns **nil** for any date not
covered by an interval (e.g. before a deputy's first membership). A caller
must render nil as **unknown** — **never** the last-known or current group.
Inferring a party affiliation for a named politician is fabrication; there is
no fallback path in the function. (Coverage is 100 % for the *current*
sample, but the rule stands for any future sample.)

---

## 6. The artifact + schema

`Politici/Data/memberships_camera.json` —
`{"schemaVersion":1,"memberships":[…]}`, each record:

```json
{
  "id": "m_p301459_20221018",
  "representativeId": "p301459",
  "groupName": "LEGA - SALVINI PREMIER (LEGA) (18.10.2022",
  "groupSigla": "LEGA",
  "start": "2022-10-18",
  "end": "2026-05-20"
}
```

- **id** is composed `m_<personId>_<startYYYYMMDD>` (the source node is a
  blank node). Uniqueness verified: **0** collisions — no person has two
  intervals sharing a `startDate` (§7).
- **start / end** are ISO `yyyy-MM-dd`; `end: null` marks the single open
  interval. Intervals are **half-open `[start, end)`**.
- **Measured 108,917 B = 106.4 KiB** — matches the pre-fetch projection
  exactly (~233 B/record over 468 records). This is ~1 % of the 5.40 MiB
  `Data/` and of the ~10 MiB soft ceiling. **`votes.json` was not touched**:
  per-position group fields (~28 B × 11,898 ≈ 333 KB) would breach its ~329
  KB gate headroom — the normalized interval file is the correct path.

---

## 7. Import + determinism, and validator invariants

**Import** (`tools/import_memberships.py`, offline, runs last in `make import`
because it reads the just-built `representatives.json` to scope + reconcile):

```
OK: 468 intervalli (400 aperti, 68 chiusi) per 400 deputati in
    Politici/Data/memberships_camera.json (106.4 KiB)
  deputati con più di un gruppo nel tempo: 52
```

**Determinism proven by diff, not inspection** (blank-node source, unordered
SPARQL): the importer sorts explicitly on the composed key
`(representativeId, start, id)` before serializing; run **twice**, the
artifact was **byte-identical** (`diff` empty), SHA-256
`d2ec2f459a9bcb28ddf7f8f1010fe1551b9e55f7ee49ebd6dc3d49dcf5cd675c`.
**Composed-id uniqueness** confirmed: 0 `(person, startDate)` collisions.

The importer fails loudly (writes nothing) on: a persona not in
`representatives.json`, a deputy with no interval or ≠1 open interval, a
missing/unparseable `startDate` or group, an id collision, an overlap under
`[start, end)`, or an open interval whose group can't be reconciled.

**Validator** (`tools/validate_data.py`, mirrors the invariants on the
committed artifact — belt and suspenders): `make validate` exit **0**, with

```
OK: 468 intervalli di adesione (400 aperti) per 400 deputati … (106.4 KiB)
OK: integrità referenziale adesioni coerente — 468 intervalli, 400 deputati,
    52 con più gruppi nel tempo
```

The new checks: schema (`{schemaVersion, memberships}`, version 1), byte gate
**`MAX_MEMBERSHIPS_FILE_BYTES = 256 KiB`** (measured 106.4 KiB = **41.6 %**, a
coarse drift backstop — the precise scope guard is referential integrity),
parseable dates, half-open validity (`start < end`), exactly one open interval
per deputy, non-overlap, id uniqueness, and the cross-file reconciliation
(every deputy is a shipped Camera deputy; every Camera deputy has ≥1 interval;
open-interval group reconciles by sigla + prefix).

---

## 8. Swift — model, service, editorial rule (no UI)

- `Politici/Models/Membership.swift` — `GroupMembership` (Identifiable,
  Codable; `start`/`end` decode as `yyyy-MM-dd` via the shared
  `Vote.dateFormatter`) + `MembershipsFile`.
- `Politici/Services/MembershipService.swift` — loads
  `memberships_camera.json` **eagerly on the main actor** (like
  `RepresentativeService`; the file is small, so no lazy/off-main machinery
  like `VoteService`). `membershipAt(representativeId:date:)` (instance) and
  the pure static `membership(at:in:)` for fixture testing implement half-open
  containment `start <= date < end` (or `end == nil`); on the validated
  non-overlapping data at most one matches, and if two ever did the
  latest-starting wins (a switch date resolves to the joined group).
- `ServiceContainer` gains `membershipService` so Phase 29 can inject it
  through the environment. **No view consumes it** — the CTA/screens are
  unchanged; the only user-visible change in the whole phase is one
  provenance row in "Informazioni e fonti" (§10).
- Build: `** BUILD SUCCEEDED **`, zero warnings/errors.

---

## 9. Tests — baseline measured from `.xcresult`, then +10 (167 → 177)

**Carried item discharged first:** the 167 baseline was measured from a
`.xcresult` on the current tip **before** any change — `xcresulttool get
test-results summary` reported `totalTestCount 167, passedTests 167,
failedTests 0` (not a from-source occurrence count).

**10 new tests** (`PoliticiTests/MembershipTests.swift`), all deliberate:

| Test | Covers (spec #3/#4) |
|---|---|
| `testMidIntervalResolvesToThatGroup` | mid-interval |
| `testStartDateIsInclusive` | start edge (inclusive) |
| `testSwitchDayResolvesToNewGroup` | end edge (exclusive) + new start (inclusive) |
| `testDayBeforeSwitchIsOldGroup` | the exclusive edge from the other side |
| `testDateBeforeFirstIntervalIsNil` | before first interval → nil |
| `testOpenEndedIntervalCoversFutureDates` | open-ended current interval |
| `testSingleOpenIntervalStartInclusiveMidAndBeforeNil` | never-switched deputy |
| `testShippingMembershipsDecodeWithExpectedStructure` | 400 deputies, one open each, unique ids |
| `testEveryVotingDeputyGroupAtTodayMatchesShippedGroup` | **spec #4** — every voting deputy's group-at-today == shipped party |
| `testShippedSwitcherResolvesAcrossItsBoundaryVoteDate` | real-data anchor (p301459, 2026-05-20/19) |

**Final `.xcresult`: `totalTestCount 177, passedTests 177, failedTests 0`,
`** TEST SUCCEEDED **`** — 167 baseline + 10. "Zero regressions" now means
177 plus documented deliberate additions. The shipping-count itself (468) is
deliberately **not** pinned in a test (it grows as deputies switch groups over
the legislature, like `votes.json`'s count); the pinned invariant is the
stable structure (400 deputies, one open interval each). The p301459 anchor
carries a re-pin comment (a re-pin on a future refetch, not a regression —
same shape as Phase 27's vote anchors).

---

## 10. Data-visibility (rule 9)

- **`Data/sources.json` / "Informazioni e fonti"**: a new provenance row was
  added (`camera-dei-deputati-adesioni-gruppi-xix-legislatura`). Bundling
  undisclosed data is worse than disclosing it, and the screen exists to say
  exactly what data ships and whence; the note states what the dataset is,
  that the sigla is canonical and the extended name preserves the source
  truncation, and that it is Camera-only. This is the **only** user-visible
  change in the phase (provenance disclosure, auto-generated by
  `make_manifest.py` — not feature UI).
- **`README.md`**: the methodology-bullet and roadmap prose that asserted
  "no historical-membership import exists" / "5 of 6" were **now false** and
  were corrected to 6/6 with the infrastructure-not-metric caveat.
- **`docs/DATA_SOURCES.md`**: new source section + cross-check note (9
  entries), kept exactly in sync with `sources.json`.
- **`HomeView` "Come funziona l'elezione"**: **decision not to touch** — it
  explains election/collegio geography only, never parliamentary-group
  visibility, and Phase 28 ships no feature that changes what it describes.

---

## 11. Methodology gate re-measured (same commit) — 5 of 6 → 6 of 6

Per `docs/v3/votes-methodology.md`'s re-evaluation protocol (`votes.json`
unchanged since Phase 27; the change is the new membership data):

| # | Requirement | Phase 27 | Phase 28 | Status |
|---|---|---|---|---|
| 1 | ≥ 30 events | ✓ | ✓ (30 / 11,899) | ✓ |
| 2 | ≥ 3 distinct sittings | ✓ | ✓ (10) | ✓ |
| 3 | ≥ 6 months span | ✓ | ✓ (8.9 mo) | ✓ |
| 4 | ≥ 2 distinct atti | ✓ | ✓ (15 / 9) | ✓ |
| 5 | `astenuto` its own category | ✓ | ✓ | ✓ |
| 6 | group membership at vote date | ✗ | **✓ — `memberships_camera.json` + `membershipAt`, 100 % sample coverage** | ✗ → ✓ |

**6 of 6.** **What this means for Phase 29 — stated plainly, not inherited:**
reaching 6/6 makes **Phase 29 a live phase** (it was structurally blocked
while line 6 was red). It does **not** pre-decide Phase 29's GO — per the
re-evaluation protocol, **Phase 29's session must re-measure this table from
the then-current data and decide GO/NOT-RUN on that fresh measurement**, and
resolve its own open questions (metric tie-breaking + the minimum-denominator
threshold — Q7, needing explicit user sign-off) — never inheriting the 6/6
recorded here. Grep-verified: the pinned metric label / any metric vocabulary
remains **absent from all app code** (present only in the methodology doc);
Phase 28 ships **no metric**.

---

## 12. Acceptance criteria

| # | Criterion (from `phase-28.md`) | Outcome |
|---|---|---|
| 1 | GO/NO-GO evidence per condition, quoted, both outcomes supported | **Met** — §4: GO on quoted per-condition evidence; NO-GO conditions each shown false |
| 2 | Under GO: validator invariants all green | **Met** — §7: `make validate` exit 0; non-overlap, one-open-per-deputy, reconciliation, byte gate |
| 3 | `membershipAt` pure-function tests (mid; both boundary edges; before-first → nil; open-ended; switcher) | **Met** — §9: 7 pure-function tests incl. both edges on the switcher fixture |
| 4 | Shipping test: every deputy in `votes.json`, `membershipAt(today)` == record's group under the normalization | **Met** — §9 `testEveryVotingDeputyGroupAtTodayMatchesShippedGroup` (sigla equality, the Swift twin of the validator reconciliation) |
| 5 | Suite green vs current baseline + documented additions | **Met** — §9: `.xcresult` 167 → 177, all pass; +10 listed |

**Deviations, stated plainly:**
1. **Coverage universe re-stated (N vs M).** The pre-fetch note conflated the
   11,899 position rows with the `(deputy, date)` pair count; §5.1 separates
   N = 11,899 rows from M = 3,967 distinct pairs, both at 100 %. Not a data
   change — a precision correction, folded in per the act-#2 instruction.
2. **A new "Informazioni e fonti" provenance row** (§10) is the one
   user-visible artifact of a "no UI" phase — provenance disclosure of newly
   bundled data, not a feature. Documented as a deliberate rule-9/refetch
   choice, not a silent addition.
3. **Byte gate 256 KiB**, sized from the measured 106.4 KiB with ~2.4×
   headroom for legitimate mid-legislature switching — deliberately looser
   than `votes.json`'s tight 84 % gate because membership counts grow over
   time and referential integrity, not size, is the precise scope guard.

---

## 13. Diff scope for this commit

```
Politici/Data/memberships_camera.json          (new — 468 intervals / 400 deputies)
Politici/Data/sources.json                     (regenerated — +1 adesioni source entry)
Politici/Models/Membership.swift               (new — GroupMembership + MembershipsFile)
Politici/Services/MembershipService.swift      (new — membershipAt half-open lookup)
Politici/Services/ServiceContainer.swift       (membershipService wired for Phase 29)
PoliticiTests/MembershipTests.swift            (new — 10 tests)
tools/queries/camera_adesioni.rq               (new — pinned pipeline query)
tools/probes/probe_camera_adesioni_shape.rq    (new — predicate-discovery probe)
tools/fetch_camera_adesioni.py                 (new — minimal-scope fetch)
tools/import_memberships.py                     (new — offline importer, fail-loud gates)
tools/validate_data.py                         (memberships structural + reconciliation invariants)
tools/make_manifest.py                         (adesioni source entry + derived note)
Makefile                                       (fetch + import wiring)
README.md, docs/DATA_SOURCES.md, tools/SOURCES.md (provenance/copy sync — 9 entries)
docs/v3/votes-methodology.md                   (gate re-measured 5/6 -> 6/6)
docs/plan/00-baseline-and-rules.md             (Q4 marked RESOLVED)
docs/v4/28-membership-history.md               (new — this report)
docs/plan/README.md                            (Phase 28 status row: pending -> done)
```

(`tools/raw/.fetch_metadata.json`, `tools/raw/camera_adesioni_sparql.json`,
and `tools/raw/SOURCES.txt` were also written but are gitignored — the
committed mirrors are `sources.json` and `tools/SOURCES.md`.)

Remote actions are the user's. Not run here:

```
git push origin v4
```
