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
  **Phase 30**.
- **Q6** — V3 commissioning brief archival (standing since Phase 13) →
  closed whenever the document surfaces; restated in 32A.
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
   `docs/v4/` and referenced from the next phase's report. *Input side:*
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

## Explicitly deferred from V4 (decisions, not omissions)

| Item | Rationale |
|---|---|
| Senato votes | Unexplored source surface; a V5 exploration candidate with its own GO/NO-GO — bolting it onto Phase 27 would double that phase's risk |
| Representative photos | Local-first runtime + image rights; a size/rights project of its own |
| Push notifications / any backend | Nothing to push from |
| SwiftData migration | Versioned `UserDefaults` favorites suffice; no new state needs more |
| `attendanceRate` | Permanent absence (no source methodology; "no participation metric ever" standing rule); field kept for frozen-fixture compatibility |
| Map-polygon VoiceOver discoverability | Platform limitation; `CollegiListView` (+ Phase 25's type filter) remains the accessible path |
| Fixing the 62 `performAccessibilityAudit` findings (`.contrast` / `.dynamicType` / `.textClipped`) | Deferred *within* V4, not out of it: Phase 24 recorded rather than fixed them (see [`docs/v4/24-ui-tests.md`](../v4/24-ui-tests.md) §5) and handed them to **Phase 32A**, which triages each to a fix or a documented human-judgment deferral |
| `make_manifest.py` fail-loud on an absent `.fetch_metadata.json` | Tooling-hardening backlog, not a shipping decision: the cache is gitignored, so a fresh-checkout/worktree `make manifest` silently rewrites every `retrievedAt` to today (see the `make manifest` caveat in `CLAUDE.md`). The script should refuse rather than fall back to `date.today()`. Pick up in a tooling-touching phase; do not implement as a side effect of unrelated work |
