# V4 Plan — Baseline, Open Questions, Plan-Wide Rules

Shared context for every `docs/plan/phase-*.md` file. Read this first in
any session executing a phase. Prepared 2026-07-21 from the shipped
v3.0-prototype state; every number below was **verified in-session on
that date** (not assumed). Phase 23 re-verifies the volatile ones.

## Verified baseline (2026-07-21)

| Fact | Value |
|---|---|
| Branch | `v4` = `origin/v4` = `origin/main` = `3dc224e` (v3 line merged via PR #2; post-22B record cherry-picked) |
| Tags | `v1.0.0` (6d3b866, user-created), `v2.0-prototype` (72448dc), `v3.0-prototype` (f90f194) — never touch |
| Test baseline | **136 declared / 139 runtime, 0 failures** (94/97 v3 baseline + 42 deliberate; ×4 `testLaunch` template cause). Phase 24 deliberately redefines this — see that file |
| Bundle | 3,201,950 B total (`Data/` minus votes = 2,490,511 B; `votes.json` = 711,439 B = 33.9% of its 2 MiB gate) vs ~10 MB soft ceiling |
| Standing gates | 3 MB per boundaries file; 1500 vertices/feature; 2 MiB votes (import-side `MAX_OUTPUT_BYTES` + validator `MAX_VOTES_FILE_BYTES`) |
| Shapefile package (already local under `tools/raw/collegi/`) | `CAMERA_CollegiPLURINOMINALI_2020` (**50 features**), `SENATO_CollegiPLURINOMINALI_2020` (**27**), `Circoscrizioni_Camera`, `Regioni_Senato`, `UT_Collegi2020` (last three: contents not yet inspected) |
| Senato cache (`tools/raw/senato_senatori_sparql.json`) | `osr:regioneElezione` present for **all 196 elective serving senators** (121 proporzionale + 73 uninominale + 2 estere); absent only for the 5 a-vita |
| Deputy coverage codes | 49 distinct `" - P0N"` plurinominale codes over **389**/400 deputies; the other 11 carry none — 8 estero + 3 structurally-bare (Valle d'Aosta + 2 suppletiva) — Phase 18 gate evidence, count corrected by Phase 25's probe (see [`docs/v4/25-plurinominale-geography.md`](../v4/25-plurinominale-geography.md) §2; the 2026-07-21 figure of 397 had silently folded the 8 estero deputies into the covered side) |
| Methodology gate | 1 of 6 lines passes (`docs/v3/votes-methodology.md`); blocked by sample shape (lines 1–4) and missing group-membership history (line 6) |
| Camera votes cadence | Same-day bursts (51/3/109/77/43 non-secret votes on recent sitting days); ~399 positions/event; ~148.6 B/position all-in (normalized schema) — Phase 21 probe |
| Known flake | Template `PoliticiUITests` failed twice in v3 on simulator-clone infrastructure (Phase 17/18 reports) |

## Open questions (owned by phases — never resolved by assumption)

- **Q1** — 50-vs-49 (Camera) / 27-vs-26 (Senato) plurinominale feature
  counts: placeholder-feature hypothesis (Valle d'Aosta / Trentino-Alto
  Adige) must be confirmed from feature attributes → **Phase 25** (gate
  condition). **RESOLVED** by Phase 25
  ([`docs/v4/25-plurinominale-geography.md`](../v4/25-plurinominale-geography.md)):
  confirmed — each layer's null-attribute row is a residual placeholder
  (POP_2011 matches the un-split territory), yielding 49 Camera / 26 Senato
  real plurinominale collegi.
- **Q2** — Contents of `UT_Collegi2020`, `Circoscrizioni_Camera`,
  `Regioni_Senato` layers → **Phase 23** inventory. **RESOLVED** by Phase 23
  ([`docs/v4/23-baseline-audit.md`](../v4/23-baseline-audit.md) §4):
  `UT_Collegi2020` is the comune-level (8,213 features / 7,904 comuni) base
  table every collegi layer aggregates from; `Circoscrizioni_Camera` = the
  28 Camera circoscrizioni; `Regioni_Senato` = the 20 administrative regions
  (short names, not ISTAT's bilingual forms).
- **Q3** — dati.camera.it behavior for aggregates / OFFSET / deep
  metadata windows → **Phase 27** probe (observe and document). **RESOLVED**
  by Phase 27 ([`docs/v4/27-votes-stratified.md`](../v4/27-votes-stratified.md)
  §3): `LIMIT/OFFSET` paging over a total `ORDER BY` is stable — zero URI
  overlap, monotonic dates, clean page boundary; each 2,000-row page well
  under any cap; no aggregate needed (so the Senato 403-on-aggregate trap was
  never hit).
- **Q4** — Shape of Camera group-membership interval data
  (`ocd:aderisce` + start/end; the v2 query's MINUS-on-ended-membership
  proves end dates exist) → **Phase 28** probe. **RESOLVED** by Phase 28
  ([`docs/v4/28-membership-history.md`](../v4/28-membership-history.md)):
  an `ocd:aderisce` carries `ocd:startDate` (the discovered start predicate,
  `YYYYMMDD`), an optional `ocd:endDate` (absent = the single open interval),
  and the group via `ocd:rif_gruppoParlamentare` (`dc:title`/`dcterms:alternative`);
  the node itself is a **blank node** (composed id minted at import). 468
  intervals for the 400 current deputies, half-open `[start, end)` (same-day
  handoff, evidenced), 100 % coverage of the shipped votes — methodology gate
  line 6 flips (`GO-STORICO` → GO).
- **Q5** — Exact ISTAT comuni product, acquisition path, license page →
  **Phase 30**. **RESOLVED** by Phase 30
  ([`docs/v4/30-comuni-geocoding.md`](../v4/30-comuni-geocoding.md)): the
  product is the **`UT_Collegi2020` layer of the ISTAT collegi package already
  local under `tools/raw/collegi/`** (the comune-level base table the collegi
  layers aggregate from — 7,904 comuni), so the acquisition path is **"none
  required"** and the licence is the **CC BY 4.0 already verified and recorded**
  for that same D.Lgs. 177/2020 release in `tools/SOURCES.md` /
  `docs/DATA_SOURCES.md`. Decided under the user-gated acquisition rule with
  approval quoted verbatim; no download and no network act occurred, and the
  shared `istat` fetch-metadata key (2026-07-18) was not advanced. Comuni
  vintage is identical *by construction* to the shipped collegi bases, which is
  what a separately-acquired current-vintage product could not have offered.
- **Q6** — V3 commissioning brief archival (standing since Phase 13) →
  **CLOSED as never produced by the user's decision in Phase 32B
  (2026-07-29)** — quoted verbatim in
  [`docs/v4/32a-release.md`](../v4/32a-release.md)'s "Decisions received"
  addendum: *"It does not exist and never did. Close it — do not carry it
  into V5."* Not carried into V5. The record of why no phase could close it
  stands below, unchanged, because it is what made the user's decision the
  only possible close. Re-searched a third time in Phase 32A
  ([`docs/v4/32a-release.md`](../v4/32a-release.md) §6) with the same result
  as Phases 13 and 23: the only commissioning brief in the tree is the
  historical documentation pack's own
  (`docs/history/HISTORY_PACK_COMMISSIONING_BRIEF.md`), whose header says it
  is not a V3/V4 architecture task. **The reason it cannot be closed by any
  phase is that the document has never been provided**, and nothing may be
  fabricated in its place (constraint #4) — so no assistant-side action can
  resolve it. It was carried into the V4 release actions as a pending user
  decision and answered there. Should the brief ever surface, it is archived
  verbatim under `docs/history/`, labelled user-provided — but nothing is
  waiting on it.
- **Q7** — Metric tie-breaking and minimum-denominator threshold need
  explicit user sign-off → **Phase 29**. **RESOLVED** by Phase 29
  ([`docs/v4/29-alignment-metric.md`](../v4/29-alignment-metric.md)): with
  explicit user sign-off (2026-07-23) a **group-majority tie excludes that vote
  from the member's denominator**, the **minimum denominator is 10** (below it
  the metric renders nothing — an honest absence, never 0%), and the value is
  shown as an integer percentage **with its denominator visible**, profile-only,
  never listed/ranked/colored. Gruppo Misto is one group per Phase 28's mapping.

## Plan-wide rules

1. Everything in the root `CLAUDE.md` — standing constraints, domain
   conventions, generated-data protocol, refetch protocol, probes
   convention, chamber-conditional keys, frozen-history rule — applies
   verbatim to every phase.
2. Every gate decision is committed with per-condition quoted evidence,
   **in both outcomes**. NO-GO / NOT-RUN / early-exit are first-class,
   plannable results, never failures to spin.
3. Every network act is user-gated: stop, ask, quote the approval
   verbatim in the phase report. Minimal-scope fetches preferred.
4. Probes are committed under `tools/probes/`; their `output/` is
   gitignored and never an import source. Probe before implementing;
   verify test expectations independently before hardcoding them.
5. Test-expectation changes are always deliberate, listed per-test in
   the report. "Zero regressions" means the current dual-definition
   baseline plus the sum of documented deliberate additions — re-derived
   after Phase 24 changes the definition.
6. Every phase ends with a self-contained report in `docs/v4/`, the
   pinned commit message, and a status flip in `docs/plan/README.md`
   (same commit). Never push, tag, or touch GitHub — the user executes
   all remote actions personally; print commands instead.
7. Where any phase file conflicts with `CLAUDE.md`'s constraints,
   `CLAUDE.md` wins; where it conflicts with observed reality, reality
   wins and the deviation is documented in the report.
8. **Side tasks** — work done outside a numbered phase (spawned or
   background sessions, interstitial cleanup/fixes). *Output side:* must
   end committed with a clean working tree, must never push or tag, and —
   where it touches `tools/` or `Politici/Data/` — must be recorded under
   `docs/v4/` and referenced from the next phase's report. **And it must
   clean up after itself:** when a spawned or background session that ran
   in its own worktree finishes, run `git worktree list` and remove that
   worktree *and* its branch. This is the same reflex as checking
   `git status` before a commit, not a separate chore — a worktree nobody
   removes is invisible from the working checkout, so nothing surfaces it
   later. Three accumulated under `.claude/worktrees/` during the v4 cycle,
   none removed by the session that created it, and the first went
   undetected for several phases; the residue still on record is the
   orphaned branch `claude/strange-payne-57880c`. *Input side:*
   **before a spawned or background session's output is trusted or
   applied, verify the commit it was based on against `v4`'s tip.** A
   session forked from a stale base runs under whatever `CLAUDE.md`, plan
   files, and generated data existed at that commit — so it can silently
   duplicate, contradict, or regress work already on the branch. When the
   base is stale, re-apply the result by hand on the current tip rather
   than committing its diff. First instance:
   [`docs/v4/25a-doc-sync.md`](../v4/25a-doc-sync.md) — a spawned doc-fix
   session had been forked from the pre-v4 `3dc224e` (under a v3-era
   `CLAUDE.md` that had never seen the plan files) and had re-derived a
   fix Phase 25 already carried; its note edits were re-applied on
   `15f3f95`, its diff discarded.
9. **Data-visibility staleness is in-scope by default.** Any phase that
   changes *where a datum is visible* — a new field, a new
   section/page/list, a new linkage that surfaces records somewhere they
   weren't — must, **as part of that phase, not as a deviation**, check the
   explanatory copy that describes the old visibility for staleness and fix
   what it made inaccurate: the `HomeView` "Come funziona" explainer,
   `README.md` prose, and `docs/DATA_SOURCES.md` (where provenance/coverage
   is described). This is declared scope, so it needs no separate
   justification; only a *decision not to touch* one of them (because it was
   already accurate) is worth a line in the report. Pattern recognized after
   three consecutive phases (24 narrowed a criterion; 25 synced attribution;
   26 updated the Senato explainer) each flagged the same shape as a
   "deviation" — it is not one.
10. **A user approval binds to the outcome it was given on.** After the user
   approves something on quoted evidence, a later change that **strictly
   improves** the approved outcome — every stated measure equal or better, and
   the basis of the decision unchanged — **may ship, disclosed in the report**:
   the report must publish both the approved figures and the shipped ones,
   state that the approval predates the change, and say why the change is an
   improvement. Anything that **worsens any measure, or shifts the basis of the
   decision** (a different source, a different licence, a different scope, a
   new trade-off the user was not shown) **goes back for re-approval before
   shipping** — never disclosed after the fact as a *fait accompli*. First
   applied in Phase 30, where approval of the comuni **source** was given on a
   whole-comune-union centroid pass (99.92 % resolution) and the shipped
   largest-part method improved every measure (99.94 %, both-chamber nil
   2 → 1) without touching the source choice the approval was actually about —
   see [`docs/v4/30-comuni-geocoding.md`](../v4/30-comuni-geocoding.md) §1.

## Explicitly deferred from V4 (decisions, not omissions)

| Item | Rationale |
|---|---|
| Senato votes | Unexplored source surface; a V5 exploration candidate with its own GO/NO-GO — bolting it onto Phase 27 would double that phase's risk |
| Representative photos | Local-first runtime + image rights; a size/rights project of its own |
| Push notifications / any backend | Nothing to push from |
| SwiftData migration | Versioned `UserDefaults` favorites suffice; no new state needs more |
| `attendanceRate` | Permanent absence (no source methodology; "no participation metric ever" standing rule); field kept for frozen-fixture compatibility |
| Map-polygon VoiceOver discoverability | Platform limitation; `CollegiListView` (+ Phase 25's type filter) remains the accessible path |
| ~~Fixing the 62 `performAccessibilityAudit` findings~~ | **DISCHARGED by Phase 32A** — and the 62 was an undercount. Phase 24's audits were viewport-limited, so its inventory covered only each screen's first viewport; Phase 32A rebuilt the audits to page through whole screens and measured **200** findings over 16 screen states in its certifying run ([`docs/v4/32a-release.md`](../v4/32a-release.md) §2, triage in [`docs/v4/a11y-checklist.md`](../v4/a11y-checklist.md)) — a run-dependent lower bound, which is why the triage is by cause. Every finding is triaged there. What remains deferred is narrower and is the row below |
| Measured on-device contrast / Dynamic Type judgment for the residual audit findings | The residue after Phase 32A's triage. The auditor evaluates translucent `.regularMaterial` against an **opaque approximation**, and the rebuilt inventory contains findings on `.primary` text (`"Angelo Rossi"`, `"Liliana Segre"`) — a foreground Apple guarantees against system backgrounds — which is direct evidence that the background model, not the foreground choice, is the variable. Deciding these needs a real measurement on a device in both appearances, which no headless session can produce; `.dynamicType`/`.textClipped` are the same visual judgment at the largest accessibility sizes. Owner: a device-side pass, which is also `docs/v2/a11y-checklist.md`'s and `docs/v3/a11y-checklist.md`'s standing pending item |
| ~~Re-run the container-identifier shadowing survey when 32A touches these screens~~ | **DISCHARGED by Phase 32A.** The survey was re-run (52 sites) and the two non-`.combine` container sites it had flagged — `MapView`'s `ChamberPicker` / `CollegioTypePicker` — were **fixed rather than re-recorded**: a segmented `Picker` is not one accessibility element, so `chamber.picker` / `collegioType.picker` were propagating onto both segments and making neither addressable. Each segment now carries its own identifier and the container identifiers are gone; `PoliticiUITestCase.selectChamber`/`selectCollegioType` address them, which also gave Phase 25's collegio-type filter its first UI-test coverage. See [`docs/v4/32a-release.md`](../v4/32a-release.md) §3 |
| A production `CLGeocoder` timeout | **Decided in Phase 32A: not shipped**, with reasons rather than by omission ([`docs/v4/32a-release.md`](../v4/32a-release.md) §5). (a) The only measurement on record — ~1 s to >120 s — comes from a **simulator with no route out**; no device-side measurement exists, and changing production behaviour to fix an unmeasured production problem is the wrong direction. (b) A timeout would silently substitute a comune-centroid answer for an address-level one, and the screen's provenance caption cannot currently tell the two apart — the exact silent-substitution family Phases 28/29/30B/31 each refused. Re-open **together with** the disclosure copy that makes the degraded answer visible, or on an actual device-side measurement of a hang. Test-side the question is already closed (Phase 30B's `-stubAddressResolver` seam) |
| A per-representative data-vintage line | Declined in Phase 31 §6.2 and **re-affirmed in Phase 32A**: nothing changed the reasoning, and the profile screen has since gained Phase 29's long metric caption, so the clutter cost went up rather than down. It stays pinned to ADR trigger 2 — distribution to people who cannot run `make refresh` — which a local prototype tag does not trip |
| UI flow 6's vote-specific anchors | `SmokeFlowUITests` pins one deputy, one vote event and one title substring (`p300480` / `vote.row.vd19_577_001_300480` / `"2423"`) because the flow proves outcome-chip and title-search *composition*, which needs a vote with a known position. Phase 27's selection is deterministic for fixed input but **not stable across refetches**, so any `votes.json` change is expected to fail these three loudly. That is the designed behaviour: the failure means **re-pin**, not regression. Recorded here so a future session does not read it as a defect |
| Phase 27's stratified selection is not stable across refetches | `tools/select_votes_scope.py` is deterministic for a fixed input set, but a refetch changes the input, so the chosen 30 votes can legitimately differ ([`docs/v4/27-votes-stratified.md`](../v4/27-votes-stratified.md) §4). Making it stable would mean pinning event URIs in `votes_scope.json`'s `explicit` mode by hand and losing the coverage-driven property that flipped the methodology gate. Not a defect; a documented property |
| Address-level resolution has no offline path | Tier 1 (`CLGeocoder`) is the only tier that can resolve a street address, and it needs the network — which the **app** may not use (constraint #3), so this is a limit of the local-first design itself, not a gap to close. Offline, the honest floor is comune-level: the bundled 7,904-comune table answers a comune name from the published assignment and a comune coordinate by point-in-polygon. Recorded so no future phase treats "offline street addresses" as achievable within the standing constraints |
| ~~Phase 30 §10's `*.sample.*` byte figure~~ | **Not deferred — corrected, and the correction is on record.** Phase 30 §10 states the three fixtures "add a further 13,179 B"; the true sum is **14,765 B** (3,773 + 6,423 + 4,569), and all three are byte-identical to their content at Phase 30's commit `0e76a75` — so it was a mis-sum, not a changed file. The correction lives in [`docs/v4/30b-comuni-assignment.md`](../v4/30b-comuni-assignment.md) §8 and is restated in Phase 31 §1.1 and Phase 32A. `docs/v4/30-comuni-geocoding.md` is deliberately **not** edited: completed phase reports record what was true when written (the frozen-history rule), and corrections land in living documents |
| `import_comuni.py` guard on cross-row name/province disagreement | Tooling-hardening backlog, not a shipping decision: the importer groups `UT_Collegi2020` rows on `PRO_COM` and takes a sorted **union** for the collegio codes (so a disagreement ships in full — by design), but resolves `DEN_COM`/`DEN_P_CM` **last-row-wins**. Measured unambiguous today — 0 of 7,904 comuni have rows disagreeing on either field ([`docs/v4/30b-comuni-assignment.md`](../v4/30b-comuni-assignment.md) §2(a)) — so nothing is wrong; the script simply does not *check* it, unlike the union path. Also worth committing there: the same report's row-reconciliation measurements, which were run read-only rather than added to `probe_comuni_assignment.py`'s condition-(a) section. Pick up in a tooling-touching phase; do not implement as a side effect of unrelated work |
| `make_manifest.py` fail-loud on an absent `.fetch_metadata.json` | Tooling-hardening backlog, not a shipping decision: the cache is gitignored, so a fresh-checkout/worktree `make manifest` silently rewrites every `retrievedAt` to today (see the `make manifest` caveat in `CLAUDE.md`). The script should refuse rather than fall back to `date.today()`. Pick up in a tooling-touching phase; do not implement as a side effect of unrelated work |
| Official bilingual (Italian/German) comune names for Alto Adige | The ISTAT `UT_Collegi2020` source carries **Italian-only** comune names — **zero** of its 7,904 `DEN_COM` values contain a `/`, so `Bolzano` is present and `Bolzano/Bozen` is not (measured; see [`docs/v4/30-comuni-geocoding.md`](../v4/30-comuni-geocoding.md) §3). Inventing the German exonyms to satisfy the Phase 30 spec's "match either side of the `/`" wording would fabricate geographic data (constraint #4), so Phase 30 handled it on the *query* side instead (a `"X/Y"` query matches via its Italian side; a German-only query honestly returns nothing). Revisit **only if and when a source that actually publishes the official bilingual forms is identified** — then it is a data-join task with its own provenance entry, not a string transformation |
| **A reachability sweep of `PoliticiUITests`** (V5) | Recorded by Phase 32B, **deliberately not fixed there**: these are UI-test changes immediately before a tag, and the tag must point at the tree the certifying run validated. `CLAUDE.md`'s v4 conventions now carry the rule — assert hittability after scrolling wherever the claim is that a user can see or use something; `.exists` proves only tree membership. The sites Phase 32A enumerated, all verified against the source at 32B time: **(1)** `SmokeFlowUITests` flow 7, `PoliticiUITests/SmokeFlowUITests.swift:273–274` — `el("addressSearch.result.camera").exists` / `…senato").exists`, **the exact shape of the bug that was live**: these passed for the whole of Phase 30B while Roma's Senato rows were off-screen and unreachable. **(2)** The Home CTAs, `SmokeFlowUITests.swift:85–86` (`home.cta.map`, `home.cta.votazioni`). **(3)** The **horizontally**-scrolled sample-city chips, `SmokeFlowUITests.swift:257` (`addressSearch.city.Roma`) — horizontal paging is not what `scrollUntilHittable` does today. **(4)** The per-row `Fonte ufficiale` link, `SmokeFlowUITests.swift:213–216` — `waitForExistence` plus a label equality on `vote.event.source.*`, deliberately never tapped (it would leave the app for Safari), so reachability is the only thing left to prove and it is not proven. **(5)** `PoliticiUITestCase.tapButton(_:_:)`, `PoliticiUITestCase.swift:197–203`: it waits **up to 5 s** for hittability and then calls `element.tap()` **regardless** — so a never-hittable button yields a dropped tap and a downstream failure, not a diagnosis at the real site. Also to fix in the same sweep: the three caveats on Phase 32A's own `AddressSearchView` guard (`AccessibilityAuditUITests.swift:385–386`) — it asserts **one** row on the *inference* that `S120004` is bottom-most rather than asserting all ten are reachable; it lives in the **audit** test rather than in flow 7, which is where the reachability claim belongs; and it **pins a collegio id**, so an ISTAT re-issue fails it for the wrong reason |
| **`Vote`'s `Decodable` conformance shipped main-actor-isolated in `v4.0-prototype`** (defect record, not a deferral) | **The defect is in the tag.** At `v4.0-prototype`, `Politici/Models/Vote.swift:71` declares `nonisolated struct Vote`, but its conformance lives in a separate `extension Vote: Codable` at `:87` **without** `nonisolated` — and a conformance-bearing extension picks up the file default independently of the type. With `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES` (which implies `InferIsolatedConformances`), that made `Vote`'s `Decodable` conformance `@MainActor` — **while `VoteService` decodes it off the main actor by design**: Phase 27's lazy-loading path runs `Self.decode(resource:bundle:)` inside a `Task.detached(priority: .userInitiated)`, and `loadIfNeeded()`'s own doc comment states the decode runs off the main actor with only the result applied on it. So the shipped tag pairs an off-main decode with a main-actor-isolated conformance. **Latent, not active:** `Vote` is a `Sendable` value type decoded from bundled JSON with no shared mutable state, no race was ever observed, and every suite run on the tag was green — under the Swift 5 language mode this is a warning, and it is a hard error only under Swift 6. It was invisible for a further reason worth carrying forward: **these warnings do not appear on incremental builds**, only on a full recompile of the test target, which is why 56 of them across 14 test files sat unseen through the whole v4 cycle. **Fixed on `chore/post-v4-tidy`** in `61d8b90` — `Models/` is uniformly `nonisolated`, conformance-bearing extensions are `nonisolated extension`, and the five test classes whose services hold real main-actor state carry `@MainActor` instead. `CLAUDE.md`'s v4 durable conventions already carry the rule and both traps; **this row is the record that the defect shipped**, so a V5 session reading the convention knows it was written against a real escape and not in the abstract |
| **`Representative.sourceUrl` ships for all 601 records and is rendered nowhere** (V5) | The data to offer **per-record** verification against `dati.camera.it` / `dati.senato.it` already exists in the bundle: every one of the 601 records carries a real, source-supplied `sourceUrl` (`http://dati.camera.it/ocd/persona.rdf/p300480`, `http://dati.senato.it/senatore/32435`) — decoded by `Representative`, shape-validated by `tools/validate_data.py` (`sourceUrl` must be null or an `http(s)` URL — it is non-null on all 601), and then referenced by **no view and no test**. Recorded here because the post-v4 tidy removed the profile's `Fonte ufficiale` field and that could be misread as having removed a verification path: it did not. That field was the **provenance badge** — a static `Label(provenance.displayName)` with a `checkmark.seal.fill`, no URL — and it read identically on all 601 profiles, since every shipping record is `provenance: "official"`. **There had never been a per-record verification path in the app**, before or after. What exists today is dataset-level ("Informazioni e fonti", from `Data/sources.json`) and per-vote (the `Fonte ufficiale` links on vote rows, which are real `Link`s and stay). Surfacing `sourceUrl` on the profile is a one-line view change with two open questions that make it a decision rather than a chore, and neither is answered here: the URLs are **RDF/data-service endpoints**, not the human-readable pages a user would expect from a "Fonte ufficiale" link — and constraint #4 forbids constructing the human page's URL from them, since this dataset does not publish it. That is the precise difference from the vote-row links, which are safe to surface because a vote's `sourceUrl` is the graph's own `dc:relation` deep link to the official "scheda votazione" **page**, carried verbatim and never constructed, and tapping any external link leaves the app for Safari. Pick up deliberately, with the link copy that tells the user where it actually goes |
| **The suite's cost is concentrated in the UI audits, and it is the dominant tax on routine work** (V5) | Measured while landing a **one-line** test in the post-v4-tidy profile work, which took **five full-suite runs and 75.9 min of machine time** (53.4 min of runs — 9.8/10.6/10.5/10.5/12.1 — plus 22.5 min of deliberate load-gate waiting). **Only two of the five were needed on the merits**; three were lost entirely to simulator-clone contention, not to anything wrong with the change — the diff against the last green tree showed zero changed executable lines under `Politici/`. The distribution, from the certifying run's `.xcresult`: `PoliticiTests` is **228 cases summing 17.3 s**, `PoliticiUITests` is **15 cases summing 814.0 s**, and within it `AccessibilityAuditUITests` alone is **7 cases summing 597.0 s** — so **94 % of declared cases account for ~2 % of case time, and 7 cases account for ~72 %**. The audits are expensive by construction: each relaunches the app, navigates a full path, and pages whole screens (`audit(_:viewports:)`), and `performAccessibilityAudit()` carries an internal deadline, so under load they are also the **first** thing to fail — the heaviest, `testAccessibilityAuditAddressSearchAndFontiEDati` (129 s) and `…VotazioniAndVoteHistory` (112 s), have the least headroom. **Options, stated rather than chosen** — this is a decision for a V5 session, not a change to make in passing: **(a)** split the UI audits out of the default suite so routine changes validate in seconds rather than minutes (the 17.3 s figure is what is on offer), at the cost of a change being able to land without audit coverage unless something re-joins them; **(b)** cap concurrent simulator destinations (`-maximum-parallel-testing-workers`, or `-parallel-testing-enabled NO`), which removes the contention that causes the flake but lengthens every run and weakens the evidence a green provides, since `CLAUDE.md` already records that a serial green is weaker than a parallel one; **(c)** run the audits on a schedule (nightly, or per-phase-closeout) rather than per suite, which keeps routine runs cheap but moves audit findings off the commit that caused them. **Any split must preserve the declared-equals-runtime invariant**, which today assumes a *single* total: `CLAUDE.md`'s baseline convention reads the count from one `.xcresult`'s `totalTestCount` and re-derives "declared" by counting `func test…(` occurrences (+ `@Test`) across `PoliticiTests/` **and** `PoliticiUITests/` together — 242 + 1 = 243 at the time of writing. Two schemes means two `.xcresult`s and two totals, so the invariant has to be restated as a sum across targets with the from-source count attributed per target, and the collision-safe occurrence rule still applies within each. Restate it in the same commit as any split; a split that leaves the invariant reading "one total" silently stops detecting a dropped test |
| ~~**Open user decision** — comune-name lookup: source assignment vs geometric resolution~~ | **RESOLVED — no longer deferred.** Raised by the Phase 30 review ([`docs/v4/30-comuni-geocoding.md`](../v4/30-comuni-geocoding.md) §11) and decided by the user commissioning **Phase 30B**, which shipped it: comune-**name** queries now cite the publisher's `CU20_COD`/`SU20_COD`, geometry is retained for the **coordinate** path alone, and the 6 multi-collegio comuni (Roma, Milano, Napoli, Torino, Palermo, Genova — 6,937,409 residents = 11.67 % by ISTAT's census-2011 `POP_2011` field) are shown with **every** assigned collegio, never one. The predicted 7 Camera / 4 Senato answer changes were reconfirmed exactly, plus the 6/3 multi-collegio comuni whose single answer became a set — see [`docs/v4/30b-comuni-assignment.md`](../v4/30b-comuni-assignment.md) §2(e). Phase 32A no longer needs to surface it |
