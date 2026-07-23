# Voting-Data Methodology — the gate any future metric must pass

Written in V3 Phase 20 (see `docs/v3/20-vote-browsing.md`). This document
is the standing contract: **no vote-derived metric of any kind ships in
this app until every line of the gate below passes**, and the standing
rules below bind any metric that ever does ship. Phase 20 itself ships
*browsing only* — events, tallies, filters — deliberately no metric.

## The gate

A proposed metric (e.g. within-group voting alignment) may only be
computed over a sample that satisfies **all six** lines. Status is
re-measured against the current shipping data as of **v4 Phase 28**
(`votes.json` unchanged since Phase 27 — 30 events, 11,899 positions; plus
the new `memberships_camera.json` — 468 group-membership intervals, imported
2026-07-22; see [`docs/v4/28-membership-history.md`](../v4/28-membership-history.md)):

| # | Requirement | Current sample (Phase 28) | Status | (Phase 27) | (Phase 20) |
|---|---|---|---|---|---|
| 1 | ≥ 30 events | **30 events**, 11,899 positions | ✓ | ✓ | ✗ (12) |
| 2 | ≥ 3 distinct sittings (sedute) | **10 sittings** (552, 577, 581, 599, 614, 634, 648, 664, 680, 694) | ✓ | ✓ | ✗ (1) |
| 3 | ≥ 6 months of date span | **272 days ≈ 8.9 months** (2025-10-22 … 2026-07-21) | ✓ | ✓ | ✗ (1 day) |
| 4 | ≥ 2 distinct atti among atto-bearing events | **15 atto-bearing events, 9 distinct atti** | ✓ | ✓ | ✗ (0) |
| 5 | `astenuto` its own category, never folded into favorevole/contrario/assente | Holds structurally: `VoteChoice.astenuto` is a distinct case end-to-end (source `"Astensione"` → `.astenuto`, own badge, own filter chip, own tally). Distribution: Assente 4,571 / Favorevole 4,326 / Contrario 2,541 / **Astenuto 461** | ✓ | ✓ | ✓ |
| 6 | Group-membership-at-vote-date available | **Now available** — `memberships_camera.json` ships per-deputy `ocd:aderisce` intervals (half-open `[start, end)`), and `MembershipService.membershipAt(representativeId:date:)` resolves the group held on any date. **100 % coverage of the shipped sample**: all 11,899 `(deputy, vote-date)` position rows (and all 3,967 distinct pairs) resolve to exactly one interval | ✓ | ✗ | ✗ |

**Conclusion (as of Phase 28): 6 of 6 lines pass (Phase 27 was 5 of 6, Phase
20 was 1 of 6).** Phase 27's stratified expansion flipped the four
sample-shape lines (1–4); **Phase 28's group-membership import flips line 6**
(the group-at-vote-date lookup, at 100 % coverage of the current sample; see
Phase 28 / Q4). The gate requires **all six** — as of this commit, all six
pass.

**What this means for Phase 29 — stated plainly, not inherited.** Reaching
6/6 makes **Phase 29 a live phase** (it was structurally blocked while line 6
was red). It does **not** pre-decide Phase 29's own GO: per the
re-evaluation protocol below, **Phase 29's session must re-measure this table
from the then-current `votes.json` and `memberships_camera.json`** and decide
GO/NOT-RUN on *that* fresh measurement — plus resolve its own open questions
(metric tie-breaking and the minimum-denominator threshold — Q7, which need
explicit user sign-off) — never inheriting the 6/6 recorded here. A gate that
passes today can regress if a future refetch changes the sample; a stale ✓ is
as misleading as an unearned one.

Rationale, now that all six pass: the sample spans 10 sittings across ~9
months with 15 substantive atto-bearing votes on 9 distinct atti, and each
vote can now be attributed to the group the deputy held **on that vote's
date** — deputies change groups mid-legislature (52 of the 400 did), and
attributing a 2025 vote to a 2026 group affiliation would be exactly the kind
of real-looking-but-misleading number this project's constraints forbid. That
was line 6, and it is now green **for group attribution only** — every
standing rule below (absences excluded, no participation metric, secret
ballots excluded, astenuto its own category, the pinned label) still binds any
metric that ships.

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
