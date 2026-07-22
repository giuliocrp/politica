# Voting-Data Methodology — the gate any future metric must pass

Written in V3 Phase 20 (see `docs/v3/20-vote-browsing.md`). This document
is the standing contract: **no vote-derived metric of any kind ships in
this app until every line of the gate below passes**, and the standing
rules below bind any metric that ever does ship. Phase 20 itself ships
*browsing only* — events, tallies, filters — deliberately no metric.

## The gate

A proposed metric (e.g. within-group voting alignment) may only be
computed over a sample that satisfies **all six** lines. Status is
re-measured against the current shipping `votes.json` as of **v4 Phase 27**
(30 events, 11,899 positions, imported 2026-07-22 — the stratified
expansion; see [`docs/v4/27-votes-stratified.md`](../v4/27-votes-stratified.md)):

| # | Requirement | Current sample (Phase 27) | Status | (Phase 20) |
|---|---|---|---|---|
| 1 | ≥ 30 events | **30 events**, 11,899 positions | ✓ | ✗ (12) |
| 2 | ≥ 3 distinct sittings (sedute) | **10 sittings** (552, 577, 581, 599, 614, 634, 648, 664, 680, 694) | ✓ | ✗ (1) |
| 3 | ≥ 6 months of date span | **272 days ≈ 8.9 months** (2025-10-22 … 2026-07-21) | ✓ | ✗ (1 day) |
| 4 | ≥ 2 distinct atti among atto-bearing events | **15 atto-bearing events, 9 distinct atti** | ✓ | ✗ (0) |
| 5 | `astenuto` its own category, never folded into favorevole/contrario/assente | Holds structurally: `VoteChoice.astenuto` is a distinct case end-to-end (source `"Astensione"` → `.astenuto`, own badge, own filter chip, own tally). Distribution now: Assente 4,571 / Favorevole 4,326 / Contrario 2,541 / **Astenuto 461** | ✓ | ✓ |
| 6 | Group-membership-at-vote-date available | **Still not available** — `representatives.json` carries only the *current* parliamentary group; the pipeline imports no historical membership intervals. This structurally blocks every group-relative metric regardless of sample size (Phase 28's target) | ✗ | ✗ |

**Conclusion (as of Phase 27): 5 of 6 lines pass (was 1 of 6).** Phase 27's
stratified expansion flipped the four sample-shape lines (1–4); **line 6 is
unmet as of Phase 27 and is exactly Phase 28's deliverable** (a
group-membership-at-vote-date import; see Phase 28 / Q4). Because the gate
requires **all six**, no vote-derived metric may ship *now*.

**Phase 29's runnability is not decided here.** It is determined by Phase
28's outcome, not by Phase 27's: if Phase 28 lands the historical-membership
import, line 6 plausibly flips and the gate reaches 6/6, at which point
Phase 29 becomes live. Per the re-evaluation protocol below, **Phase 29's
session must re-measure this table from the then-current `votes.json` and
`representatives.json`** and decide GO/NOT-RUN on that fresh measurement —
never inherit a verdict recorded here.

Rationale, now that lines 1–4 pass: the sample spans 10 sittings across
~9 months with 15 substantive atto-bearing votes on 9 distinct atti, so it
is no longer "a single afternoon's party discipline." But a *group*-relative
metric still cannot be computed honestly without knowing each deputy's
parliamentary group **on each vote's date** — deputies change groups
mid-legislature, and attributing a 2025 vote to a 2026 group affiliation
would be exactly the kind of real-looking-but-misleading number this
project's constraints forbid. That is line 6, and it stays red.

## Standing rules (bind any future metric, independent of sample size)

- **Absences are excluded from every denominator.** The source's
  `"Non ha votato"` genuinely conflates "absent" with "present but not
  voting" (see `docs/v2/04-votes-import.md`); treating it as a behavioral
  signal in either direction would be fabrication.
- **No participation/attendance metric, ever**, for the same
  `"Non ha votato"` ambiguity — the source does not distinguish the
  reasons, so neither can we. (`attendanceRate` stays null everywhere.)
- **Secret ballots stay excluded at fetch scope.** Their per-deputy
  records carry only a generic voted flag by law; including them would
  misrepresent legal unattributability as data.
- **Astenuto is always its own category** (gate line 5, restated as a
  permanent rule).
- **The only permitted metric label is the pinned Italian string**
  `"Allineamento nel campione di votazioni importate"` — the label itself
  must state the sample-bound scope. It appears in this documentation
  only; grep-verified absent from all app code as of Phase 20.
- Any metric ships with its exact denominator definition and the gate
  table above, re-measured, in the same commit.

## Re-evaluation protocol

Whenever the votes sample changes (Phase 21 or later), this file's gate
table must be re-measured from the new `votes.json` in the same commit —
the numbers above are point-in-time, and a stale "✗" is as misleading as
an unearned "✓".
