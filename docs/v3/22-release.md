# V3 Phase 22A — Documentation, Accessibility Checklist, Release Prep

Docs-only phase (one comment-string correction in
`CollegiListView.swift` aside — a stale "Collegi campione" reference,
exactly the stale-line class this phase exists to clear). No tag was
created and nothing was pushed; Phase 22B owns both, gated on the
pending decisions at the end of this report.

## 1. Report-set verification

`docs/v3/` contains all eleven phase reports — 13, **13B**, 14, 15,
**15b**, 16, 17, 18, 19, 20, 21 — plus `votes-methodology.md` and (new
this phase) `a11y-checklist.md`. No gaps; 22B is unblocked.

Per-phase commit hashes, recovered from `git log --oneline` (quoted
below verbatim; every phase is exactly one commit, no interstitial
fixes anywhere on `v3`):

```
9c7a436 docs(v3): phase 21 — votes scope probe: measured early exit (no data change)
89e0b16 feat(v3): phase 20 — vote browsing (source-backed event identity) + voting-methodology gate
873fc5f feat(v3): phase 19 — Preferiti (local favorites)
0d75506 feat(v3): phase 18 — plurinominale/estero representation context (gated)
c491548 feat(v3): phase 17 — senator mandates (MandateType) + Senato collegio linkage (GO-LINK)
3828ebd docs(v3): phase 15b — Senato linkage predicate probe (GO/NO-GO re-evaluation)
5f6650a feat(v3): phase 16 — Senato uninominale boundaries + chamber-aware map
a1cac30 docs(v3): phase 15 — Senato source exploration (read-only findings, GO/NO-GO)
b371465 chore(v3): phase 14 — pipeline hardening (offline `all`, `refresh`, validate-last, vertex report, probes)
492152f chore(v3): phase 13b — deployment target change (user-approved)
1d2eba5 chore(v3): phase 13 — baseline audit and hygiene closeout (v3 branch from audited main)
```

(Note the 15b docs commit lands *after* 16 in history — the probe was a
user-gated insert run between them; the CHANGELOG lists phases in
logical order with these exact hashes.)

## 2. What this phase changed

- **`docs/v3/a11y-checklist.md`** (new): every seeded V3 surface checked
  by code inspection with per-surface results, plus the honest
  pending-human-checks list; `docs/v2/a11y-checklist.md` referenced,
  untouched. Re-verified baselines: still zero custom animations; the
  MapKit-polygons-vs-VoiceOver limitation stands with `CollegiListView`
  as the alternative.
- **`README.md`** full refresh: dual-chamber map (221 collegi), Senato
  linkage 73/74, mandates, plurinominale context, Preferiti, Votazioni,
  normalized votes schema, `boundaries-senato`, probes dir, both a11y
  checklists; known limitations updated (single-sitting votes sample +
  the Phase 21 measured exit; the no-metric rule; UITests flakiness
  note); the old "v3 roadmap" rewritten as "Roadmap (post-v3)" with
  shipped / measurably-exited / open items stated plainly.
- **`CLAUDE.md`**: new "Domain conventions established in v3" section
  (chamber-conditional keys, `regione` vs `circoscrizione`, S-prefix
  ids, MandateType semantics, linkage alias policy, probes + endpoint
  findings, favorites store, no-metric rule, frozen-history rule) plus
  the generated-data and refetch protocols promoted into the Data Files
  section; layout tree updated (probes/, docs/v3, docs/history).
- **`docs/DATA_SOURCES.md`**: full 6-entry cross-check vs
  `Data/sources.json` and `tools/SOURCES.md` — **no mismatches, nothing
  to fix** (Phase 17's re-sync held; Phase 21 moved no dates).
- **`CHANGELOG.md`**: `v3.0-prototype (2026-07-21)` entry, per-phase
  with the hashes above, honest one-liners for the non-shipping outcomes
  (15's NO-GO(LINK), 21's early exit), and the "Release actions" pending-
  decisions subsection mirroring the block at the end of this report.
- **`docs/releases/v3.0-prototype.md`** (new; the `docs/releases/`
  directory itself is new): follows the backfilled v2 note's structure —
  the CHANGELOG entry reproduced verbatim with CHANGELOG canonical, plus
  an explicit note that the tag does not exist yet at commit time.
- **Stale-line sweep**: grep over living docs and app code for the
  NO-GO-era phrase classes ("Collegi campione", "nessun senatore",
  "not rendered at all", "never mapped") — one hit found and fixed (the
  `CollegiListView` doc comment); zero remain outside the frozen
  `docs/v2`/`docs/v3` phase reports and `docs/history`, which record
  history and are correct as records.
- **Frozen-history check**: `git diff docs/v2 docs/history` — zero diff.

## 3. Open questions status

- **V3 commissioning brief (Open Q2, Phase 13)**: still not provided;
  archival remains pending, listed in the CHANGELOG release actions.
- **`origin/v3` note (Phase 17 report)**: the branch tracks `origin/v3`
  (pushed at some point after Phase 13's audit snapshot); 22B's printed
  push commands should be re-derived from actual state at 22B time
  (`git push origin v3` rather than the `-u` first-push form, plus
  whatever unpushed commits exist then).

## 4. Final verification (this phase, after all doc changes)

- Build: **BUILD SUCCEEDED** (generic/platform=iOS Simulator).
- Tests: iPhone 17 Pro simulator, **exit 0, 0 failures, 139 runtime
  cases passed**. One log line was truncated mid-name by xcodebuild
  output interleaving (`testEveryCaseHasANonEmptySymbol2026-07-21…`,
  log line 472) — the third occurrence of this cosmetic artifact in v3,
  verified as such (suite completed, zero failure lines, exit 0).
- **Dual-definition counts and regression arithmetic**:
  - Declared: **136** = 132 `func test` in `PoliticiTests` + 1 Swift
    Testing `@Test example()` + 3 in `PoliticiUITests`.
  - Runtime: **139** = 136 + 3 (the `testLaunch()` ×4
    UI-configuration cause, unchanged since Phase 13 named it).
  - Arithmetic vs baseline: 94 declared / 97 runtime [Phase 13]
    + 15 [16] + 6 [17] + 6 [18] + 7 [19] + 8 [20] + 0 [21] + 0 [22A]
    = **136 / 139. Exact match — zero regressions.**
- `git tag` lists only `v2.0-prototype` (and any pre-existing tags) — no
  new tag; nothing pushed by this phase.

## 5. PENDING USER DECISIONS (mirrored in CHANGELOG "Release actions")

Phase 22B runs only after these are answered, quotes the answers, commits
the decisions record FIRST, and only then tags:

- **(a) Tag `v3.0-prototype`** — approve creating the local annotated tag
  at the 22B decisions commit? (22B will also print — not execute — the
  push commands for branch and tag.)
- **(b) Repository visibility / GitHub Release** — should a GitHub
  Release be drafted once pushed, and is the repository staying
  private/going public? (URL placeholder reserved in CHANGELOG.)
- **(c) Retrospective `v1.0.0` tag** — created only under a separate
  explicit instruction; deliberately not proposed as a default and not
  re-asked by 22B.
- *(standing)* the V3 commissioning brief, if it surfaces, gets archived
  under `docs/history/`.
