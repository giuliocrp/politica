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
| Deputy coverage codes | 49 distinct `" - P0N"` plurinominale codes over 397/400 deputies; 3 structurally-bare records (Valle d'Aosta + 2 suppletiva) — Phase 18 gate evidence |
| Methodology gate | 1 of 6 lines passes (`docs/v3/votes-methodology.md`); blocked by sample shape (lines 1–4) and missing group-membership history (line 6) |
| Camera votes cadence | Same-day bursts (51/3/109/77/43 non-secret votes on recent sitting days); ~399 positions/event; ~148.6 B/position all-in (normalized schema) — Phase 21 probe |
| Known flake | Template `PoliticiUITests` failed twice in v3 on simulator-clone infrastructure (Phase 17/18 reports) |

## Open questions (owned by phases — never resolved by assumption)

- **Q1** — 50-vs-49 (Camera) / 27-vs-26 (Senato) plurinominale feature
  counts: placeholder-feature hypothesis (Valle d'Aosta / Trentino-Alto
  Adige) must be confirmed from feature attributes → **Phase 25** (gate
  condition).
- **Q2** — Contents of `UT_Collegi2020`, `Circoscrizioni_Camera`,
  `Regioni_Senato` layers → **Phase 23** inventory.
- **Q3** — dati.camera.it behavior for aggregates / OFFSET / deep
  metadata windows → **Phase 27** probe (observe and document).
- **Q4** — Shape of Camera group-membership interval data
  (`ocd:aderisce` + start/end; the v2 query's MINUS-on-ended-membership
  proves end dates exist) → **Phase 28** probe.
- **Q5** — Exact ISTAT comuni product, acquisition path, license page →
  **Phase 30**.
- **Q6** — V3 commissioning brief archival (standing since Phase 13) →
  closed whenever the document surfaces; restated in 32A.
- **Q7** — Metric tie-breaking and minimum-denominator threshold need
  explicit user sign-off → **Phase 29**.

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

## Explicitly deferred from V4 (decisions, not omissions)

| Item | Rationale |
|---|---|
| Senato votes | Unexplored source surface; a V5 exploration candidate with its own GO/NO-GO — bolting it onto Phase 27 would double that phase's risk |
| Representative photos | Local-first runtime + image rights; a size/rights project of its own |
| Push notifications / any backend | Nothing to push from |
| SwiftData migration | Versioned `UserDefaults` favorites suffice; no new state needs more |
| `attendanceRate` | Permanent absence (no source methodology; "no participation metric ever" standing rule); field kept for frozen-fixture compatibility |
| Map-polygon VoiceOver discoverability | Platform limitation; `CollegiListView` (+ Phase 25's type filter) remains the accessible path |
